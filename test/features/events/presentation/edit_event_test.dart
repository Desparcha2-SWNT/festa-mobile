import 'package:festa/app/routes.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/events/application/events_providers.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/events/presentation/edit_event_screen.dart';
import 'package:festa/features/events/presentation/my_events_screen.dart';
import 'package:festa/features/location/application/user_location_provider.dart';
import 'package:festa/features/location/domain/user_location.dart';
import 'package:festa/features/map/presentation/map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fakes.dart';

/// Evento publicado y vigente (fechas lejanas para que la prueba no dependa del día en que corre).
// En hora local, para que no cruce la medianoche en ninguna zona horaria (el CI corre en UTC):
// el formulario solo admite eventos que empiezan y terminan el mismo día.
Event upcomingEvent({String status = 'published'}) => Event.fromJson({
  ...eventJson(),
  'startsAt': DateTime(2099, 1, 1, 18).toUtc().toIso8601String(),
  'endsAt': DateTime(2099, 1, 1, 21).toUtc().toIso8601String(),
  'status': status,
});

void main() {
  late MockEventsApi api;

  setUp(() {
    api = MockEventsApi();
    when(() => api.byId('e1')).thenAnswer((_) async => upcomingEvent());
    when(() => api.mine()).thenAnswer((_) async => [upcomingEvent()]);
  });

  Future<void> pumpApp(WidgetTester tester, {String initialLocation = '/my-events/e1/edit'}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: Routes.myEvents, builder: (_, _) => const MyEventsScreen()),
        GoRoute(
          path: Routes.editEventPattern,
          builder: (_, state) => EditEventScreen(eventId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: Routes.eventDetailPattern,
          builder: (_, _) => const Scaffold(body: Text('Detalle')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventsApiProvider.overrideWithValue(api),
          nearbyEventsProvider.overrideWith((ref) async => <Event>[]),
          userLocationProvider.overrideWith((ref) async => const UserLocation.device(testDevicePoint)),
          mapViewBuilderProvider.overrideWithValue((_) => const SizedBox.expand()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('desde «Mis eventos» un evento vigente abre la edición con sus datos', (tester) async {
    await pumpApp(tester, initialLocation: Routes.myEvents);

    await tap(tester, find.text('10ª Feria del Autómata'));

    expect(find.text('Editar evento'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '10ª Feria del Autómata'), findsOneWidget);
  });

  testWidgets('guarda solo lo que cambió y vuelve a «Mis eventos»', (tester) async {
    when(() => api.update('e1', any())).thenAnswer((_) async => upcomingEvent());
    await pumpApp(tester);

    await tester.enterText(find.byKey(const Key('eventForm.title')), 'Feria del Autómata 2099');
    await tap(tester, find.byKey(const Key('eventForm.submit')));

    verify(() => api.update('e1', {'title': 'Feria del Autómata 2099'})).called(1);
    expect(find.text('Cambios guardados.'), findsOneWidget);
    expect(find.text('Mis eventos'), findsOneWidget);
  });

  testWidgets('sin cambios no llama al servidor', (tester) async {
    await pumpApp(tester);

    await tap(tester, find.byKey(const Key('eventForm.submit')));

    verifyNever(() => api.update(any(), any()));
    expect(find.text('No hiciste cambios.'), findsOneWidget);
  });

  testWidgets('si el servidor lo rechaza, lo explica y no sale de la edición', (tester) async {
    when(() => api.update('e1', any()))
        .thenThrow(const ApiException(code: 'HTTP_403', message: 'Solo quien creó el evento puede editarlo.'));
    await pumpApp(tester);

    await tester.enterText(find.byKey(const Key('eventForm.title')), 'Otro título');
    await tap(tester, find.byKey(const Key('eventForm.submit')));

    expect(find.text('Solo quien creó el evento puede editarlo.'), findsOneWidget);
    expect(find.text('Editar evento'), findsOneWidget);
  });

  testWidgets('cancelar pide el motivo, avisa y vuelve a «Mis eventos»', (tester) async {
    when(() => api.cancel('e1', reason: any(named: 'reason')))
        .thenAnswer((_) async => upcomingEvent(status: 'cancelled'));
    await pumpApp(tester);

    await tap(tester, find.byKey(const Key('editEvent.cancel')));
    expect(find.text('¿Cancelar este evento?'), findsOneWidget);

    await tap(tester, find.byKey(const Key('cancelEvent.confirm')));
    expect(find.text('Escribe el motivo.'), findsOneWidget);
    verifyNever(() => api.cancel(any(), reason: any(named: 'reason')));

    await tester.enterText(find.byKey(const Key('cancelEvent.reason')), 'Lluvia');
    await tap(tester, find.byKey(const Key('cancelEvent.confirm')));

    verify(() => api.cancel('e1', reason: 'Lluvia')).called(1);
    expect(find.text('Evento cancelado.'), findsOneWidget);
    expect(find.text('Mis eventos'), findsOneWidget);
  });

  testWidgets('«Mantener evento» no cancela nada', (tester) async {
    await pumpApp(tester);

    await tap(tester, find.byKey(const Key('editEvent.cancel')));
    await tap(tester, find.text('Mantener evento'));

    verifyNever(() => api.cancel(any(), reason: any(named: 'reason')));
    expect(find.text('Editar evento'), findsOneWidget);
  });

  testWidgets('un evento cancelado ya no se puede editar', (tester) async {
    when(() => api.byId('e1')).thenAnswer((_) async => upcomingEvent(status: 'cancelled'));
    await pumpApp(tester);

    expect(find.text('Este evento ya no se puede editar.'), findsOneWidget);
  });
}
