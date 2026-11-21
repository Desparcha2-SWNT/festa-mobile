import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/event.dart';

/// El último listado de eventos cercanos que se cargó, con la hora en que se guardó (SCRUM-140).
class CachedEvents {
  const CachedEvents({required this.events, required this.savedAt});

  final List<Event> events;
  final DateTime savedAt;
}

/// Guarda en el teléfono el último listado del mapa, para mostrarlo cuando no hay conexión.
abstract interface class ExploreCache {
  Future<CachedEvents?> read();
  Future<void> save(List<Event> events, DateTime savedAt);
}

/// Son eventos publicados, los mismos que cualquiera ve en el mapa: no es un secreto, así que basta
/// con SharedPreferences.
class SharedPreferencesExploreCache implements ExploreCache {
  SharedPreferencesExploreCache([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  static const _key = 'festa.explore_cache.v1';

  @override
  Future<CachedEvents?> read() async {
    final raw = await _preferences.getString(_key);
    return raw == null ? null : decode(raw);
  }

  @override
  Future<void> save(List<Event> events, DateTime savedAt) => _preferences.setString(_key, encode(events, savedAt));

  static String encode(List<Event> events, DateTime savedAt) => jsonEncode({
    'savedAt': savedAt.toUtc().toIso8601String(),
    'items': [for (final event in events) event.toSearchJson()],
  });

  /// `null` si lo guardado no se puede leer (por ejemplo, de una versión anterior de la app).
  static CachedEvents? decode(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return CachedEvents(
        savedAt: DateTime.parse(json['savedAt'] as String),
        events: [for (final item in json['items'] as List<dynamic>) Event.fromSearchJson(item as Map<String, dynamic>)],
      );
    } on Object {
      return null;
    }
  }
}
