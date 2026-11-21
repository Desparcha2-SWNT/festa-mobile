import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:festa/features/events/data/events_api.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/events/domain/event_filters.dart';
import 'package:festa/features/location/domain/geo_point.dart';
import 'package:flutter_test/flutter_test.dart';

class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode({'items': <dynamic>[]}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const center = GeoPoint(latitude: 4.78, longitude: -74.04);

  test('la búsqueda manda categoría, fecha y radio junto con la posición', () async {
    final adapter = _CapturingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://festa.test'))..httpClientAdapter = adapter;
    final now = DateTime(2026, 11, 21, 9);

    await EventsApi(dio).nearby(
      center,
      radiusKm: 5,
      filters: const EventFilters(categories: {EventCategory.cultural}, datePreset: EventDatePreset.week, radiusKm: 5),
      now: now,
    );

    final query = adapter.last!.queryParameters;
    expect(adapter.last!.path, '/api/events');
    expect(query['radiusKm'], 5);
    expect(query['category'], 'cultural');
    expect(query['from'], now.toUtc().toIso8601String());
    expect(query['to'], now.add(const Duration(days: 7)).toUtc().toIso8601String());
  });

  test('sin filtros la búsqueda no lleva parámetros de categoría ni fecha', () async {
    final adapter = _CapturingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://festa.test'))..httpClientAdapter = adapter;

    await EventsApi(dio).nearby(center, radiusKm: 3);

    expect(adapter.last!.queryParameters.keys, containsAll(['lat', 'lng', 'radiusKm']));
    expect(adapter.last!.queryParameters.containsKey('category'), isFalse);
    expect(adapter.last!.queryParameters.containsKey('from'), isFalse);
  });
}
