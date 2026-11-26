import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/dashboard/data/dashboard_api.dart';
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
  (DashboardApi, _FakeAdapter) build(int status, Object body) {
    final adapter = _FakeAdapter(status, body);
    final dio = Dio(BaseOptions(baseUrl: 'http://festa.test'))..httpClientAdapter = adapter;
    return (DashboardApi(dio), adapter);
  }

  test('lee totales y detalle por evento de /api/analytics/merchants/me', () async {
    final (api, adapter) = build(200, {
      'merchant': null,
      'totals': {
        'events': 2,
        'attendees': 30,
        'checkIns': 24,
        'views': 410,
        'shares': 6,
        'recommendedByAi': 12,
        'ticketsSold': 5,
        'grossCents': 17500000,
      },
      'events': [
        {
          'eventId': 'e1',
          'title': 'Noche de jazz',
          'startsAt': '2026-11-22T00:00:00.000Z',
          'status': 'published',
          'attendees': 20,
          'checkIns': 16,
          'showUpRate': 0.8,
          'views': 300,
          'ticketsSold': 5,
          'grossCents': 17500000,
        },
      ],
    });

    final dashboard = await api.mine();

    expect(adapter.last!.method, 'GET');
    expect(adapter.last!.path, '/api/analytics/merchants/me');
    expect(dashboard.totals.events, 2);
    expect(dashboard.totals.checkIns, 24);
    expect(dashboard.totals.grossCents, 17500000);
    expect(dashboard.events.single.title, 'Noche de jazz');
    expect(dashboard.events.single.showUpRate, 0.8);
    expect(dashboard.events.single.isCancelled, isFalse);
    expect(dashboard.isEmpty, isFalse);
  });

  test('un comercio sin eventos llega con todo en cero y se reconoce como vacío', () async {
    final (api, _) = build(200, {
      'merchant': null,
      'totals': {'events': 0, 'attendees': 0},
      'events': <Object>[],
    });

    final dashboard = await api.mine();

    expect(dashboard.isEmpty, isTrue);
    expect(dashboard.totals.views, 0);
  });

  test('un evento cancelado y sin nombre se lee sin fallar', () async {
    final (api, _) = build(200, {
      'totals': {'events': 1},
      'events': [
        {'eventId': 'e2', 'status': 'cancelled'},
      ],
    });

    final event = (await api.mine()).events.single;

    expect(event.isCancelled, isTrue);
    expect(event.title, 'Evento sin nombre');
    expect(event.startsAt, isNull);
    expect(event.showUpRate, isNull);
  });

  test('traduce un 401 a ApiException con su código de estado', () async {
    final (api, _) = build(401, {'error': 'no autorizado'});

    await expectLater(api.mine(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)));
  });
}
