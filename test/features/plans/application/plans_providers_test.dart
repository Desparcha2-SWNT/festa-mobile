import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/plans/application/plans_providers.dart';
import 'package:festa/features/plans/data/plans_api.dart';
import 'package:festa/features/plans/domain/my_plan.dart';
import 'package:festa/features/plans/presentation/plan_formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlansApi extends Mock implements PlansApi {}

MyPlan _plan(String id) => MyPlan(
  attendanceId: id,
  eventId: 'e-$id',
  title: 'Plan $id',
  startsAt: DateTime.utc(2026, 11, 14, 20),
  endsAt: DateTime.utc(2026, 11, 14, 23),
  status: PlanStatus.confirmed,
);

void main() {
  group('retryPlans', () {
    test('no reintenta un 4xx', () {
      const badRequest = ApiException(code: 'invalid_query', message: 'x', statusCode: 400);
      const unauthorized = ApiException(code: ApiException.unauthorized, message: 'x', statusCode: 401);
      expect(retryPlans(0, badRequest), isNull);
      expect(retryPlans(0, unauthorized), isNull);
    });

    test('reintenta un error de red o del servidor dos veces, cada vez con más espera', () {
      const offline = ApiException(code: ApiException.networkError, message: 'x');
      const down = ApiException(code: ApiException.unknownError, message: 'x', statusCode: 503);
      expect(retryPlans(0, offline), const Duration(milliseconds: 300));
      expect(retryPlans(1, down), const Duration(milliseconds: 600));
      expect(retryPlans(2, offline), isNull);
    });
  });

  group('PlansController', () {
    late _MockPlansApi api;
    late ProviderContainer container;

    setUp(() {
      api = _MockPlansApi();
      container = ProviderContainer(overrides: [plansApiProvider.overrideWithValue(api)]);
      addTearDown(container.dispose);
    });

    test('cada pestaña pide lo suyo', () async {
      when(() => api.list(PlansTab.upcoming))
          .thenAnswer((_) async => MyPlansPage(items: [_plan('a')], total: 1, offset: 0));
      when(() => api.list(PlansTab.past)).thenAnswer((_) async => const MyPlansPage(items: [], total: 0, offset: 0));

      final upcoming = container.listen(plansControllerProvider(PlansTab.upcoming), (_, _) {});
      final past = container.listen(plansControllerProvider(PlansTab.past), (_, _) {});
      await container.read(plansControllerProvider(PlansTab.upcoming).future);
      await container.read(plansControllerProvider(PlansTab.past).future);

      expect(upcoming.read().value!.items.single.title, 'Plan a');
      expect(upcoming.read().value!.hasMore, isFalse);
      expect(past.read().value!.items, isEmpty);
    });

    test('«ver más» agrega la siguiente página y para cuando ya no quedan', () async {
      when(() => api.list(PlansTab.upcoming))
          .thenAnswer((_) async => MyPlansPage(items: [_plan('a')], total: 2, offset: 0));
      when(() => api.list(PlansTab.upcoming, offset: 1))
          .thenAnswer((_) async => MyPlansPage(items: [_plan('b')], total: 2, offset: 1));

      final sub = container.listen(plansControllerProvider(PlansTab.upcoming), (_, _) {});
      await container.read(plansControllerProvider(PlansTab.upcoming).future);
      expect(sub.read().value!.hasMore, isTrue);

      final notifier = container.read(plansControllerProvider(PlansTab.upcoming).notifier);
      await notifier.loadMore();
      await notifier.loadMore(); // ya no quedan: no vuelve a pedir

      expect(sub.read().value!.items.map((p) => p.attendanceId), ['a', 'b']);
      expect(sub.read().value!.hasMore, isFalse);
      verify(() => api.list(PlansTab.upcoming, offset: 1)).called(1);
    });
  });

  test('la fecha del plan lleva día de la semana y hora de 12 horas', () {
    expect(formatPlanDate(DateTime(2026, 11, 14, 15, 5)), 'sáb 14 nov · 3:05 p. m.');
    expect(formatPlanDate(DateTime(2026, 11, 16, 0, 30)), 'lun 16 nov · 12:30 a. m.');
  });
}
