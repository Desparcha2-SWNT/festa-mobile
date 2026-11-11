import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/events/presentation/event_formatters.dart';
import 'package:festa/features/location/domain/geo_point.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';

void main() {
  test('lee el evento de event-service', () {
    final event = Event.fromJson(eventJson(category: 'gastronomico', ticketed: true, priceCents: 1000000));

    expect(event.id, 'e1');
    expect(event.category, EventCategory.gastronomico);
    expect(event.location, const GeoPoint(latitude: 4.7829, longitude: -74.0421));
    expect(event.venueName, 'Bloque I');
    expect(event.organizerIsMerchant, isTrue);
    expect(event.capacity, 30);
    expect(event.startsAt, DateTime.utc(2026, 11, 12, 13, 30));
  });

  group('formatos', () {
    test('el precio es «Gratis» o en pesos con separador de miles', () {
      expect(EventFormatters.price(Event.fromJson(eventJson())), 'Gratis');
      expect(EventFormatters.price(Event.fromJson(eventJson(ticketed: true, priceCents: 1000000))), r'$10.000');
      expect(EventFormatters.price(Event.fromJson(eventJson(ticketed: true, priceCents: 150000000))), r'$1.500.000');
    });

    test('la hora va en formato de 12 horas', () {
      expect(EventFormatters.time(DateTime(2026, 11, 12, 8, 30)), '8:30 a. m.');
      expect(EventFormatters.time(DateTime(2026, 11, 12, 12, 5)), '12:05 p. m.');
      expect(EventFormatters.time(DateTime(2026, 11, 12, 0, 0)), '12:00 a. m.');
    });

    test('la fecha lleva día de la semana y mes abreviados', () {
      expect(EventFormatters.date(DateTime(2026, 11, 11)), 'mié 11 nov');
    });
  });
}
