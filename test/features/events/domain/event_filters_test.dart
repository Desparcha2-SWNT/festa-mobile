import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/events/domain/event_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 21, 15, 30);

  test('sin filtros no cambia la búsqueda y no está activo', () {
    const filters = EventFilters();
    expect(filters.isActive, isFalse);
    expect(filters.activeCount, 0);
    expect(filters.toQuery(now), isEmpty);
  });

  test('las categorías viajan como lista separada por comas, en orden del enum', () {
    const filters = EventFilters(categories: {EventCategory.musical, EventCategory.cultural});
    expect(filters.toQuery(now), {'category': 'cultural,musical'});
    expect(filters.activeCount, 1);
  });

  test('hoy cubre el día local completo, en UTC', () {
    const filters = EventFilters(datePreset: EventDatePreset.today);
    final query = filters.toQuery(now);
    expect(query['from'], DateTime(2026, 11, 21).toUtc().toIso8601String());
    expect(query['to'], DateTime(2026, 11, 21, 23, 59, 59).toUtc().toIso8601String());
  });

  test('esta semana va de ahora a siete días después', () {
    const filters = EventFilters(datePreset: EventDatePreset.week);
    final query = filters.toQuery(now);
    expect(query['from'], now.toUtc().toIso8601String());
    expect(query['to'], now.add(const Duration(days: 7)).toUtc().toIso8601String());
  });

  test('la distancia cuenta como filtro solo si no es la de por defecto', () {
    const filters = EventFilters(radiusKm: 5);
    expect(filters.isActive, isTrue);
    expect(filters.activeCount, 1);
    expect(filters.toQuery(now), isEmpty, reason: 'el radio va como parámetro aparte, no en el filtro');
  });

  test('cuenta cada filtro activo una vez', () {
    const filters = EventFilters(categories: {EventCategory.deportivo}, datePreset: EventDatePreset.today, radiusKm: 1);
    expect(filters.activeCount, 3);
  });
}
