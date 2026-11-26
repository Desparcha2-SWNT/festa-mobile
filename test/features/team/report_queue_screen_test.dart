import 'dart:async';

import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/events/application/events_providers.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/team/application/team_providers.dart';
import 'package:festa/features/team/data/team_reports_api.dart';
import 'package:festa/features/team/domain/team_report.dart';
import 'package:festa/features/team/presentation/report_queue_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fakes.dart';

class _MockTeamReportsApi extends Mock implements TeamReportsApi {}

/// Hora fija de las pruebas: miércoles 25 de noviembre de 2026, 2:00 p. m.
final _now = DateTime(2026, 11, 25, 14);

TeamReport _report(
  String id, {
  String targetType = 'event',
  String targetId = 'e1',
  String reason = 'informacion_falsa',
  String? comment = 'La fecha no es la real.',
  DateTime? created,
}) => TeamReport.fromJson({
  'reportId': id,
  'targetType': targetType,
  'targetId': targetId,
  'reason': reason,
  'comment': ?comment,
  'reporterId': 'a1',
  'createdAt': (created ?? _now.subtract(const Duration(hours: 2))).toUtc().toIso8601String(),
});

void main() {
  late _MockTeamReportsApi api;

  setUp(() => api = _MockTeamReportsApi());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teamReportsApiProvider.overrideWithValue(api),
          eventDetailProvider.overrideWith((ref, id) async => Event.fromJson(eventJson(id: id))),
        ],
        child: MaterialApp(home: ReportQueueScreen(now: () => _now)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openReport(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(Key('team.report.$id')));
    await tester.pumpAndSettle();
  }

  Future<void> dismiss(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('team.report.dismiss')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('team.report.dismiss.confirm')));
    await tester.pumpAndSettle();
  }

  testWidgets('lista los reportes abiertos con qué se reporta, el motivo, el comentario y cuándo', (tester) async {
    when(() => api.open()).thenAnswer(
      (_) async => [
        _report('r1'),
        _report('r2', targetType: 'user', reason: 'acoso', comment: null, created: DateTime(2026, 11, 24, 18)),
      ],
    );

    await pump(tester);

    expect(find.text('Reportes (2)'), findsOneWidget);
    expect(find.text('Evento reportado · Información falsa'), findsOneWidget);
    expect(find.text('«La fecha no es la real.»'), findsOneWidget);
    expect(find.text('Reportado hace 2 h'), findsOneWidget);
    expect(find.text('Cuenta reportada · Acoso o intimidación'), findsOneWidget);
    expect(find.text('Reportado ayer'), findsOneWidget);
  });

  testWidgets('sin reportes lo dice', (tester) async {
    when(() => api.open()).thenAnswer((_) async => []);

    await pump(tester);

    expect(find.byKey(const Key('team.reports.empty')), findsOneWidget);
  });

  testWidgets('si falla la carga muestra el error y permite reintentar', (tester) async {
    var calls = 0;
    when(() => api.open()).thenAnswer((_) async {
      if (calls++ == 0) throw networkFailure;
      return [_report('r1')];
    });

    await pump(tester);
    expect(find.byKey(const Key('team.reports.error')), findsOneWidget);
    expect(find.text('Sin conexión'), findsOneWidget);

    await tester.tap(find.byKey(const Key('team.reports.retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('team.report.r1')), findsOneWidget);
  });

  testWidgets('el reporte de un evento muestra el evento y quién lo organiza', (tester) async {
    when(() => api.open()).thenAnswer((_) async => [_report('r1')]);

    await pump(tester);
    await openReport(tester, 'r1');

    expect(find.text('Reporte'), findsOneWidget);
    expect(find.text('Información falsa'), findsOneWidget);
    expect(find.text('10ª Feria del Autómata · organiza Programa de Ingeniería Mecánica'), findsOneWidget);
    expect(find.text('La fecha no es la real.'), findsOneWidget);
    expect(find.text('Hace 2 horas'), findsOneWidget);
    expect(find.byKey(const Key('team.report.openEvent')), findsOneWidget);
  });

  testWidgets('el reporte de una cuenta muestra su nombre, correo y si ya está suspendida', (tester) async {
    when(() => api.open()).thenAnswer((_) async => [_report('r2', targetType: 'user', targetId: 'u1')]);
    when(() => api.account('u1')).thenAnswer(
      (_) async => const ReportedAccount(id: 'u1', displayName: 'Ana', email: 'ana@escuelaing.edu.co', suspended: true),
    );

    await pump(tester);
    await openReport(tester, 'r2');

    expect(find.text('Ana · ana@escuelaing.edu.co · ya está suspendida'), findsOneWidget);
  });

  testWidgets('descartar cierra el reporte, vuelve a la cola y la recarga', (tester) async {
    var reports = [_report('r1'), _report('r2')];
    when(() => api.open()).thenAnswer((_) async => reports);
    when(() => api.dismiss('r1')).thenAnswer((_) async => reports = [_report('r2')]);

    await pump(tester);
    await openReport(tester, 'r1');
    await dismiss(tester);

    verify(() => api.dismiss('r1')).called(1);
    expect(find.text('Reporte descartado.'), findsOneWidget);
    expect(find.text('Reportes (1)'), findsOneWidget);
    expect(find.byKey(const Key('team.report.r1')), findsNothing);
  });

  testWidgets('mientras se envía no se puede volver ni enviar de nuevo', (tester) async {
    final pending = Completer<void>();
    when(() => api.open()).thenAnswer((_) async => [_report('r1')]);
    when(() => api.dismiss('r1')).thenAnswer((_) => pending.future);

    await pump(tester);
    await openReport(tester, 'r1');
    await tester.tap(find.byKey(const Key('team.report.dismiss')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('team.report.dismiss.confirm')));
    await tester.pump();

    expect(tester.widget<OutlinedButton>(find.byKey(const Key('team.report.dismiss'))).onPressed, isNull);
    await tester.pageBack();
    await tester.pump();
    expect(find.text('Reporte'), findsOneWidget);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Reporte descartado.'), findsOneWidget);
  });

  testWidgets('si otra persona ya lo cerró, vuelve a la cola con el aviso', (tester) async {
    when(() => api.open()).thenAnswer((_) async => [_report('r1')]);
    when(() => api.dismiss('r1')).thenThrow(
      const ApiException(code: 'REPORT_ALREADY_RESOLVED', message: 'El reporte ya está cerrado', statusCode: 409),
    );

    await pump(tester);
    await openReport(tester, 'r1');
    await dismiss(tester);

    expect(find.text('El reporte ya está cerrado'), findsOneWidget);
    expect(find.text('Reporte'), findsNothing);
    verify(() => api.open()).called(2);
  });

  testWidgets('sin red se queda en el reporte para reintentar', (tester) async {
    when(() => api.open()).thenAnswer((_) async => [_report('r1')]);
    when(() => api.dismiss('r1')).thenThrow(networkFailure);

    await pump(tester);
    await openReport(tester, 'r1');
    await dismiss(tester);

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.byKey(const Key('team.report.dismiss')), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('team.report.dismiss'))).onPressed, isNotNull);
  });
}
