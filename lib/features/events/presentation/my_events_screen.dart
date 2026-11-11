import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../application/events_providers.dart';
import '../domain/event.dart';
import 'event_formatters.dart';

/// Eventos que creó el organizador (RF4: «el evento aparece en mi lista de eventos creados»).
/// Diseño: Figma «24 · Mis eventos». Los borradores del Figma no existen todavía en event-service.
class MyEventsScreen extends ConsumerStatefulWidget {
  const MyEventsScreen({super.key});

  @override
  ConsumerState<MyEventsScreen> createState() => _MyEventsScreenState();
}

enum _Tab { published, cancelled }

class _MyEventsScreenState extends ConsumerState<MyEventsScreen> {
  _Tab _tab = _Tab.published;

  Future<void> _refresh() => ref.refresh(myEventsProvider.future);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = ref.watch(myEventsProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Text('Mis eventos', style: theme.textTheme.headlineMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final (tab, label) in [(_Tab.published, 'Publicados'), (_Tab.cancelled, 'Cancelados')])
                    ChoiceChip(
                      label: Text(label),
                      selected: _tab == tab,
                      onSelected: (_) => setState(() => _tab = tab),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: switch (events) {
                  AsyncData(:final value) => _EventList(
                    events: value
                        .where((e) => (e.status == EventStatus.cancelled) == (_tab == _Tab.cancelled))
                        .toList(),
                    emptyMessage: _tab == _Tab.published
                        ? 'Aún no has publicado eventos.'
                        : 'No tienes eventos cancelados.',
                  ),
                  AsyncError(:final error) when !events.isLoading => _LoadError(
                    message: error is ApiException ? error.message : 'No pudimos cargar tus eventos.',
                    onRetry: _refresh,
                  ),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: FilledButton.icon(
                key: const Key('myEvents.create'),
                onPressed: () => context.push(Routes.createEvent),
                icon: const Icon(Icons.add),
                label: const Text('Crear evento'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.events, required this.emptyMessage});

  final List<Event> events;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      // Desplazable para poder refrescar aunque esté vacía.
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Text(emptyMessage, textAlign: TextAlign.center),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) => _MyEventCard(event: events[index]),
    );
  }
}

class _MyEventCard extends StatelessWidget {
  const _MyEventCard({required this.event});

  final Event event;

  (String, Color) _statusChip(ColorScheme colors) => switch (event.status) {
    EventStatus.published when event.endsAt.isBefore(DateTime.now()) => ('Terminado', colors.outline),
    EventStatus.published => ('Publicado', colors.tertiary),
    EventStatus.hidden => ('Oculto por moderación', colors.error),
    EventStatus.cancelled => ('Cancelado', colors.error),
    EventStatus.expired => ('Terminado', colors.outline),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (statusLabel, statusColor) = _statusChip(theme.colorScheme);
    final capacity = event.capacity;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.eventDetail(event.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(statusLabel, style: theme.textTheme.labelMedium?.copyWith(color: statusColor)),
              const SizedBox(height: 4),
              Text(event.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '${EventFormatters.schedule(event)} · ${event.venueName}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (capacity != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Cupo: $capacity personas',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 48),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      Center(
        child: FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
      ),
    ],
  );
}
