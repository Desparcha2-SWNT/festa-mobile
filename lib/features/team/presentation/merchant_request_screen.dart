import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/design.dart';
import '../../../core/network/api_exception.dart';
import '../application/team_providers.dart';
import '../data/team_merchants_api.dart';
import '../domain/pending_merchant.dart';
import 'submitted_formatters.dart';
import 'team_widgets.dart';

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
    // Todo lo que se usa después del `await` se toma antes: el contenedor de Riverpod sigue sirviendo para
    // refrescar la lista aunque esta pantalla ya no esté. Mientras se envía, el botón atrás queda bloqueado
    // (PopScope), así la decisión no queda a medias.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final api = ref.read(teamMerchantsApiProvider);
    setState(() => _sending = true);
    try {
      await action(api);
      container.invalidate(pendingMerchantsProvider);
      if (mounted) navigator.pop(done);
    } on ApiException catch (e) {
      final message = e.fieldErrors.values.firstOrNull ?? e.message;
      // Con respuesta del servidor la lista pudo cambiar (por ejemplo, otra persona del equipo ya la revisó).
      // Sin red se deja todo igual para reintentar.
      if (e.statusCode != null) container.invalidate(pendingMerchantsProvider);
      if (!mounted) return;
      if (_alreadyResolved(e)) {
        // Ya no hay nada que decidir aquí: se vuelve a la lista con el mensaje del servidor.
        navigator.pop(message);
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(message)));
      setState(() => _sending = false);
    }
  }

  /// La solicitud ya no está pendiente o ya no existe: 404, 409, o un 400 de estado (sin errores de campos).
  static bool _alreadyResolved(ApiException e) =>
      e.statusCode == 404 || e.statusCode == 409 || (e.statusCode == 400 && e.fieldErrors.isEmpty);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final draft = widget.merchant.profile.draft;
    final submitted = widget.merchant.submittedAt;
    final now = (widget.now ?? DateTime.now)();
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        appBar: AppBar(title: const Text('Solicitud')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(FestaSpace.xl, FestaSpace.xs, FestaSpace.xl, FestaSpace.xl),
          children: [
            Text(draft.businessName, style: text.headlineMedium),
            const SizedBox(height: FestaSpace.md),
            TeamField(label: 'Categoría', value: draft.category.label),
            TeamField(label: 'Ubicación', value: draft.address),
            if (draft.description.trim().isNotEmpty) TeamField(label: 'Descripción', value: draft.description),
            if (submitted != null)
              TeamField(label: 'Enviado', value: '${submittedLong(submitted, now)} · cuenta de comercio'),
            const SizedBox(height: FestaSpace.xs),
            const TeamInfoBox('Revisa que el lugar y la descripción sean reales antes de aprobar.'),
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

  // user-service cuenta con `@Size(max = 500)`, en unidades UTF-16 como `String.length`. El contador de la
  // pantalla cuenta igual: con `maxLength` de Flutter contaría caracteres visibles y un emoji (que vale 2)
  // dejaría el botón gris sin explicación.
  int get _length => _reason.text.trim().length;

  bool get _tooLong => _length > maxLength;

  bool get _valid => _length > 0 && !_tooLong;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Rechazar a ${widget.name}'),
    content: TextField(
      key: const Key('team.reject.reason'),
      controller: _reason,
      autofocus: true,
      maxLines: 4,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: 'Motivo',
        hintText: 'Por ejemplo: la dirección no coincide con el lugar del negocio.',
        counterText: '$_length/$maxLength',
        errorText: _tooLong ? 'El motivo pasa de $maxLength caracteres (los emojis cuentan doble).' : null,
        // En un diálogo angosto el aviso no cabe en una línea; sin esto se corta con «…».
        errorMaxLines: 2,
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
