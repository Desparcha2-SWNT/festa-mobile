import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/plans/data/plans_api.dart';
import 'package:festa/features/plans/domain/my_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responde siempre lo mismo y guarda la última petición.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body);

  final int status;
  final Object body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  (PlansApi, _FakeAdapter) build(int status, Object body) {
    final adapter = _FakeAdapter(status, body);
    final dio = Dio(BaseOptions(baseUrl: 'http://festa.test'))..httpClientAdapter = adapter;
    return (PlansApi(dio), adapter);
  }

  test('pide la pestaña a booking y lee lugar, portada y estado', () async {
    final (api, adapter) = build(200, {
      'when': 'past',
      'total': 2,
      'limit': 20,
      'offset': 20,
      'items': [
        {
          'attendanceId': 'a1',
          'eventId': 'e1',
          'title': 'Noche de jazz',
          'startsAt': '2026-11-14T20:05:00.000Z',
          'endsAt': '2026-11-14T23:05:00.000Z',
          'venueName': 'Bloque G',
          'coverImageUrl': 'https://img.test/a.jpg',
          'status': 'confirmed',
          'eventStatus': 'expired',
          'confirmedAt': '2026-11-10T12:00:00.000Z',
        },
        {
          'attendanceId': 'a2',
          'eventId': 'e2',
          'title': 'Torneo',
          'startsAt': '2026-11-12T15:00:00.000Z',
          'endsAt': '2026-11-12T18:00:00.000Z',
          'venueName': null,
          'coverImageUrl': null,
          'status': 'event_cancelled',
          'eventStatus': 'cancelled',
          'confirmedAt': '2026-11-09T12:00:00.000Z',
        },
      ],
    });

    final page = await api.list(PlansTab.past, offset: 20);

    expect(adapter.last!.path, '/api/bookings/attendances/mine');
    expect(adapter.last!.queryParameters, {'when': 'past', 'limit': 20, 'offset': 20});
    expect(page.total, 2);
    expect(page.items.first.title, 'Noche de jazz');
    expect(page.items.first.venueName, 'Bloque G');
    expect(page.items.first.coverImageUrl, 'https://img.test/a.jpg');
    expect(page.items.first.status, PlanStatus.confirmed);
    expect(page.items.first.startsAt, DateTime.utc(2026, 11, 14, 20, 5));
    expect(page.items.last.venueName, isNull);
    expect(page.items.last.status, PlanStatus.eventCancelled);
  });

  test('un error del servidor llega como ApiException con su código HTTP', () async {
    final (api, _) = build(503, {'error': 'no disponible'});

    await expectLater(
      api.list(PlansTab.upcoming),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 503)),
    );
  });
}
