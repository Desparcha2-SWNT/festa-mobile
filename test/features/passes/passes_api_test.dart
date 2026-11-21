import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/passes/data/passes_api.dart';
import 'package:festa/features/passes/domain/pass.dart';
import 'package:flutter_test/flutter_test.dart';

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
  (PassesApi, _FakeAdapter) build(int status, Object body) {
    final adapter = _FakeAdapter(status, body);
    final dio = Dio(BaseOptions(baseUrl: 'http://festa.test'))..httpClientAdapter = adapter;
    return (PassesApi(dio), adapter);
  }

  test('pide las entradas a booking', () async {
    final (api, adapter) = build(200, {
      'items': [
        {
          'passId': 'p1',
          'eventId': 'e1',
          'eventTitle': 'Noche de jazz',
          'source': 'rsvp',
          'status': 'valid',
          'qr': 'FESTA1.x',
        },
        {'passId': 'p2', 'eventId': 'e2', 'eventTitle': 'Torneo', 'source': 'ticket', 'status': 'revoked', 'qr': null},
      ],
    });

    final passes = await api.mine();

    expect(adapter.last!.path, '/api/bookings/passes/mine');
    expect(passes.map((p) => p.passId), ['p1', 'p2']);
    expect(passes.last.status, PassStatus.revoked);
  });

  test('un error llega como ApiException', () async {
    final (api, _) = build(503, {'error': 'no disponible'});

    await expectLater(api.mine(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 503)));
  });
}
