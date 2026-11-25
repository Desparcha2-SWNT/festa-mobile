import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/design.dart';
import '../../../core/network/api_exception.dart';
import '../application/reports_providers.dart';
import '../domain/report.dart';

/// SCRUM-109 (RF14): abre el formulario para reportar un evento o a un usuario. Si el reporte se envía,
/// avisa con un SnackBar. Devuelve `true` si se envió.
Future<bool> showReportSheet(
  BuildContext context, {
  required ReportTarget target,
  required String targetId,
  required String subject,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ReportSheet(target: target, targetId: targetId, subject: subject),
  );
  if (sent ?? false) {
    messenger.showSnackBar(const SnackBar(content: Text('Gracias. El equipo de Festa revisará tu reporte.')));
  }
  return sent ?? false;
}

/// Formulario del reporte: un motivo (obligatorio) y un comentario opcional de hasta 500 caracteres,
/// el máximo que acepta user-service.
class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({super.key, required this.target, required this.targetId, required this.subject});

  final ReportTarget target;
  final String targetId;

  /// Lo que se reporta, tal como lo ve el usuario: el título del evento o el nombre de la persona.
  final String subject;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  static const maxCommentLength = 500;

  final _comment = TextEditingController();
  ReportReason? _reason;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    // user-service cuenta con `@Size(max = 500)`, en unidades UTF-16 como `String.length`. El contador del
    // campo cuenta lo que se ve, así que un comentario con muchos emojis puede pasarlo: se revisa aquí.
    if (_comment.text.trim().length > maxCommentLength) {
      setState(() => _error = 'El comentario es muy largo. Acórtalo un poco (los emojis cuentan doble).');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(reportsApiProvider)
          .create(target: widget.target, targetId: widget.targetId, reason: reason, comment: _comment.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.fieldErrors.values.firstOrNull ?? e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final title = switch (widget.target) {
      ReportTarget.event => 'Reportar evento',
      ReportTarget.user => 'Reportar al organizador',
    };
    return Padding(
      // El teclado no tapa el comentario ni el botón.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(FestaSpace.xl, 0, FestaSpace.xl, FestaSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: text.titleLarge),
              const SizedBox(height: FestaSpace.xxs),
              Text(widget.subject, style: text.bodyMedium?.copyWith(color: FestaColors.textSecondary)),
              const SizedBox(height: FestaSpace.md),
              Text('¿Qué está pasando?', style: text.titleSmall),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (reason) {
                  if (!_sending) setState(() => _reason = reason);
                },
                child: Column(
                  children: [
                    for (final reason in ReportReason.values)
                      RadioListTile<ReportReason>(
                        key: Key('report.reason.${reason.api}'),
                        value: reason,
                        title: Text(reason.label),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: FestaSpace.xs),
              TextField(
                key: const Key('report.comment'),
                controller: _comment,
                enabled: !_sending,
                maxLength: maxCommentLength,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Cuéntanos más (opcional)',
                  hintText: 'Lo que nos ayude a revisarlo',
                ),
              ),
              Text(
                'El equipo de Festa revisa cada reporte a mano antes de tomar una decisión.',
                style: text.bodySmall?.copyWith(color: FestaColors.textSecondary),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: FestaSpace.sm),
                Text(
                  error,
                  key: const Key('report.error'),
                  style: text.bodyMedium?.copyWith(color: FestaColors.textError),
                ),
              ],
              const SizedBox(height: FestaSpace.md),
              FilledButton(
                key: const Key('report.send'),
                onPressed: _reason == null || _sending ? null : _send,
                child: _sending
                    ? const SizedBox.square(dimension: FestaSpace.lg, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Enviar reporte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
