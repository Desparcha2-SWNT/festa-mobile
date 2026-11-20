import '../../location/domain/geo_point.dart';
import 'event.dart';

/// Lo que el organizador llena al crear o editar un evento (RF4).
class EventDraft {
  const EventDraft({
    required this.title,
    required this.venueName,
    required this.venueAddress,
    required this.location,
    required this.startsAt,
    required this.endsAt,
    required this.category,
    required this.description,
    this.capacity,
  });

  factory EventDraft.fromEvent(Event event) => EventDraft(
    title: event.title,
    venueName: event.venueName,
    venueAddress: event.venueAddress,
    location: event.location,
    startsAt: event.startsAt.toLocal(),
    endsAt: event.endsAt.toLocal(),
    category: event.category,
    description: event.description,
    capacity: event.capacity,
  );

  final String title;
  final String venueName;
  final String venueAddress;
  final GeoPoint location;
  final DateTime startsAt;
  final DateTime endsAt;
  final EventCategory category;
  final String description;

  /// `null` si no hay límite de personas.
  final int? capacity;

  Map<String, dynamic> get _venueJson => {
    'name': venueName,
    'address': venueAddress,
    'location': {'lat': location.latitude, 'lng': location.longitude},
  };

  Map<String, dynamic> _editableJson() => {
    'title': title,
    'description': description,
    'category': category.name,
    'startsAt': startsAt.toUtc().toIso8601String(),
    'endsAt': endsAt.toUtc().toIso8601String(),
    'venue': _venueJson,
    'capacity': capacity,
  };

  /// Cuerpo de `POST /api/events` para un evento de un comercio verificado (sin boletería por ahora).
  Map<String, dynamic> toCreateJson({required String merchantId, required String organizerName}) => {
    ..._editableJson(),
    'organizerType': 'merchant',
    'merchantId': merchantId,
    'organizerName': organizerName,
  };

  /// Cuerpo de `PATCH /api/events/:id`: solo los campos que cambiaron frente a [original].
  Map<String, dynamic> changesFrom(EventDraft original) {
    final before = original._editableJson();
    return {
      for (final MapEntry(:key, :value) in _editableJson().entries)
        if (!_sameJson(value, before[key])) key: value,
    };
  }

  /// Los valores son textos, números o el mapa del lugar, siempre armado en el mismo orden, así que
  /// basta comparar su texto.
  static bool _sameJson(Object? a, Object? b) => a.toString() == b.toString();
}
