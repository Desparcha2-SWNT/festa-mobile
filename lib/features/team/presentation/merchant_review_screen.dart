import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/design.dart';
import '../../../core/network/api_exception.dart';
import '../../plans/presentation/plan_formatters.dart';
import '../application/team_providers.dart';
import '../domain/pending_merchant.dart';

/// SCRUM-61 (RF3): el equipo Festa revisa los comercios pendientes y los aprueba o los rechaza con un motivo.
/// Al aprobar, user-service le da el rol `merchant` a la cuenta y el comercio ya puede publicar.
class MerchantReviewScreen extends ConsumerStatefulWidget {
  const MerchantReviewScreen({super.key});

  @override
  ConsumerState<MerchantReviewScreen> createState() => _MerchantReviewScreenState();
}

class _MerchantReviewScreenState extends ConsumerState<MerchantReviewScreen> {
  /// Comercios con una decisión en camino: sus botones se desactivan para no enviarla dos veces.
  final _busy = <String>{};

  Future<void> _decide(PendingMerchant merchant, {required bool approve}) async {
    final name = merchant.profile.draft.businessName;
    final String? reason;
    if (approve) {
      if (!await _confirmApprove(name)) return;
      reason = null;
    } else {
      reason = await _askRejectReason(name);
      if (reason == null) return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(teamMerchantsApiProvider);
    setState(() => _busy.add(merchant.accountId));
    try {
      if (approve) {
        await api.approve(merchant.accountId);
      } else {
        await api.reject(merchant.accountId, reason!);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(approve ? '$name quedó verificado.' : '$name fue rechazado. Verá el motivo para corregir.'),
        ),
      );
      ref.invalidate(pendingMerchantsProvider);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.fieldErrors.values.firstOrNull ?? e.message)));
      // Con respuesta del servidor (por ejemplo, otra persona del equipo ya lo revisó) la lista puede haber
      // cambiado: se vuelve a pedir. Sin red se deja como está para reintentar.
      if (e.statusCode != null) ref.invalidate(pendingMerchantsProvider);
    } finally {
      if (mounted) setState(() => _busy.remove(merchant.accountId));
    }
  }

  Future<bool> _confirmApprove(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Verificar a $name?'),
        content: const Text('Podrá publicar eventos y vender boletas en Festa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            key: const Key('team.approve.confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verificar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<String?> _askRejectReason(String name) => showDialog<String>(
    context: context,
    builder: (_) => _RejectDialog(name: name),
  );

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingMerchantsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Comercios por verificar')),
      body: switch (pending) {
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
                    busy: _busy.contains(value[i].accountId),
                    onApprove: () => _decide(value[i], approve: true),
                    onReject: () => _decide(value[i], approve: false),
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
    );
  }
}

class _MerchantCard extends StatelessWidget {
  const _MerchantCard({required this.merchant, required this.busy, required this.onApprove, required this.onReject});

  final PendingMerchant merchant;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final secondary = text.bodyMedium?.copyWith(color: FestaColors.textSecondary);
    final draft = merchant.profile.draft;
    final submitted = merchant.submittedAt;
    return Card(
      key: Key('team.merchant.${merchant.accountId}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(FestaSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(draft.businessName, style: text.titleMedium),
            const SizedBox(height: FestaSpace.xxs),
            Text(draft.category.label, style: secondary),
            Text(draft.address, style: secondary),
            if (draft.description.trim().isNotEmpty) ...[
              const SizedBox(height: FestaSpace.xs),
              Text(draft.description),
            ],
            if (submitted != null) ...[
              const SizedBox(height: FestaSpace.xs),
              Text('Enviado el ${formatPlanDate(submitted)}', style: text.bodySmall),
            ],
            const SizedBox(height: FestaSpace.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  key: Key('team.reject.${merchant.accountId}'),
                  onPressed: busy ? null : onReject,
                  child: const Text('Rechazar'),
                ),
                const SizedBox(width: FestaSpace.sm),
                FilledButton(
                  key: Key('team.approve.${merchant.accountId}'),
                  onPressed: busy ? null : onApprove,
                  child: const Text('Verificar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pide el motivo del rechazo: obligatorio y de hasta 500 caracteres, como exige user-service. El comercio
/// lo ve en su pantalla de estado para corregir el perfil.
class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.name});

  final String name;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  static const maxLength = 500;

  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  // user-service cuenta con `@Size(max = 500)`, en unidades UTF-16 como `String.length`.
  bool get _valid => _reason.text.trim().isNotEmpty && _reason.text.trim().length <= maxLength;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Rechazar a ${widget.name}'),
    content: TextField(
      key: const Key('team.reject.reason'),
      controller: _reason,
      autofocus: true,
      maxLines: 4,
      maxLength: maxLength,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        labelText: 'Motivo',
        hintText: 'Por ejemplo: la dirección no coincide con el lugar del negocio.',
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(
        key: const Key('team.reject.confirm'),
        onPressed: _valid ? () => Navigator.pop(context, _reason.text.trim()) : null,
        child: const Text('Rechazar'),
      ),
    ],
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
