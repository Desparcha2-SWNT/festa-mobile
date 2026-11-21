import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/attendees/data/attendees_api.dart';
import 'package:festa/features/attendees/domain/attendee.dart';
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

const _eventId = '6f1c2b8e-3a1d-4c3e-9b0a-1f2e3d4c5b6a';

void main() {
  (AttendeesApi, _FakeAdapter) build(int status, Object body) {
    final adapter = _FakeAdapter(status, body);
    final dio = Dio(BaseOptions(baseUrl: 'http://festa.test'))..httpClientAdapter = adapter;
    return (AttendeesApi(dio), adapter);
  }

  test('pide la página a booking y lee nombre, boletas e ingresos', () async {
    final (api, adapter) = build(200, {
      'eventId': _eventId,
      'capacity': 80,
      'attendeeCount': 3,
      'total': 2,
      'limit': 50,
      'offset': 0,
      'items': [
        {
          'attendanceId': 'a1',
          'displayName': 'Ana María',
          'source': 'ticket',
          'tickets': 2,
          'checkedIn': 1,
          'confirmedAt': '2026-11-14T20:05:00.000Z',
        },
        {
          'attendanceId': 'a2',
          'displayName': null,
          'source': 'rsvp',
          'tickets': 1,
          'checkedIn': 0,
          'confirmedAt': '2026-11-14T21:00:00.000Z',
        },
      ],
    });

    final page = await api.list(_eventId, offset: 50);

    expect(adapter.last!.path, '/api/bookings/events/$_eventId/attendees');
    expect(adapter.last!.queryParameters, {'limit': 50, 'offset': 50});
    expect(page.capacity, 80);
    expect(page.attendeeCount, 3);
    expect(page.total, 2);
    expect(page.items.first.displayName, 'Ana María');
    expect(page.items.first.source, AttendanceSource.ticket);
    expect(page.items.first.fullyCheckedIn, isFalse);
    expect(page.items.last.displayName, isNull);
    expect(page.items.last.source, AttendanceSource.rsvp);
    expect(page.items.last.confirmedAt, DateTime.utc(2026, 11, 14, 21));
  });

  test('el 403 de quien no organiza el evento llega como ApiException', () async {
    final (api, _) = build(403, {
      'error': 'solo el organizador del evento puede ver sus asistentes',
      'code': 'not_organizer',
    });

    await expectLater(
      api.list(_eventId),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.code, 'code', 'not_organizer'),
      ),
    );
  });
}
