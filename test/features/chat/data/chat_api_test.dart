import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/chat/data/chat_api.dart';
import 'package:festa/features/location/domain/geo_point.dart';
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

const _reply = {
  'sessionId': '5b7d7f3a-6f4e-4f0e-9c7a-3f5f6a1b2c3d',
  'reply': 'Te sugiero esta noche de jazz.',
  'events': [
    {
      'eventId': 'e1',
      'title': 'Noche de jazz',
      'category': 'musical',
      'startsAt': '2026-11-22T00:00:00Z',
      'venueName': 'Bloque G',
      'priceCents': 0,
      'isLive': false,
    },
  ],
  'disclaimer': 'Sugerencias automatizadas generadas por IA.',
};

void main() {
  (ChatApi, _FakeAdapter) build(int status, Object body) {
    final adapter = _FakeAdapter(status, body);
    final dio = Dio(BaseOptions(baseUrl: 'http://festa.test'))..httpClientAdapter = adapter;
    return (ChatApi(dio), adapter);
  }

  test('manda el mensaje a /api/ai/chat y lee la respuesta con sus eventos', () async {
    final (api, adapter) = build(200, _reply);

    final reply = await api.send('algo de jazz');

    expect(adapter.last!.method, 'POST');
    expect(adapter.last!.path, '/api/ai/chat');
    expect(adapter.last!.data, {'message': 'algo de jazz'});
    expect(reply.sessionId, '5b7d7f3a-6f4e-4f0e-9c7a-3f5f6a1b2c3d');
    expect(reply.reply, 'Te sugiero esta noche de jazz.');
    expect(reply.events.single.title, 'Noche de jazz');
    expect(reply.events.single.isFree, isTrue);
    expect(reply.disclaimer, 'Sugerencias automatizadas generadas por IA.');
  });

  test('reenvía la sesión y solo manda la ubicación si quien llama la entrega', () async {
    final (api, adapter) = build(200, _reply);

    await api.send('y algo gratis', sessionId: 's-1', location: const GeoPoint(latitude: 4.7, longitude: -74.0));

    expect(adapter.last!.data, {
      'message': 'y algo gratis',
      'sessionId': 's-1',
      'location': {'lat': 4.7, 'lng': -74.0},
    });
  });

  test('sin aviso del servicio usa el de sugerencia automatizada', () async {
    final (api, _) = build(200, {..._reply}..remove('disclaimer'));

    final reply = await api.send('hola');

    expect(reply.disclaimer, contains('automatizadas'));
  });

  test('traduce un 429 a ApiException con su código de estado', () async {
    final (api, _) = build(429, {'detail': 'vas muy rápido, espera un momento'});

    await expectLater(api.send('hola'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 429)));
  });
}
