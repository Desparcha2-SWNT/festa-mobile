import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/attendance/data/attendance_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responde según el método y guarda las peticiones.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  final Map<String, (int, Object)> responses;
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    final (status, body) = responses[options.method]!;
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
  (AttendanceApi, _FakeAdapter) build(Map<String, (int, Object)> responses) {
    final adapter = _FakeAdapter(responses);
    final dio = Dio(BaseOptions(baseUrl: 'http://festa.test'))..httpClientAdapter = adapter;
    return (AttendanceApi(dio), adapter);
  }

  test('lee el estado y confirma y cancela en la ruta de booking', () async {
    final (api, adapter) = build({
      'GET': (200, {'eventId': 'e1', 'capacity': 30, 'attendeeCount': 3, 'confirmed': false}),
      'POST': (201, {'attendanceId': 'a1', 'eventId': 'e1', 'status': 'confirmed', 'attendeeCount': 4}),
      'DELETE': (200, {'eventId': 'e1', 'status': 'cancelled', 'attendeeCount': 3}),
    });

    final status = await api.status('e1');
    expect(status.attendeeCount, 3);
    expect(status.capacity, 30);
    expect(status.confirmed, isFalse);
    expect(await api.confirm('e1'), 4);
    expect(await api.cancel('e1'), 3);

    expect(adapter.seen.map((r) => '${r.method} ${r.path}'), [
      'GET /api/bookings/events/e1/attendance',
      'POST /api/bookings/events/e1/attendance',
      'DELETE /api/bookings/events/e1/attendance',
    ]);
  });

  test('el 409 de un evento lleno llega como ApiException con su código', () async {
    final (api, _) = build({
      'POST': (409, {'error': 'el evento no tiene cupos disponibles', 'code': 'full'}),
    });

    await expectLater(
      api.confirm('e1'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'full').having((e) => e.statusCode, 'statusCode', 409)),
    );
  });
}
