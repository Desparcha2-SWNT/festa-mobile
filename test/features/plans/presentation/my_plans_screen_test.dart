import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/plans/application/plans_providers.dart';
import 'package:festa/features/plans/data/plans_api.dart';
import 'package:festa/features/plans/domain/my_plan.dart';
import 'package:festa/features/plans/presentation/my_plans_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlansApi extends Mock implements PlansApi {}

MyPlan _plan(String id, {String? title, String? venue, PlanStatus status = PlanStatus.confirmed}) => MyPlan(
  attendanceId: id,
  eventId: 'e-$id',
  title: title ?? 'Plan $id',
  startsAt: DateTime(2026, 11, 14, 15, 5),
  endsAt: DateTime(2026, 11, 14, 18),
  status: status,
  venueName: venue,
);

MyPlansPage _page(List<MyPlan> items, {int? total, int offset = 0}) =>
    MyPlansPage(items: items, total: total ?? items.length, offset: offset);

void main() {
  late _MockPlansApi api;

  setUp(() {
    api = _MockPlansApi();
    when(() => api.list(PlansTab.past)).thenAnswer((_) async => _page([]));
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [plansApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: MyPlansScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra los próximos planes con fecha y lugar', (tester) async {
    when(() => api.list(PlansTab.upcoming)).thenAnswer(
      (_) async => _page([_plan('a1', title: 'Noche de jazz', venue: 'Bloque G'), _plan('a2', title: 'Torneo')]),
    );

    await pump(tester);

    expect(find.text('Noche de jazz'), findsOneWidget);
    expect(find.text('Bloque G'), findsOneWidget);
    expect(find.text('Torneo'), findsOneWidget);
    expect(find.text('sáb 14 nov · 3:05 p. m.'), findsNWidgets(2));
    expect(find.text('Evento cancelado'), findsNothing);
    expect(find.byKey(const Key('plans.loadMore.upcoming')), findsNothing);
  });

  testWidgets('sin planes próximos lo dice', (tester) async {
    when(() => api.list(PlansTab.upcoming)).thenAnswer((_) async => _page([]));

    await pump(tester);

    expect(find.byKey(const Key('plans.empty.upcoming')), findsOneWidget);
    expect(find.text('Todavía no tienes planes'), findsOneWidget);
  });

  testWidgets('en pasados, un evento que el organizador canceló se marca', (tester) async {
    when(() => api.list(PlansTab.upcoming)).thenAnswer((_) async => _page([]));
    when(() => api.list(PlansTab.past)).thenAnswer(
      (_) async =>
          _page([_plan('p1', title: 'Ya fue'), _plan('p2', title: 'Se canceló', status: PlanStatus.eventCancelled)]),
    );

    await pump(tester);
    await tester.tap(find.byKey(const Key('plans.tab.past')));
    await tester.pumpAndSettle();

    expect(find.text('Ya fue'), findsOneWidget);
    expect(find.text('Se canceló'), findsOneWidget);
    expect(find.text('Evento cancelado'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('plans.item.p2')), matching: find.text('Evento cancelado')),
      findsOneWidget,
    );
  });

  testWidgets('"Ver más" trae la siguiente página', (tester) async {
    when(() => api.list(PlansTab.upcoming)).thenAnswer((_) async => _page([_plan('a1', title: 'Uno')], total: 2));
    when(() => api.list(PlansTab.upcoming, offset: 1))
        .thenAnswer((_) async => _page([_plan('a2', title: 'Dos')], total: 2, offset: 1));

    await pump(tester);
    expect(find.text('Ver más (1)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('plans.loadMore.upcoming')));
    await tester.pumpAndSettle();

    expect(find.text('Uno'), findsOneWidget);
    expect(find.text('Dos'), findsOneWidget);
    expect(find.byKey(const Key('plans.loadMore.upcoming')), findsNothing);
  });

  testWidgets('"Ver más" con una página ilegible avisa y conserva la lista, sin dejar el error sin manejar', (
    tester,
  ) async {
    when(() => api.list(PlansTab.upcoming)).thenAnswer((_) async => _page([_plan('a1', title: 'Uno')], total: 2));
    // Un JSON inesperado no es una ApiException: antes escapaba sin que la persona viera nada.
    when(() => api.list(PlansTab.upcoming, offset: 1))
        .thenAnswer((_) async => throw const FormatException('JSON inesperado'));

    await pump(tester);
    await tester.tap(find.byKey(const Key('plans.loadMore.upcoming')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No pudimos cargar más planes. Intenta de nuevo.'), findsOneWidget);
    expect(find.text('Uno'), findsOneWidget);
    // El botón sigue ahí para reintentar.
    expect(find.byKey(const Key('plans.loadMore.upcoming')), findsOneWidget);
  });

  testWidgets('sin red reintenta solo dos veces y luego ofrece reintentar a mano', (tester) async {
    var online = false;
    when(() => api.list(PlansTab.upcoming)).thenAnswer((_) async {
      if (!online) throw const ApiException(code: ApiException.networkError, message: 'No pudimos conectarnos.');
      return _page([_plan('a1', title: 'Noche de jazz')]);
    });

    await pump(tester);
    expect(find.byKey(const Key('plans.error.upcoming')), findsOneWidget);
    expect(find.text('No pudimos conectarnos.'), findsOneWidget);
    verify(() => api.list(PlansTab.upcoming)).called(3); // el intento y dos reintentos automáticos

    online = true;
    await tester.tap(find.byKey(const Key('plans.retry.upcoming')));
    await tester.pumpAndSettle();

    expect(find.text('Noche de jazz'), findsOneWidget);
  });
}
