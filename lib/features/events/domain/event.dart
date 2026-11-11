import '../../location/domain/geo_point.dart';

enum EventCategory {
  cultural('Cultural'),
  musical('Musical'),
  deportivo('Deportivo'),
  gastronomico('Gastronómico');

  const EventCategory(this.label);

  final String label;

  static EventCategory fromApi(String value) => EventCategory.values.byName(value);
}

/// Evento publicado, tal como lo devuelve event-service (`toApi` en `src/events/repository.js`).
class Event {
  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.descriptionAiGenerated,
    required this.category,
    required this.startsAt,
    required this.endsAt,
    required this.venueName,
    required this.venueAddress,
    required this.location,
    required this.organizerName,
    required this.organizerIsMerchant,
    required this.ticketed,
    required this.priceCents,
    this.capacity,
    this.coverImageUrl,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    final venue = json['venue'] as Map<String, dynamic>;
    final location = venue['location'] as Map<String, dynamic>;
    return Event(
      id: json['eventId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      descriptionAiGenerated: json['descriptionAiGenerated'] as bool? ?? false,
      category: EventCategory.fromApi(json['category'] as String),
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      venueName: venue['name'] as String,
      venueAddress: venue['address'] as String,
      location: GeoPoint(latitude: (location['lat'] as num).toDouble(), longitude: (location['lng'] as num).toDouble()),
      organizerName: json['organizerName'] as String,
      organizerIsMerchant: json['organizerType'] == 'merchant',
      ticketed: json['ticketed'] as bool? ?? false,
      priceCents: json['priceCents'] as int? ?? 0,
      capacity: json['capacity'] as int?,
      coverImageUrl: json['coverImageUrl'] as String?,
    );
  }

  final String id;
  final String title;
  final String description;
  final bool descriptionAiGenerated;
  final EventCategory category;
  final DateTime startsAt;
  final DateTime endsAt;
  final String venueName;
  final String venueAddress;
  final GeoPoint location;
  final String organizerName;
  final bool organizerIsMerchant;

  /// Solo un comercio verificado puede vender boletas (lo exige event-service al crear el evento).
  final bool ticketed;
  final int priceCents;
  final int? capacity;
  final String? coverImageUrl;

  bool get isFree => priceCents == 0;
}
