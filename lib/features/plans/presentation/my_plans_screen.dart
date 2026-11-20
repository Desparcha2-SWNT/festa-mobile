import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/design.dart';
import '../../../core/network/api_exception.dart';
import '../application/plans_providers.dart';
import '../domain/my_plan.dart';
import 'plan_formatters.dart';

/// «Mis planes» (SCRUM-142, pantalla 21 del Figma): los eventos gratis a los que el usuario confirmó
/// asistencia, en dos pestañas. Las entradas compradas van aparte (SCRUM-26).
class MyPlansScreen extends StatelessWidget {
  const MyPlansScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: PlansTab.values.length,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Mis planes'),
        bottom: const TabBar(
          tabs: [
            Tab(key: Key('plans.tab.upcoming'), text: 'Próximos'),
            Tab(key: Key('plans.tab.past'), text: 'Pasados'),
          ],
        ),
      ),
      body: const TabBarView(children: [_PlansTabView(PlansTab.upcoming), _PlansTabView(PlansTab.past)]),
    ),
  );
}

class _PlansTabView extends ConsumerWidget {
  const _PlansTabView(this.tab);

  final PlansTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = plansControllerProvider(tab);
    return switch (ref.watch(provider)) {
      AsyncData(:final value) => RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: value.items.isEmpty
            ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [_EmptyView(tab)])
            : _PlanList(tab: tab, state: value, onLoadMore: () => _loadMore(context, ref)),
      ),
      AsyncError(:final error) => _ErrorView(tab: tab, error: error, onRetry: () => ref.invalidate(provider)),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  /// El error del refresh ya queda en el estado del provider (la pantalla muestra el error con
  /// «Reintentar»); aquí solo se evita que el `RefreshIndicator` lo deje sin capturar.
  Future<void> _refresh(WidgetRef ref) =>
      ref.refresh(plansControllerProvider(tab).future).then((_) {}, onError: (Object _) {});

  Future<void> _loadMore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(plansControllerProvider(tab).notifier).loadMore();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      // Una página que no se puede leer (p. ej. un JSON inesperado) no es una ApiException: sin este
      // caso el error escapaba sin que la persona viera nada. La lista ya cargada se conserva.
      messenger.showSnackBar(const SnackBar(content: Text('No pudimos cargar más planes. Intenta de nuevo.')));
    }
  }
}

class _PlanList extends StatelessWidget {
  const _PlanList({required this.tab, required this.state, required this.onLoadMore});

  final PlansTab tab;
  final PlansState state;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) => ListView.separated(
    key: Key('plans.list.${tab.name}'),
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(FestaSpace.md),
    itemCount: state.items.length + (state.hasMore ? 1 : 0),
    separatorBuilder: (_, _) => const SizedBox(height: FestaSpace.sm),
    itemBuilder: (context, i) {
      if (i < state.items.length) return _PlanCard(plan: state.items[i]);
      return OutlinedButton(
        key: Key('plans.loadMore.${tab.name}'),
        onPressed: onLoadMore,
        child: Text('Ver más (${state.total - state.items.length})'),
      );
    },
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final MyPlan plan;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final secondary = text.bodyMedium?.copyWith(color: FestaColors.textSecondary);
    final cancelled = plan.status == PlanStatus.eventCancelled;
    return Card(
      key: Key('plans.item.${plan.attendanceId}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(FestaSpace.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Cover(url: plan.coverImageUrl),
            const SizedBox(width: FestaSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: text.titleMedium?.copyWith(
                      decoration: cancelled ? TextDecoration.lineThrough : null,
                      color: cancelled ? FestaColors.textSecondary : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: FestaSpace.xxs),
                  Text(formatPlanDate(plan.startsAt), style: secondary),
                  if (plan.venueName != null && plan.venueName!.trim().isNotEmpty)
                    Text(plan.venueName!, style: secondary, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (cancelled) ...[const SizedBox(height: FestaSpace.xs), const _CancelledBadge()],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Portada del evento; si no hay o no carga, un recuadro con ícono del mismo tamaño.
class _Cover extends StatelessWidget {
  const _Cover({this.url});

  static const _size = 72.0;

  final String? url;

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: FestaColors.bgBrandSoft,
      child: Center(child: Icon(Icons.event_outlined, color: FestaColors.textBrand)),
    );
    return ClipRRect(
      borderRadius: FestaRadius.smAll,
      child: SizedBox.square(
        dimension: _size,
        child: url == null
            ? placeholder
            : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
      ),
    );
  }
}

class _CancelledBadge extends StatelessWidget {
  const _CancelledBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: FestaSpace.xs, vertical: FestaSpace.xxs),
    decoration: BoxDecoration(color: FestaColors.bgErrorSoft, borderRadius: FestaRadius.smAll),
    child: Text(
      'Evento cancelado',
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: FestaColors.textError),
    ),
  );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView(this.tab);

  final PlansTab tab;

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (tab) {
      PlansTab.upcoming => (
        'Todavía no tienes planes',
        'Cuando confirmes tu asistencia a un evento gratis, aparecerá aquí.',
      ),
      PlansTab.past => ('Aún no hay planes pasados', 'Los eventos a los que asististe quedarán aquí.'),
    };
    return Padding(
      padding: const EdgeInsets.all(FestaSpace.xxl),
      child: Column(
        children: [
          const Icon(Icons.event_available_outlined, size: FestaSpace.xxxl * 1.4, color: FestaColors.textSecondary),
          const SizedBox(height: FestaSpace.md),
          Text(
            title,
            key: Key('plans.empty.${tab.name}'),
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: FestaSpace.xs),
          Text(body, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.tab, required this.error, required this.onRetry});

  final PlansTab tab;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(FestaSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: FestaSpace.xxxl * 1.4, color: FestaColors.textSecondary),
          const SizedBox(height: FestaSpace.md),
          Text(
            'No pudimos cargar tus planes',
            key: Key('plans.error.${tab.name}'),
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: FestaSpace.xs),
          Text(
            error is ApiException ? (error as ApiException).message : 'Intenta de nuevo.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: FestaSpace.xl),
          OutlinedButton(key: Key('plans.retry.${tab.name}'), onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}
