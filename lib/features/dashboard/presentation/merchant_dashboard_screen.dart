import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/design.dart';
import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../plans/presentation/plan_formatters.dart';
import '../application/dashboard_providers.dart';
import '../domain/merchant_dashboard.dart';

/// «Mis resultados» (RF15, SCRUM-113): vista simple del comercio con lo que pasó en sus eventos.
/// Solo conteos: confirmados, ingresos, vistas, compartidos, recomendaciones de la IA y ventas.
class MerchantDashboardScreen extends ConsumerWidget {
  const MerchantDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(merchantDashboardProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis resultados')),
      body: switch (dashboard) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(merchantDashboardProvider.future).then((_) {}, onError: (Object _) {}),
          child: value.isEmpty ? const _EmptyView() : _Content(dashboard: value),
        ),
        AsyncError(:final error) => _ErrorView(
          message: error is ApiException ? error.message : 'No pudimos cargar tus resultados.',
          onRetry: () => ref.invalidate(merchantDashboardProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.dashboard});

  final MerchantDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final totals = dashboard.totals;
    final theme = Theme.of(context).textTheme;
    return ListView(
      key: const Key('dashboard.list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(FestaSpace.md),
      children: [
        Wrap(
          spacing: FestaSpace.sm,
          runSpacing: FestaSpace.sm,
          children: [
            _Metric(keyName: 'events', label: 'Eventos', value: '${totals.events}'),
            _Metric(keyName: 'attendees', label: 'Confirmaron asistencia', value: '${totals.attendees}'),
            _Metric(keyName: 'checkIns', label: 'Ingresaron', value: '${totals.checkIns}'),
            _Metric(keyName: 'views', label: 'Vieron tus eventos', value: '${totals.views}'),
            _Metric(keyName: 'shares', label: 'Compartidos', value: '${totals.shares}'),
            _Metric(keyName: 'ai', label: 'Recomendados por la IA', value: '${totals.recommendedByAi}'),
            _Metric(keyName: 'tickets', label: 'Boletas vendidas', value: '${totals.ticketsSold}'),
            _Metric(keyName: 'gross', label: 'Ventas', value: formatCop(totals.grossCents)),
          ],
        ),
        const SizedBox(height: FestaSpace.xs),
        Text(
          'Las ventas son el precio de las boletas, antes de la comisión de la pasarela de pagos, que se descuenta del pago al comercio.',
          key: const Key('dashboard.salesNote'),
          style: theme.bodySmall?.copyWith(color: FestaColors.textSecondary),
        ),
        const SizedBox(height: FestaSpace.lg),
        Text('Por evento', style: theme.titleMedium),
        const SizedBox(height: FestaSpace.xs),
        if (dashboard.events.isEmpty)
          Text(
            'Todavía no hay detalle por evento.',
            style: theme.bodyMedium?.copyWith(color: FestaColors.textSecondary),
          )
        else
          for (final event in dashboard.events) ...[_EventTile(event: event), const SizedBox(height: FestaSpace.xs)],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.keyName, required this.label, required this.value});

  final String keyName;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final width = (MediaQuery.sizeOf(context).width - FestaSpace.md * 2 - FestaSpace.sm) / 2;
    return Container(
      key: Key('dashboard.metric.$keyName'),
      width: width,
      padding: const EdgeInsets.all(FestaSpace.sm),
      decoration: BoxDecoration(color: FestaColors.bgMuted, borderRadius: BorderRadius.circular(FestaRadius.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: theme.headlineSmall),
          const SizedBox(height: FestaSpace.xxs),
          Text(label, style: theme.bodySmall?.copyWith(color: FestaColors.textSecondary)),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final DashboardEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final secondary = theme.bodySmall?.copyWith(color: FestaColors.textSecondary);
    final startsAt = event.startsAt;
    return Material(
      color: FestaColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FestaRadius.md),
        side: const BorderSide(color: FestaColors.border),
      ),
      child: InkWell(
        key: Key('dashboard.event.${event.eventId}'),
        borderRadius: BorderRadius.circular(FestaRadius.md),
        onTap: () => context.push(Routes.eventDetail(event.eventId)),
        child: Padding(
          padding: const EdgeInsets.all(FestaSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title, style: theme.titleSmall),
              if (startsAt != null) Text(formatPlanDate(startsAt), style: secondary),
              if (event.isCancelled)
                Text('Evento cancelado', style: theme.labelMedium?.copyWith(color: FestaColors.textError)),
              const SizedBox(height: FestaSpace.xxs),
              Text(
                '${event.attendees} confirmados · ${event.checkIns} ingresaron · ${event.views} vistas',
                style: theme.bodyMedium,
              ),
              if (event.ticketsSold > 0)
                Text('${event.ticketsSold} boletas · ${formatCop(event.grossCents)}', style: theme.bodyMedium),
              if (event.showUpRate != null)
                Text('Asistencia real: ${(event.showUpRate! * 100).round()} %', style: secondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      Padding(
        padding: const EdgeInsets.all(FestaSpace.xl),
        child: Text(
          'Cuando publiques tu primer evento, aquí verás cuánta gente lo vio, confirmó y llegó.',
          key: const Key('dashboard.empty'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: FestaColors.textSecondary),
        ),
      ),
    ],
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(FestaSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, key: const Key('dashboard.error'), textAlign: TextAlign.center),
          const SizedBox(height: FestaSpace.md),
          OutlinedButton(key: const Key('dashboard.retry'), onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}

/// «$ 35.000» a partir de centavos de peso.
String formatCop(int cents) {
  final pesos = (cents / 100).round().toString();
  final grouped = pesos.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return '\$ $grouped';
}
