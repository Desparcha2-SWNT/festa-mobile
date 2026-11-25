import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/events/data/description_api.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responde siempre lo mismo y guarda las peticiones.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body);

  final int status;
  final Object body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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

final _uuidV4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

void main() {
  (DescriptionApi, _FakeAdapter) build(int status, Object body) {
    final adapter = _FakeAdapter(status, body);
    final dio = Dio(BaseOptions(baseUrl: 'http://festa.test'))..httpClientAdapter = adapter;
    return (DescriptionApi(dio), adapter);
  }

  const ok = {
    'draftId': 'x',
    'description': '  Una noche de jazz para disfrutar en el campus.  ',
    'cached': false,
    'provider': 'gemini',
    'model': 'm',
  };

  test('pide la descripción a /api/ai/descriptions con los datos del evento', () async {
    final (api, adapter) = build(200, ok);

    final text = await api.generate(
      name: 'Noche de jazz',
      location: 'Bloque G',
      category: EventCategory.musical,
      startsAt: DateTime.utc(2026, 11, 22, 1),
      notes: 'con invitados',
      merchantId: 'm-1',
    );

    expect(text, 'Una noche de jazz para disfrutar en el campus.');
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/api/ai/descriptions');
    final data = request.data as Map<String, dynamic>;
    expect(data['draftId'], matches(_uuidV4));
    expect(data['name'], 'Noche de jazz');
    expect(data['location'], 'Bloque G');
    expect(data['activityType'], 'Musical');
    expect(data['category'], 'musical');
    expect(data['startsAt'], '2026-11-22T01:00:00.000Z');
    expect(data['notes'], 'con invitados');
    expect(data['merchantId'], 'm-1');
  });

  test('sin notas, fecha ni comercio no manda esos campos', () async {
    final (api, adapter) = build(200, ok);

    await api.generate(name: 'Torneo', location: 'Cancha', category: EventCategory.deportivo, notes: '   ');

    final data = adapter.requests.single.data as Map<String, dynamic>;
    expect(data.keys, unorderedEquals(['draftId', 'name', 'location', 'activityType', 'category']));
  });

  test('cada petición abre un borrador nuevo (el servicio genera una descripción por borrador)', () async {
    final (api, adapter) = build(200, ok);

    await api.generate(name: 'Torneo', location: 'Cancha', category: EventCategory.deportivo);
    await api.generate(name: 'Torneo', location: 'Cancha', category: EventCategory.deportivo);

    final ids = adapter.requests.map((r) => (r.data as Map<String, dynamic>)['draftId']).toSet();
    expect(ids, hasLength(2));
  });

  test('recorta las notas largas al máximo que acepta el servicio', () async {
    final (api, adapter) = build(200, ok);

    await api.generate(name: 'Torneo', location: 'Cancha', category: EventCategory.deportivo, notes: 'a' * 500);

    expect(
      ((adapter.requests.single.data as Map<String, dynamic>)['notes'] as String).length,
      DescriptionApi.maxNotesLength,
    );
  });

  test('traduce un 429 y un 403 a ApiException con su código de estado', () async {
    final (limited, _) = build(429, {'detail': 'vas muy rápido'});
    await expectLater(
      limited.generate(name: 'Torneo', location: 'Cancha', category: EventCategory.deportivo),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 429)),
    );

    final (forbidden, _) = build(403, {'detail': 'el comercio no es tuyo o no está verificado'});
    await expectLater(
      forbidden.generate(name: 'Torneo', location: 'Cancha', category: EventCategory.deportivo, merchantId: 'm'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)),
    );
  });
}
