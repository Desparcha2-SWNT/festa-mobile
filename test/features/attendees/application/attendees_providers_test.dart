import 'dart:async';

import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/attendees/application/attendees_providers.dart';
import 'package:festa/features/attendees/data/attendees_api.dart';
import 'package:festa/features/attendees/domain/attendee.dart';
import 'package:festa/features/attendees/presentation/attendee_formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAttendeesApi extends Mock implements AttendeesApi {}

Attendee _attendee(String id) => Attendee(
  attendanceId: id,
  source: AttendanceSource.rsvp,
  tickets: 1,
  checkedIn: 0,
  confirmedAt: DateTime.utc(2026, 11, 14, 20),
);

AttendeePage _page(List<String> ids, {required int total, int offset = 0}) => AttendeePage(
  items: [for (final id in ids) _attendee(id)],
  total: total,
  attendeeCount: total,
  offset: offset,
  capacity: 80,
);

void main() {
  group('retryAttendees', () {
    const forbidden = ApiException(code: 'not_organizer', message: 'x', statusCode: 403);
    const notFound = ApiException(code: 'not_found', message: 'x', statusCode: 404);
    const offline = ApiException(code: ApiException.networkError, message: 'x');

    test('no reintenta un 403 ni un 404', () {
      expect(retryAttendees(0, forbidden), isNull);
      expect(retryAttendees(0, notFound), isNull);
    });

    test('reintenta un error de red dos veces, cada vez con más espera', () {
      expect(retryAttendees(0, offline), const Duration(milliseconds: 300));
      expect(retryAttendees(1, offline), const Duration(milliseconds: 600));
      expect(retryAttendees(2, offline), isNull);
    });
  });

  test('la hora de confirmación se muestra en formato de 12 horas', () {
    expect(formatConfirmedAt(DateTime(2026, 1, 3, 0, 7)), '3 ene, 12:07 a. m.');
    expect(formatConfirmedAt(DateTime(2026, 12, 31, 12, 30)), '31 dic, 12:30 p. m.');
  });

  group('AttendeesController: «ver más» y refresh a la vez', () {
    late _MockAttendeesApi api;
    late ProviderContainer container;
    final provider = attendeesControllerProvider('e1');

    setUp(() {
      api = _MockAttendeesApi();
      container = ProviderContainer(overrides: [attendeesApiProvider.overrideWithValue(api)]);
      addTearDown(container.dispose);
    });

    /// Primera carga con [a] de 3; el refresh trae [x, y] de 2. La página 2 queda en manos de la prueba.
    Future<Completer<AttendeePage>> loadThenStartLoadMore() async {
      var loads = 0;
      when(() => api.list('e1'))
          .thenAnswer((_) async => ++loads == 1 ? _page(['a'], total: 3) : _page(['x', 'y'], total: 2));
      final secondPage = Completer<AttendeePage>();
      when(() => api.list('e1', offset: 1)).thenAnswer((_) => secondPage.future);
      container.listen(provider, (_, _) {});
      await container.read(provider.future);
      return secondPage;
    }

    test('una página pedida antes del refresh no pisa la lista recargada', () async {
      final secondPage = await loadThenStartLoadMore();
      final loadingMore = container.read(provider.notifier).loadMore();

      await container.refresh(provider.future);
      secondPage.complete(_page(['b'], total: 3, offset: 1)); // llega tarde, con datos viejos
      await loadingMore;

      final state = container.read(provider).value!;
      expect(state.items.map((a) => a.attendanceId), ['x', 'y']);
      expect(state.total, 2);
    });

    test('el error de una página vieja no sube a la pantalla', () async {
      final secondPage = await loadThenStartLoadMore();
      final loadingMore = container.read(provider.notifier).loadMore();

      await container.refresh(provider.future);
      secondPage.completeError(const ApiException(code: ApiException.networkError, message: 'x'));

      await expectLater(loadingMore, completes);
      expect(container.read(provider).value!.items.map((a) => a.attendanceId), ['x', 'y']);
    });

    test('sin refresh de por medio, la página se agrega como siempre', () async {
      final secondPage = await loadThenStartLoadMore();
      final loadingMore = container.read(provider.notifier).loadMore();
      secondPage.complete(_page(['b'], total: 3, offset: 1));
      await loadingMore;

      expect(container.read(provider).value!.items.map((a) => a.attendanceId), ['a', 'b']);
    });
  });
}
