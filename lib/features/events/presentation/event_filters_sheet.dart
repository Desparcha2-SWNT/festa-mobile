import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/design.dart';
import '../application/events_providers.dart';
import '../domain/event.dart';
import '../domain/event_filters.dart';

/// Abre la hoja de filtros del mapa (SCRUM-79 y 81). Los cambios solo se aplican con «Aplicar».
Future<void> showEventFiltersSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const EventFiltersSheet(),
);

class EventFiltersSheet extends ConsumerStatefulWidget {
  const EventFiltersSheet({super.key});

  @override
  ConsumerState<EventFiltersSheet> createState() => _EventFiltersSheetState();
}

class _EventFiltersSheetState extends ConsumerState<EventFiltersSheet> {
  late Set<EventCategory> _categories;
  late EventDatePreset _date;
  late double _radiusKm;

  @override
  void initState() {
    super.initState();
    final current = ref.read(eventFiltersProvider);
    _categories = {...current.categories};
    _date = current.datePreset;
    _radiusKm = current.radiusKm;
  }

  static const _dateLabels = {
    EventDatePreset.any: 'Cualquier fecha',
    EventDatePreset.today: 'Hoy',
    EventDatePreset.week: 'Esta semana',
  };

  void _clear() => setState(() {
    _categories = {};
    _date = EventDatePreset.any;
    _radiusKm = EventFilters.defaultRadiusKm;
  });

  void _apply() {
    ref
        .read(eventFiltersProvider.notifier)
        .apply(EventFilters(categories: _categories, datePreset: _date, radiusKm: _radiusKm));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(FestaSpace.md, 0, FestaSpace.md, FestaSpace.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filtrar eventos', style: theme.textTheme.titleLarge),
            const SizedBox(height: FestaSpace.md),
            Text('Categoría', style: theme.textTheme.titleSmall),
            const SizedBox(height: FestaSpace.xs),
            Wrap(
              spacing: FestaSpace.xs,
              children: [
                for (final c in EventCategory.values)
                  FilterChip(
                    key: Key('filters.cat.${c.name}'),
                    label: Text(c.label),
                    selected: _categories.contains(c),
                    onSelected: (on) => setState(() => on ? _categories.add(c) : _categories.remove(c)),
                  ),
              ],
            ),
            const SizedBox(height: FestaSpace.md),
            Text('Fecha', style: theme.textTheme.titleSmall),
            const SizedBox(height: FestaSpace.xs),
            SegmentedButton<EventDatePreset>(
              key: const Key('filters.date'),
              segments: [for (final p in EventDatePreset.values) ButtonSegment(value: p, label: Text(_dateLabels[p]!))],
              selected: {_date},
              onSelectionChanged: (s) => setState(() => _date = s.first),
            ),
            const SizedBox(height: FestaSpace.md),
            Text('Distancia', style: theme.textTheme.titleSmall),
            const SizedBox(height: FestaSpace.xs),
            SegmentedButton<double>(
              key: const Key('filters.radius'),
              segments: [
                for (final km in EventFilters.radiusOptionsKm)
                  ButtonSegment(value: km, label: Text('${km.toStringAsFixed(0)} km')),
              ],
              selected: {_radiusKm},
              onSelectionChanged: (s) => setState(() => _radiusKm = s.first),
            ),
            const SizedBox(height: FestaSpace.lg),
            Row(
              children: [
                TextButton(key: const Key('filters.clear'), onPressed: _clear, child: const Text('Limpiar filtros')),
                const Spacer(),
                FilledButton(key: const Key('filters.apply'), onPressed: _apply, child: const Text('Aplicar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
