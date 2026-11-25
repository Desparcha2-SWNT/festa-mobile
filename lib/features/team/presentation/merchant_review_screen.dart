import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/design.dart';
import '../../../core/network/api_exception.dart';
import '../application/team_providers.dart';
import '../domain/pending_merchant.dart';
import 'merchant_request_screen.dart';
import 'submitted_formatters.dart';

/// SCRUM-61 (RF3), Figma «28 · Revisión de comercios»: el equipo Festa ve los comercios que esperan
/// verificación y abre cada solicitud para aprobarla o rechazarla.
class MerchantReviewScreen extends ConsumerWidget {
  const MerchantReviewScreen({super.key, this.now});

  /// Hora de referencia para «hace 2 h»; en las pruebas se fija.
  final DateTime Function()? now;

  Future<void> _open(BuildContext context, PendingMerchant merchant) async {
    final messenger = ScaffoldMessenger.of(context);
    final decision = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => MerchantRequestScreen(merchant: merchant, now: now),
      ),
    );
    if (decision != null) messenger.showSnackBar(SnackBar(content: Text(decision)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingMerchantsProvider);
    final count = pending.value?.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Revisión de comercios')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(FestaSpace.md, FestaSpace.xs, FestaSpace.md, 0),
            // user-service solo lista los pendientes (`GET /users/admin/merchants`): las pestañas «Aprobados» y
            // «Rechazados» del Figma necesitan un endpoint que todavía no existe.
            child: ChoiceChip(
              key: const Key('team.merchants.tab.pending'),
              label: Text(count == null ? 'Pendientes' : 'Pendientes ($count)'),
              selected: true,
              onSelected: (_) {},
            ),
          ),
          Expanded(
            child: switch (pending) {
              AsyncData(:final value) => RefreshIndicator(
                onRefresh: () => ref.refresh(pendingMerchantsProvider.future),
                child: value.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          _Message(
                            key: Key('team.merchants.empty'),
                            title: 'No hay comercios por verificar',
                            body: 'Cuando un comercio envíe su perfil, aparecerá aquí.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        key: const Key('team.merchants.list'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(FestaSpace.md),
                        itemCount: value.length,
                        separatorBuilder: (_, _) => const SizedBox(height: FestaSpace.sm),
                        itemBuilder: (context, i) => _MerchantCard(
                          merchant: value[i],
                          now: (now ?? DateTime.now)(),
                          onTap: () => _open(context, value[i]),
                        ),
                      ),
              ),
              AsyncError(:final error) => Center(
                child: _Message(
                  key: const Key('team.merchants.error'),
                  title: 'No pudimos cargar los comercios',
                  body: error is ApiException ? error.message : 'Intenta de nuevo.',
                  action: OutlinedButton(
                    key: const Key('team.merchants.retry'),
                    onPressed: () => ref.invalidate(pendingMerchantsProvider),
                    child: const Text('Reintentar'),
                  ),
                ),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}

/// Tarjeta del Figma 28: nombre, «Categoría · Enviado hace 2 h», la insignia «Pendiente» y la flecha.
class _MerchantCard extends StatelessWidget {
  const _MerchantCard({required this.merchant, required this.now, required this.onTap});

  final PendingMerchant merchant;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final draft = merchant.profile.draft;
    final submitted = merchant.submittedAt;
    final details = submitted == null
        ? draft.category.label
        : '${draft.category.label} · Enviado ${submittedShort(submitted, now)}';
    return Card(
      key: Key('team.merchant.${merchant.accountId}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(FestaSpace.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(draft.businessName, style: text.titleMedium),
                    const SizedBox(height: FestaSpace.xxs),
                    Text(details, style: text.bodySmall?.copyWith(color: FestaColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: FestaSpace.xs),
              const PendingBadge(),
              const SizedBox(width: FestaSpace.xs),
              const Icon(Icons.chevron_right, color: FestaColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Insignia amarilla «Pendiente» del Figma 28.
class PendingBadge extends StatelessWidget {
  const PendingBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: FestaSpace.sm, vertical: FestaSpace.xxs),
    decoration: BoxDecoration(color: FestaColors.bgLive, borderRadius: BorderRadius.circular(FestaRadius.full)),
    child: Text('Pendiente', style: Theme.of(context).textTheme.labelMedium),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body, this.action, super.key});

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(FestaSpace.xxl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: FestaSpace.xs),
        Text(body, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: FestaSpace.xl), action!],
      ],
    ),
  );
}
