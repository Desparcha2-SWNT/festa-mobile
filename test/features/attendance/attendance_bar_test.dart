import 'package:festa/app/routes.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/attendance/application/attendance_providers.dart';
import 'package:festa/features/attendance/data/attendance_api.dart';
import 'package:festa/features/attendance/domain/attendance_status.dart';
import 'package:festa/features/events/application/events_providers.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/events/presentation/event_detail_screen.dart';
import 'package:festa/features/passes/application/passes_providers.dart';
import 'package:festa/features/passes/data/passes_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fakes.dart';

class _MockAttendanceApi extends Mock implements AttendanceApi {}

class _MockPassesApi extends Mock implements PassesApi {}

/// Cuenta los refrescos de la copia de «Mis entradas» (SCRUM-91) sin pedir nada.
class _CountingSync extends PassesSync {
  _CountingSync() : super(api: _MockPassesApi(), cache: InMemoryPassesCache(), accountId: () => null);

  int calls = 0;

  @override
  Future<void> refresh() async => calls++;
}

/// Evento gratis que todavía no termina, con cupo para 30.
Event _openEvent({bool ticketed = false, int? capacity = 30, String status = 'published'}) {
  final starts = DateTime.now().add(const Duration(days: 2));
  return Event.fromJson({
    ...eventJson(ticketed: ticketed, priceCents: ticketed ? 1000000 : 0),
    'startsAt': starts.toUtc().toIso8601String(),
    'endsAt': starts.add(const Duration(hours: 3)).toUtc().toIso8601String(),
    'capacity': capacity,
    'status': status,
  });
}

void main() {
  late _MockAttendanceApi api;
  late _CountingSync passesSync;

  setUp(() {
    api = _MockAttendanceApi();
    passesSync = _CountingSync();
  });

  Future<void> pumpDetail(WidgetTester tester, Event event) async {
    final router = GoRouter(
      initialLocation: Routes.eventDetail(event.id),
      routes: [
        GoRoute(
          path: Routes.map,
          builder: (_, _) => const Scaffold(body: Text('Mapa')),
        ),
        GoRoute(
          path: Routes.eventDetailPattern,
          builder: (_, state) => EventDetailScreen(eventId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventDetailProvider.overrideWith((ref, id) async => event),
          attendanceApiProvider.overrideWithValue(api),
          passesSyncProvider.overrideWithValue(passesSync),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('confirmar asistencia ocupa un cupo y lo dice', (tester) async {
    when(() => api.status('e1'))
        .thenAnswer((_) async => const AttendanceStatus(confirmed: false, attendeeCount: 3, capacity: 30));
    when(() => api.confirm('e1')).thenAnswer((_) async => 4);

    await pumpDetail(tester, _openEvent());
    expect(find.text('3 de 30 cupos ocupados'), findsOneWidget);

    await tester.tap(find.byKey(const Key('attendance.confirm')));
    await tester.pumpAndSettle();

    verify(() => api.confirm('e1')).called(1);
    expect(find.byKey(const Key('attendance.going')), findsOneWidget);
    expect(find.text('4 de 30 cupos ocupados'), findsOneWidget);
    expect(find.text('¡Listo! Quedó en tus planes.'), findsOneWidget);
    // La entrada nueva queda guardada para mostrar el QR sin señal, sin abrir «Mis entradas».
    expect(passesSync.calls, 1);
  });

  testWidgets('cancelar pide confirmación y libera el cupo', (tester) async {
    when(() => api.status('e1'))
        .thenAnswer((_) async => const AttendanceStatus(confirmed: true, attendeeCount: 4, capacity: 30));
    when(() => api.cancel('e1')).thenAnswer((_) async => 3);

    await pumpDetail(tester, _openEvent());
    await tester.tap(find.byKey(const Key('attendance.cancel')));
    await tester.pumpAndSettle();
    expect(find.text('¿Cancelar tu asistencia?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('attendance.cancel.confirm')));
    await tester.pumpAndSettle();

    verify(() => api.cancel('e1')).called(1);
    expect(find.text('Confirmo que voy'), findsOneWidget);
    expect(find.text('3 de 30 cupos ocupados'), findsOneWidget);
  });

  testWidgets('un evento lleno no deja confirmar', (tester) async {
    when(() => api.status('e1'))
        .thenAnswer((_) async => const AttendanceStatus(confirmed: false, attendeeCount: 30, capacity: 30));

    await pumpDetail(tester, _openEvent());

    final button = tester.widget<FilledButton>(find.byKey(const Key('attendance.confirm')));
    expect(button.onPressed, isNull);
    expect(find.text('Sin cupos'), findsOneWidget);
  });

  testWidgets('si se llenó mientras miraba, muestra el motivo y vuelve a pedir el estado', (tester) async {
    var calls = 0;
    when(
      () => api.status('e1'),
    ).thenAnswer((_) async => AttendanceStatus(confirmed: false, attendeeCount: calls++ == 0 ? 29 : 30, capacity: 30));
    when(() => api.confirm('e1'))
        .thenThrow(const ApiException(code: 'full', message: 'El evento no tiene cupos disponibles.', statusCode: 409));

    await pumpDetail(tester, _openEvent());
    await tester.tap(find.byKey(const Key('attendance.confirm')));
    await tester.pumpAndSettle();

    expect(find.text('El evento no tiene cupos disponibles.'), findsOneWidget);
    expect(find.text('Sin cupos'), findsOneWidget);
    verify(() => api.status('e1')).called(2);
  });

  testWidgets('sin cupo máximo cuenta las personas que van', (tester) async {
    when(() => api.status('e1')).thenAnswer((_) async => const AttendanceStatus(confirmed: false, attendeeCount: 1));

    await pumpDetail(tester, _openEvent(capacity: null));

    expect(find.text('1 persona va'), findsOneWidget);
  });

  testWidgets('no aparece en eventos con boleta ni en los que ya terminaron', (tester) async {
    await pumpDetail(tester, _openEvent(ticketed: true));
    expect(find.byKey(const Key('attendance.confirm')), findsNothing);

    await pumpDetail(tester, testEvent()); // terminó el 12 de noviembre
    expect(find.byKey(const Key('attendance.confirm')), findsNothing);
    verifyNever(() => api.status(any()));
  });
}
