import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/design.dart';
import '../../../core/network/api_exception.dart';
import '../application/team_providers.dart';
import '../data/team_merchants_api.dart';
import '../domain/pending_merchant.dart';
import 'submitted_formatters.dart';

/// SCRUM-61 (RF3), Figma «29 · Solicitud de comercio»: los datos que envió el comercio y la decisión del
/// equipo. Al aprobar, user-service le da el rol `merchant` y ya puede publicar; al rechazar, el comercio ve
/// el motivo para corregir. Cierra la pantalla con el mensaje que la lista muestra.
class MerchantRequestScreen extends ConsumerStatefulWidget {
  const MerchantRequestScreen({required this.merchant, super.key, this.now});

  final PendingMerchant merchant;
  final DateTime Function()? now;

  @override
  ConsumerState<MerchantRequestScreen> createState() => _MerchantRequestScreenState();
}

class _MerchantRequestScreenState extends ConsumerState<MerchantRequestScreen> {
  bool _sending = false;

  String get _name => widget.merchant.profile.draft.businessName;

  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Aprobar a $_name?'),
        content: const Text('Podrá publicar eventos y vender boletas en Festa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            key: const Key('team.approve.confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await _send((api) => api.approve(widget.merchant.accountId), '$_name quedó verificado.');
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectDialog(name: _name),
    );
    if (reason == null) return;
    await _send(
      (api) => api.reject(widget.merchant.accountId, reason),
      '$_name fue rechazado. Verá el motivo para corregir.',
    );
  }

  Future<void> _send(Future<void> Function(TeamMerchantsApi api) action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _sending = true);
    try {
      await action(ref.read(teamMerchantsApiProvider));
      ref.invalidate(pendingMerchantsProvider);
      navigator.pop(done);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.fieldErrors.values.firstOrNull ?? e.message)));
      // Con respuesta del servidor (por ejemplo, otra persona del equipo ya lo revisó) la lista cambió.
      // Sin red se deja todo igual para reintentar.
      if (e.statusCode != null) ref.invalidate(pendingMerchantsProvider);
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final draft = widget.merchant.profile.draft;
    final submitted = widget.merchant.submittedAt;
    final now = (widget.now ?? DateTime.now)();
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitud')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(FestaSpace.xl, FestaSpace.xs, FestaSpace.xl, FestaSpace.xl),
        children: [
          Text(draft.businessName, style: text.headlineMedium),
          const SizedBox(height: FestaSpace.md),
          _Field(label: 'Categoría', value: draft.category.label),
          _Field(label: 'Ubicación', value: draft.address),
          if (draft.description.trim().isNotEmpty) _Field(label: 'Descripción', value: draft.description),
          if (submitted != null)
            _Field(label: 'Enviado', value: '${submittedLong(submitted, now)} · cuenta de comercio'),
          const SizedBox(height: FestaSpace.xs),
          const _InfoBox('Revisa que el lugar y la descripción sean reales antes de aprobar.'),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(FestaSpace.xl, FestaSpace.xs, FestaSpace.xl, FestaSpace.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                key: const Key('team.approve'),
                onPressed: _sending ? null : _approve,
                child: const Text('Aprobar comercio'),
              ),
              const SizedBox(height: FestaSpace.sm),
              OutlinedButton(
                key: const Key('team.reject'),
                onPressed: _sending ? null : _reject,
                child: const Text('Rechazar con motivo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dato de la solicitud: etiqueta pequeña y el valor debajo, como en el Figma 29.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: FestaSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodySmall?.copyWith(color: FestaColors.textSecondary)),
          const SizedBox(height: FestaSpace.xxs),
          Text(value, style: text.bodyLarge),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: FestaColors.bgSubtle, borderRadius: FestaRadius.mdAll),
    child: Padding(
      padding: const EdgeInsets.all(FestaSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 20, color: FestaColors.textSecondary),
          const SizedBox(width: FestaSpace.xs),
          Expanded(
            child: Text(text, style: const TextStyle(color: FestaColors.textSecondary)),
          ),
        ],
      ),
    ),
  );
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
