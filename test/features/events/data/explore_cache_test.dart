import 'package:festa/features/events/data/explore_cache.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';

void main() {
  test('lo guardado se lee igual: eventos del mapa y hora en que se guardó', () {
    final event = Event.fromSearchJson({
      'eventId': 'e1',
      'title': 'Noche de jazz',
      'category': 'musical',
      'startsAt': '2026-11-24T23:00:00.000Z',
      'endsAt': '2026-11-25T02:00:00.000Z',
      'venueName': 'Bloque G',
      'location': {'lat': 4.7829, 'lng': -74.0421},
      'organizerName': 'Programa de Música',
      'ticketed': true,
      'priceCents': 1500000,
      'capacity': 80,
      'coverImageUrl': 'https://img.test/a.jpg',
    });
    final savedAt = DateTime.utc(2026, 11, 20, 20, 5);

    final read = SharedPreferencesExploreCache.decode(SharedPreferencesExploreCache.encode([event], savedAt))!;

    expect(read.savedAt, savedAt);
    final copy = read.events.single;
    expect(copy.toSearchJson(), event.toSearchJson());
    expect(copy.title, 'Noche de jazz');
    expect(copy.location.latitude, 4.7829);
    expect(copy.startsAt, DateTime.utc(2026, 11, 24, 23));
  });

  test('un evento de prueba sobrevive la ida y vuelta', () {
    final event = testEvent();
    final read = SharedPreferencesExploreCache.decode(SharedPreferencesExploreCache.encode([event], DateTime(2026)))!;
    expect(read.events.single.toSearchJson(), event.toSearchJson());
  });

  test('lo que no se puede leer cuenta como nada guardado', () {
    expect(SharedPreferencesExploreCache.decode('no es json'), isNull);
    expect(SharedPreferencesExploreCache.decode('{"savedAt": "2026-11-20T00:00:00Z", "items": [{"x": 1}]}'), isNull);
  });
}
