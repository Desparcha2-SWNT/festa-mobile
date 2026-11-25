import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/design.dart';
import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../attendance/presentation/attendance_bar.dart';
import '../../auth/application/session_controller.dart';
import '../../reports/domain/report.dart';
import '../../reports/presentation/report_sheet.dart';
import '../application/events_providers.dart';
import '../domain/event.dart';
import 'event_category_color.dart';
import 'event_formatters.dart';
import 'event_share.dart';

/// SCRUM-75: detalle de un evento. Diseño: Figma «9 · Detalle del evento».
///
/// Abajo, «Confirmo que voy» y los cupos ocupados (SCRUM-70) para los eventos gratis.
/// Arriba, el botón para compartir el evento (SCRUM-107, RF13) y el menú para reportar el evento o a su
/// organizador (SCRUM-109, RF14).
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(eventDetailProvider(eventId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle'),
        actions: [
          // Un evento cancelado no se comparte: invitaría a un plan que ya no existe.
          if (detail case AsyncData(:final value) when value.status != EventStatus.cancelled)
            _ShareButton(event: value),
          if (detail case AsyncData(:final value)) _ReportMenu(event: value),
        ],
      ),
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
    final cancelled = event.status == EventStatus.cancelled;
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
                    if (cancelled) ...[const _CancelledBanner(), const SizedBox(height: 16)],
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
        // Un evento cancelado ya no está en el mapa.
        if (!cancelled)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (AttendanceBar.appliesTo(event)) ...[AttendanceBar(event: event), const SizedBox(height: 8)],
                  OutlinedButton(
                    key: const Key('eventDetail.showOnMap'),
                    onPressed: () => _showOnMap(context, ref),
                    child: const Text('Ver en el mapa'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ShareButton extends ConsumerWidget {
  const _ShareButton({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    key: const Key('eventDetail.share'),
    tooltip: 'Compartir',
    icon: const Icon(Icons.share_outlined),
    onPressed: () {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
      ref.read(eventSharerProvider).share(event, origin: origin);
    },
  );
}

enum _ReportAction { event, organizer }

/// Menú «⋮» con las opciones de reporte. No aparece en los eventos propios: nadie se reporta a sí mismo.
class _ReportMenu extends ConsumerWidget {
  const _ReportMenu({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountId = ref.watch(sessionControllerProvider.select((session) => session.value?.id));
    final organizerId = event.organizerId;
    if (accountId != null && accountId == organizerId) return const SizedBox.shrink();
    return PopupMenuButton<_ReportAction>(
      key: const Key('eventDetail.menu'),
      tooltip: 'Más opciones',
      onSelected: (action) => switch (action) {
        _ReportAction.event => showReportSheet(
          context,
          target: ReportTarget.event,
          targetId: event.id,
          subject: event.title,
        ),
        _ReportAction.organizer => showReportSheet(
          context,
          target: ReportTarget.user,
          targetId: organizerId!,
          subject: event.organizerName,
        ),
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          key: Key('eventDetail.reportEvent'),
          value: _ReportAction.event,
          child: ListTile(leading: Icon(Icons.flag_outlined), title: Text('Reportar evento')),
        ),
        if (organizerId != null)
          const PopupMenuItem(
            key: Key('eventDetail.reportOrganizer'),
            value: _ReportAction.organizer,
            child: ListTile(leading: Icon(Icons.person_off_outlined), title: Text('Reportar al organizador')),
          ),
      ],
    );
  }
}

class _CancelledBanner extends StatelessWidget {
  const _CancelledBanner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.errorContainer, borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.event_busy, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text('El organizador canceló este evento.', style: TextStyle(color: colors.onErrorContainer)),
            ),
          ],
        ),
      ),
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
              // Negro sobre el color de categoría (AA); el blanco no llega a 4,5:1 en estos colores.
              labelStyle: const TextStyle(color: FestaColors.textPrimary),
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
                          style: theme.textTheme.bodySmall?.copyWith(color: FestaColors.textSuccess),
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
