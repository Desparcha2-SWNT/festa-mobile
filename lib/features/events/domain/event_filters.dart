import 'event.dart';

/// Rango de fecha del filtro. `any` no filtra por fecha.
enum EventDatePreset { any, today, week }

/// Filtros de la búsqueda de eventos en el mapa (SCRUM-79 y 81). Se aplican en event-service:
/// `category` (lista separada por comas), `from` y `to` (ISO 8601 en UTC). El radio se pasa aparte.
class EventFilters {
  const EventFilters({
    this.categories = const {},
    this.datePreset = EventDatePreset.any,
    this.radiusKm = defaultRadiusKm,
  });

  static const defaultRadiusKm = 3.0;

  /// Distancias que ofrece la hoja de filtros.
  static const radiusOptionsKm = [1.0, 3.0, 5.0];

  final Set<EventCategory> categories;
  final EventDatePreset datePreset;
  final double radiusKm;

  /// Cuántos filtros distintos al valor por defecto hay activos (categoría, fecha y distancia).
  int get activeCount =>
      (categories.isNotEmpty ? 1 : 0) +
      (datePreset != EventDatePreset.any ? 1 : 0) +
      (radiusKm != defaultRadiusKm ? 1 : 0);

  bool get isActive => activeCount > 0;

  /// Rango local que cubre el filtro de fecha, o `null` si no filtra por fecha.
  ({DateTime from, DateTime to})? dateRange(DateTime now) => switch (datePreset) {
    EventDatePreset.any => null,
    EventDatePreset.today => (
      from: DateTime(now.year, now.month, now.day),
      to: DateTime(now.year, now.month, now.day, 23, 59, 59),
    ),
    EventDatePreset.week => (from: now, to: now.add(const Duration(days: 7))),
  };

  /// Parámetros de la búsqueda que cambian con los filtros (sin lat, lng ni radiusKm).
  Map<String, String> toQuery(DateTime now) {
    final query = <String, String>{};
    if (categories.isNotEmpty) {
      query['category'] = (categories.toList()..sort((a, b) => a.index.compareTo(b.index)))
          .map((c) => c.name)
          .join(',');
    }
    final range = dateRange(now);
    if (range != null) {
      query['from'] = range.from.toUtc().toIso8601String();
      query['to'] = range.to.toUtc().toIso8601String();
    }
    return query;
  }
}
