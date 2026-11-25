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

TeamReport _report(String id, {required String targetType, required String targetId}) => TeamReport.fromJson({
  'reportId': id,
  'targetType': targetType,
  'targetId': targetId,
  'reason': targetType == 'event' ? 'informacion_falsa' : 'acoso',
  'createdAt': _now.toUtc().toIso8601String(),
});

void main() {
  late _MockTeamReportsApi api;

  setUp(() {
    api = _MockTeamReportsApi();
    when(() => api.account('u1')).thenAnswer(
      (_) async =>
          const ReportedAccount(id: 'u1', displayName: 'Ana', email: 'ana@escuelaing.edu.co', suspended: false),
    );
  });

  /// Abre la cola con [report] y entra al reporte.
  Future<void> openReport(WidgetTester tester, TeamReport report) async {
    var reports = [report];
    when(() => api.open()).thenAnswer((_) async => reports);
    when(() => api.hideEvent(any(), reason: any(named: 'reason'))).thenAnswer((_) async => reports = []);
    when(
      () => api.suspendUser(
        any(),
        reason: any(named: 'reason'),
        until: any(named: 'until'),
      ),
    ).thenAnswer((_) async => reports = []);
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
    await tester.tap(find.byKey(Key('team.report.${report.reportId}')));
    await tester.pumpAndSettle();
  }

  Future<void> act(WidgetTester tester, {String? reason, String? duration}) async {
    await tester.tap(find.byKey(const Key('team.report.act')));
    await tester.pumpAndSettle();
    if (duration != null) {
      await tester.tap(find.byKey(Key('team.report.duration.$duration')));
      await tester.pump();
    }
    if (reason != null) {
      await tester.enterText(find.byKey(const Key('team.report.reason')), reason);
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('team.report.act.confirm')));
    await tester.pumpAndSettle();
  }

  testWidgets('oculta el evento reportado con el motivo y vuelve a la cola vacía', (tester) async {
    await openReport(tester, _report('r1', targetType: 'event', targetId: 'e1'));
    expect(find.text('Ocultar evento'), findsOneWidget);

    await act(tester, reason: 'La fecha y el lugar son falsos.');

    verify(() => api.hideEvent('r1', reason: 'La fecha y el lugar son falsos.')).called(1);
    expect(find.text('Evento oculto: ya no aparece en el mapa ni en la búsqueda.'), findsOneWidget);
    expect(find.byKey(const Key('team.reports.empty')), findsOneWidget);
  });

  testWidgets('suspende la cuenta 7 días por defecto, contados desde ahora', (tester) async {
    await openReport(tester, _report('r2', targetType: 'user', targetId: 'u1'));
    expect(find.text('Suspender cuenta'), findsOneWidget);

    await act(tester);

    verify(() => api.suspendUser('r2', reason: '', until: _now.add(const Duration(days: 7)))).called(1);
    expect(find.text('Cuenta suspendida por 7 días.'), findsOneWidget);
  });

  testWidgets('suspende la cuenta sin fecha de fin', (tester) async {
    await openReport(tester, _report('r2', targetType: 'user', targetId: 'u1'));

    await act(tester, duration: 'none', reason: 'Acoso repetido.');

    verify(() => api.suspendUser('r2', reason: 'Acoso repetido.')).called(1);
    expect(find.text('Cuenta suspendida sin fecha de fin.'), findsOneWidget);
  });

  testWidgets('un motivo que pasa los 500 de user-service no deja confirmar', (tester) async {
    await openReport(tester, _report('r1', targetType: 'event', targetId: 'e1'));
    await tester.tap(find.byKey(const Key('team.report.act')));
    await tester.pumpAndSettle();

    // 300 emojis: 600 unidades UTF-16 para el servidor.
    await tester.enterText(find.byKey(const Key('team.report.reason')), '🎉' * 300);
    await tester.pump();

    expect(tester.widget<FilledButton>(find.byKey(const Key('team.report.act.confirm'))).onPressed, isNull);
    expect(find.textContaining('los emojis cuentan doble'), findsOneWidget);
  });

  testWidgets('cancelar no cambia nada', (tester) async {
    await openReport(tester, _report('r1', targetType: 'event', targetId: 'e1'));
    await tester.tap(find.byKey(const Key('team.report.act')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    verifyNever(() => api.hideEvent(any(), reason: any(named: 'reason')));
    expect(find.text('Reporte'), findsOneWidget);
  });
}
