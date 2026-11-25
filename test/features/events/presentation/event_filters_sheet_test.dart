import 'package:festa/features/events/application/events_providers.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/events/domain/event_filters.dart';
import 'package:festa/features/events/presentation/event_filters_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Arranca con filtros ya aplicados, como si el usuario los hubiera elegido antes.
class _SeededFilters extends EventFiltersController {
  _SeededFilters(this.seed);

  final EventFilters seed;

  @override
  EventFilters build() => seed;
}

void main() {
  testWidgets('aplicar la hoja cambia los filtros del mapa', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    key: const Key('open'),
                    onPressed: () => showEventFiltersSheet(context),
                    child: const Text('abrir'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filters.cat.musical')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('filters.cat.gastronomico')));
    await tester.pump();
    await tester.tap(find.text('Hoy'));
    await tester.pump();
    await tester.tap(find.text('5 km'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('filters.apply')));
    await tester.pumpAndSettle();

    final applied = container.read(eventFiltersProvider);
    expect(applied.categories, {EventCategory.musical, EventCategory.gastronomico});
    expect(applied.datePreset, EventDatePreset.today);
    expect(applied.radiusKm, 5);
    expect(find.byKey(const Key('filters.apply')), findsNothing, reason: 'la hoja se cierra al aplicar');
  });

  testWidgets('limpiar filtros vuelve a los valores por defecto', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventFiltersProvider.overrideWith(
            () => _SeededFilters(const EventFilters(datePreset: EventDatePreset.week, radiusKm: 1)),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    key: const Key('open'),
                    onPressed: () => showEventFiltersSheet(context),
                    child: const Text('abrir'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filters.clear')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('filters.apply')));
    await tester.pumpAndSettle();

    expect(container.read(eventFiltersProvider).isActive, isFalse);
  });
}
