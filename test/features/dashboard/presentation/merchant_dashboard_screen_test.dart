import 'dart:async';

import 'package:festa/app/routes.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/dashboard/application/dashboard_providers.dart';
import 'package:festa/features/dashboard/data/dashboard_api.dart';
import 'package:festa/features/dashboard/domain/merchant_dashboard.dart';
import 'package:festa/features/dashboard/presentation/merchant_dashboard_screen.dart';
import 'package:festa/features/merchant/application/merchant_controller.dart';
import 'package:festa/features/merchant/domain/merchant_profile.dart';
import 'package:festa/features/merchant/presentation/my_merchant_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fakes.dart';

class _MockDashboardApi extends Mock implements DashboardApi {}

class _VerifiedMerchant extends MerchantController {
  @override
  Future<MerchantProfile?> build() async => testMerchantProfile(MerchantStatus.verified);
}

const _totals = DashboardTotals(
  events: 2,
  attendees: 30,
  checkIns: 24,
  views: 410,
  shares: 6,
  recommendedByAi: 12,
  ticketsSold: 5,
  grossCents: 17500000,
);

DashboardEvent _event(String id, {String title = 'Noche de jazz', String? status, int ticketsSold = 5}) =>
    DashboardEvent(
      eventId: id,
      title: title,
      startsAt: DateTime(2026, 11, 22, 19),
      status: status,
      attendees: 20,
      checkIns: 16,
      views: 300,
      ticketsSold: ticketsSold,
      grossCents: ticketsSold * 3500000,
      showUpRate: 0.8,
    );

void main() {
  late _MockDashboardApi api;

  setUp(() => api = _MockDashboardApi());

  Future<void> pumpDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dashboardApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: MerchantDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra los totales del comercio', (tester) async {
    when(() => api.mine()).thenAnswer((_) async => MerchantDashboard(totals: _totals, events: [_event('e1')]));

    await pumpDashboard(tester);

    for (final entry in {
      'events': '2',
      'attendees': '30',
      'checkIns': '24',
      'views': '410',
      'shares': '6',
      'ai': '12',
      'tickets': '5',
      'gross': r'$ 175.000',
    }.entries) {
      final metric = find.byKey(Key('dashboard.metric.${entry.key}'));
      expect(metric, findsOneWidget, reason: entry.key);
      expect(
        find.descendant(of: metric, matching: find.text(entry.value)),
        findsOneWidget,
        reason: entry.key,
      );
    }
    expect(find.byKey(const Key('dashboard.salesNote')), findsOneWidget);
  });

  testWidgets('lista cada evento con sus números y marca los cancelados', (tester) async {
    when(() => api.mine()).thenAnswer(
      (_) async => MerchantDashboard(
        totals: _totals,
        events: [
          _event('e1'),
          _event('e2', title: 'Torneo', status: 'cancelled', ticketsSold: 0),
        ],
      ),
    );

    await pumpDashboard(tester);

    expect(find.text('Noche de jazz'), findsOneWidget);
    expect(find.text('20 confirmados · 16 ingresaron · 300 vistas'), findsNWidgets(2));
    expect(find.text(r'5 boletas · $ 175.000'), findsOneWidget);
    expect(find.text('Asistencia real: 80 %'), findsNWidgets(2));
    expect(find.text('Torneo'), findsOneWidget);
    expect(find.text('Evento cancelado'), findsOneWidget);
    // Sin boletas vendidas no se muestra la línea de ventas del evento.
    expect(find.textContaining('0 boletas'), findsNothing);
  });

  testWidgets('un comercio sin eventos ve cómo se llenará el panel', (tester) async {
    when(() => api.mine()).thenAnswer(
      (_) async => const MerchantDashboard(
        totals: DashboardTotals(
          events: 0,
          attendees: 0,
          checkIns: 0,
          views: 0,
          shares: 0,
          recommendedByAi: 0,
          ticketsSold: 0,
          grossCents: 0,
        ),
        events: [],
      ),
    );

    await pumpDashboard(tester);

    expect(find.byKey(const Key('dashboard.empty')), findsOneWidget);
    expect(find.byKey(const Key('dashboard.list')), findsNothing);
  });

  testWidgets('si falla muestra el error y «Reintentar» lo vuelve a pedir', (tester) async {
    var calls = 0;
    when(() => api.mine()).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw const ApiException(code: 'X', message: 'No pudimos conectarnos.', statusCode: 503);
      return MerchantDashboard(totals: _totals, events: [_event('e1')]);
    });

    await pumpDashboard(tester);
    expect(find.text('No pudimos conectarnos.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dashboard.retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard.error')), findsNothing);
    expect(find.byKey(const Key('dashboard.list')), findsOneWidget);
  });

  testWidgets('al tocar un evento abre su detalle', (tester) async {
    when(() => api.mine()).thenAnswer((_) async => MerchantDashboard(totals: _totals, events: [_event('e1')]));
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: Routes.merchantDashboard,
      routes: [
        GoRoute(path: Routes.merchantDashboard, builder: (_, _) => const MerchantDashboardScreen()),
        GoRoute(
          path: Routes.eventDetailPattern,
          builder: (_, _) => const Scaffold(body: Text('Detalle')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dashboardApiProvider.overrideWithValue(api)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboard.event.e1')));
    await tester.pumpAndSettle();

    expect(find.text('Detalle'), findsOneWidget);
  });

  testWidgets('«Mi comercio» tiene el acceso a «Mis resultados»', (tester) async {
    when(() => api.mine()).thenAnswer((_) async => MerchantDashboard(totals: _totals, events: [_event('e1')]));
    final router = GoRouter(
      initialLocation: Routes.myMerchant,
      routes: [
        GoRoute(path: Routes.myMerchant, builder: (_, _) => const MyMerchantScreen()),
        GoRoute(path: Routes.merchantDashboard, builder: (_, _) => const MerchantDashboardScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          merchantControllerProvider.overrideWith(_VerifiedMerchant.new),
          dashboardApiProvider.overrideWithValue(api),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('myMerchant.dashboard')));
    await tester.pumpAndSettle();

    expect(find.text('Mis resultados'), findsOneWidget);
    expect(find.byKey(const Key('dashboard.list')), findsOneWidget);
  });

  testWidgets('mientras carga muestra el indicador', (tester) async {
    final pending = Completer<MerchantDashboard>();
    when(() => api.mine()).thenAnswer((_) => pending.future);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dashboardApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: MerchantDashboardScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(
      const MerchantDashboard(
        totals: DashboardTotals(
          events: 0,
          attendees: 0,
          checkIns: 0,
          views: 0,
          shares: 0,
          recommendedByAi: 0,
          ticketsSold: 0,
          grossCents: 0,
        ),
        events: [],
      ),
    );
    await tester.pumpAndSettle();
  });
}
