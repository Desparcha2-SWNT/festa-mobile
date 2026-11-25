import 'package:festa/app/routes.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/auth/application/session_controller.dart';
import 'package:festa/features/auth/domain/account.dart';
import 'package:festa/features/events/application/events_providers.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/events/presentation/event_detail_screen.dart';
import 'package:festa/features/reports/application/reports_providers.dart';
import 'package:festa/features/reports/data/reports_api.dart';
import 'package:festa/features/reports/domain/report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fakes.dart';

class _MockReportsApi extends Mock implements ReportsApi {}

class _SignedInUser extends SessionController {
  @override
  Future<Account?> build() async => testAccount;
}

/// El organizador del evento de prueba (`organizerId: 'o1'` en `eventJson`).
class _SignedInOrganizer extends SessionController {
  @override
  Future<Account?> build() async =>
      const Account(id: 'o1', email: 'mecanica@escuelaing.edu.co', displayName: 'Mecánica', role: Role.user);
}

void main() {
  setUpAll(() {
    registerFallbackValue(ReportTarget.event);
    registerFallbackValue(ReportReason.spam);
  });

  late _MockReportsApi reports;

  setUp(() => reports = _MockReportsApi());

  void stubCreate(Future<void> Function() answer) => when(
    () => reports.create(
      target: any(named: 'target'),
      targetId: any(named: 'targetId'),
      reason: any(named: 'reason'),
      comment: any(named: 'comment'),
    ),
  ).thenAnswer((_) => answer());

  Future<void> pumpDetail(WidgetTester tester, {SessionController Function() session = _SignedInUser.new}) async {
    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(session),
        eventDetailProvider.overrideWith((ref, id) async => Event.fromJson(eventJson())),
        reportsApiProvider.overrideWithValue(reports),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: Routes.eventDetail('e1'),
      routes: [
        GoRoute(
          path: Routes.eventDetailPattern,
          builder: (_, state) => EventDetailScreen(eventId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// El formulario no cabe entero en la pantalla de prueba: se desplaza hasta el control antes de tocarlo.
  Future<void> tapInSheet(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
  }

  Future<void> openReport(WidgetTester tester, String option) async {
    await tester.tap(find.byKey(const Key('eventDetail.menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(option)));
    await tester.pumpAndSettle();
  }

  testWidgets('reporta el evento con el motivo y el comentario, y lo agradece', (tester) async {
    stubCreate(() async {});
    await pumpDetail(tester);

    await openReport(tester, 'eventDetail.reportEvent');
    expect(find.text('Reportar evento'), findsOneWidget);

    // Sin motivo no se puede enviar.
    expect(tester.widget<FilledButton>(find.byKey(const Key('report.send'))).onPressed, isNull);

    await tapInSheet(tester, 'report.reason.informacion_falsa');
    await tester.enterText(find.byKey(const Key('report.comment')), 'La fecha no es la real.');
    await tester.pump();
    await tapInSheet(tester, 'report.send');
    await tester.pumpAndSettle();

    verify(
      () => reports.create(
        target: ReportTarget.event,
        targetId: 'e1',
        reason: ReportReason.falseInfo,
        comment: 'La fecha no es la real.',
      ),
    ).called(1);
    expect(find.byKey(const Key('report.send')), findsNothing);
    expect(find.text('Gracias. El equipo de Festa revisará tu reporte.'), findsOneWidget);
  });

  testWidgets('reporta al organizador con su cuenta', (tester) async {
    stubCreate(() async {});
    await pumpDetail(tester);

    await openReport(tester, 'eventDetail.reportOrganizer');
    expect(find.text('Reportar al organizador'), findsOneWidget);
    expect(find.text('Programa de Ingeniería Mecánica'), findsWidgets);

    await tapInSheet(tester, 'report.reason.acoso');
    await tester.pump();
    await tapInSheet(tester, 'report.send');
    await tester.pumpAndSettle();

    verify(
      () => reports.create(target: ReportTarget.user, targetId: 'o1', reason: ReportReason.harassment, comment: ''),
    ).called(1);
  });

  testWidgets('si ya lo había reportado, muestra el aviso y deja el formulario abierto', (tester) async {
    stubCreate(
      () async => throw const ApiException(
        code: 'REPORT_ALREADY_OPEN',
        message: 'Ya reportaste esto; el equipo lo está revisando',
        statusCode: 409,
      ),
    );
    await pumpDetail(tester);

    await openReport(tester, 'eventDetail.reportEvent');
    await tapInSheet(tester, 'report.reason.spam');
    await tester.pump();
    await tapInSheet(tester, 'report.send');
    await tester.pumpAndSettle();

    expect(find.text('Ya reportaste esto; el equipo lo está revisando'), findsOneWidget);
    expect(find.byKey(const Key('report.send')), findsOneWidget);
    expect(find.text('Gracias. El equipo de Festa revisará tu reporte.'), findsNothing);
  });

  testWidgets('sin conexión muestra el error y se puede reintentar', (tester) async {
    var attempts = 0;
    stubCreate(() async {
      if (attempts++ == 0) throw networkFailure;
    });
    await pumpDetail(tester);

    await openReport(tester, 'eventDetail.reportEvent');
    await tapInSheet(tester, 'report.reason.fraude');
    await tester.pump();
    await tapInSheet(tester, 'report.send');
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión'), findsOneWidget);

    await tapInSheet(tester, 'report.send');
    await tester.pumpAndSettle();

    expect(find.text('Gracias. El equipo de Festa revisará tu reporte.'), findsOneWidget);
  });

  testWidgets('el organizador no ve la opción de reportar su propio evento', (tester) async {
    await pumpDetail(tester, session: _SignedInOrganizer.new);

    expect(find.text('10ª Feria del Autómata'), findsOneWidget);
    expect(find.byKey(const Key('eventDetail.menu')), findsNothing);
  });
}
