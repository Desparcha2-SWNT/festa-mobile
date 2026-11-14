import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/events/domain/event_draft.dart';
import 'package:festa/features/location/domain/geo_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final draft = EventDraft(
    title: 'Feria del Autómata',
    venueName: 'Bloque I',
    venueAddress: 'AK 45 #205-59',
    location: const GeoPoint(latitude: 4.7829, longitude: -74.0421),
    startsAt: DateTime.utc(2026, 11, 20, 13, 30),
    endsAt: DateTime.utc(2026, 11, 20, 16, 30),
    category: EventCategory.musical,
    description: 'Muestra de autómatas.',
  );

  EventDraft copy({String? title, String? venueName, int? capacity}) => EventDraft(
    title: title ?? draft.title,
    venueName: venueName ?? draft.venueName,
    venueAddress: draft.venueAddress,
    location: draft.location,
    startsAt: draft.startsAt,
    endsAt: draft.endsAt,
    category: draft.category,
    description: draft.description,
    capacity: capacity ?? draft.capacity,
  );

  test('el cuerpo para crear lleva el comercio como organizador y las fechas en UTC', () {
    final json = draft.toCreateJson(merchantId: 'm1', organizerName: 'Programa de Mecánica');

    expect(json, containsPair('organizerType', 'merchant'));
    expect(json, containsPair('merchantId', 'm1'));
    expect(json, containsPair('organizerName', 'Programa de Mecánica'));
    expect(json, containsPair('category', 'musical'));
    expect(json, containsPair('startsAt', '2026-11-20T13:30:00.000Z'));
    expect(json['venue'], {
      'name': 'Bloque I',
      'address': 'AK 45 #205-59',
      'location': {'lat': 4.7829, 'lng': -74.0421},
    });
    expect(json, containsPair('capacity', null));
  });

  test('al editar solo se envía lo que cambió', () {
    expect(copy(title: 'Feria 2026').changesFrom(draft), {'title': 'Feria 2026'});
    expect(copy(capacity: 40).changesFrom(draft), {'capacity': 40});
    expect(copy().changesFrom(draft), isEmpty);
  });

  test('un cambio en el lugar envía el lugar completo', () {
    final changes = copy(venueName: 'Auditorio').changesFrom(draft);

    expect(changes.keys, ['venue']);
    expect(changes['venue'], containsPair('name', 'Auditorio'));
  });
}
