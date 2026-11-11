import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../application/events_providers.dart';
import '../domain/event.dart';
import 'event_category_color.dart';
import 'event_formatters.dart';

/// SCRUM-75: detalle de un evento. Diseño: Figma «9 · Detalle del evento».
///
/// El botón «Confirmo que voy» y el conteo de cupos ocupados llegan con la asistencia (SCRUM-70).
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(eventDetailProvider(eventId));
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle')),
      body: switch (detail) {
        AsyncData(:final value) => _EventDetail(event: value),
        AsyncError(:final error) => _LoadError(
          message: error is ApiException ? error.message : 'No pudimos cargar el evento.',
          onRetry: () => ref.invalidate(eventDetailProvider(eventId)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _EventDetail extends ConsumerWidget {
  const _EventDetail({required this.event});

  final Event event;

  void _showOnMap(BuildContext context, WidgetRef ref) {
    ref.read(selectedEventProvider.notifier).select(event);
    context.go(Routes.map);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final capacity = event.capacity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            children: [
              _Cover(event: event),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    _InfoRow(icon: Icons.calendar_today_outlined, text: EventFormatters.schedule(event)),
                    _InfoRow(icon: Icons.place_outlined, text: '${event.venueName}, ${event.venueAddress}'),
                    _InfoRow(icon: Icons.sell_outlined, text: EventFormatters.price(event)),
                    if (capacity != null) _InfoRow(icon: Icons.group_outlined, text: 'Cupo para $capacity personas'),
                    const SizedBox(height: 16),
                    _Organizer(event: event),
                    const SizedBox(height: 24),
                    Text('Sobre el plan', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(event.description, style: theme.textTheme.bodyMedium),
                    if (event.descriptionAiGenerated) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 16, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            'Descripción generada con IA',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: OutlinedButton(
              key: const Key('eventDetail.showOnMap'),
              onPressed: () => _showOnMap(context, ref),
              child: const Text('Ver en el mapa'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(color: event.category.color.withValues(alpha: 0.2));
    final imageUrl = event.coverImageUrl;
    return SizedBox(
      height: 180,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl == null)
            placeholder
          else
            Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
          Positioned(
            left: 16,
            top: 16,
            child: Chip(
              label: Text(event.category.label),
              backgroundColor: event.category.color,
              labelStyle: const TextStyle(color: Colors.white),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _Organizer extends StatelessWidget {
  const _Organizer({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                event.organizerIsMerchant ? Icons.storefront_outlined : Icons.person_outline,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.organizerName, style: theme.textTheme.titleSmall),
                  // event-service solo deja vender boletas a comercios verificados.
                  if (event.ticketed)
                    Row(
                      children: [
                        Icon(Icons.check, size: 16, color: theme.colorScheme.tertiary),
                        const SizedBox(width: 4),
                        Text(
                          'Comercio verificado',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.tertiary),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
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
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}
