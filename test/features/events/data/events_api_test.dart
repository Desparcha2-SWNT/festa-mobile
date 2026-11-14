import 'package:dio/dio.dart';
import 'package:festa/features/events/data/events_api.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/location/domain/geo_point.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un elemento tal como lo devuelve `searchEvents` en event-service (GET /events).
Map<String, dynamic> searchItem() => {
  'eventId': 'e1',
  'title': 'Noche de jazz',
  'category': 'musical',
  'startsAt': '2099-01-01T23:00:00.000Z',
  'endsAt': '2099-01-02T02:00:00.000Z',
  'happeningNow': false,
  'venueName': 'Bloque I',
  'organizerName': 'Ana',
  'location': {'lat': 4.7829, 'lng': -74.0421},
  'isLive': false,
  'ticketed': false,
  'priceCents': 0,
  'capacity': 30,
  'attendeeCount': 2,
  'soldOut': false,
  'featured': false,
  'coverImageUrl': null,
  'distanceMeters': 120,
};

void main() {
  test('nearby usa la búsqueda del mapa (GET /api/events) y lee su resumen', () async {
    late RequestOptions sent;
    final dio = Dio(BaseOptions(baseUrl: 'http://festa.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sent = options;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'items': [searchItem()],
                },
              ),
            );
          },
        ),
      );

    final events = await EventsApi(dio).nearby(const GeoPoint(latitude: 4.78, longitude: -74.04), radiusKm: 3);

    expect(sent.method, 'GET');
    expect(sent.path, '/api/events');
    expect(sent.queryParameters, {'lat': 4.78, 'lng': -74.04, 'radiusKm': 3.0});
    expect(events, hasLength(1));
    final event = events.single;
    expect(event.id, 'e1');
    expect(event.category, EventCategory.musical);
    expect(event.location, const GeoPoint(latitude: 4.7829, longitude: -74.0421));
    expect(event.venueName, 'Bloque I');
    expect(event.capacity, 30);
    expect(event.status, EventStatus.published);
  });
}
