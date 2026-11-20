import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/network/api_exception.dart';
import '../application/events_providers.dart';
import '../domain/event.dart';
import '../domain/event_draft.dart';
import 'widgets/event_form.dart';

/// SCRUM-67: el creador edita o cancela su evento (RF4). Diseño: Figma «25 · Editar evento» y
/// «24b · Cancelar evento». Solo se envían los campos que cambiaron.
class EditEventScreen extends ConsumerWidget {
  const EditEventScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(eventDetailProvider(eventId));
    return Scaffold(
      appBar: AppBar(title: const Text('Editar evento')),
      body: switch (event) {
        AsyncData(:final value) when value.isEditable => _EditForm(event: value),
        AsyncData() => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Este evento ya no se puede editar.', textAlign: TextAlign.center),
          ),
        ),
        AsyncError(:final error) when !event.isLoading => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error is ApiException ? error.message : 'No pudimos cargar el evento.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(eventDetailProvider(eventId)),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.event});

  final Event event;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  late final EventDraft _original = EventDraft.fromEvent(widget.event);
  bool _busy = false;
  ApiException? _error;

  /// Después de editar o cancelar, la lista, el detalle y el mapa se vuelven a pedir para que el
  /// cambio se vea de inmediato.
  void _refreshEventViews() {
    ref
      ..invalidate(myEventsProvider)
      ..invalidate(eventDetailProvider(widget.event.id))
      ..invalidate(nearbyEventsProvider);
  }

  Future<void> _run(Future<void> Function() action, {required String done}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      _refreshEventViews();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      context.go(Routes.myEvents);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(EventDraft draft) async {
    final changes = draft.changesFrom(_original);
    if (changes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hiciste cambios.')));
      return;
    }
    await _run(() => ref.read(eventsApiProvider).update(widget.event.id, changes), done: 'Cambios guardados.');
  }

  Future<void> _cancel() async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _CancelDialog());
    if (reason == null) return;
    await _run(() => ref.read(eventsApiProvider).cancel(widget.event.id, reason: reason), done: 'Evento cancelado.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EventForm(
      initial: _original,
      submitLabel: 'Guardar cambios',
      submitting: _busy,
      onSubmit: _save,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            Text(_error!.message, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
          ],
          Text(
            'Si cambias la fecha o el lugar, avisaremos a quienes ya confirmaron.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      footer: TextButton(
        key: const Key('editEvent.cancel'),
        onPressed: _busy ? null : _cancel,
        style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
        child: const Text('Cancelar evento'),
      ),
    );
  }
}

/// Confirma la cancelación y pide el motivo, que les llega a quienes habían confirmado.
/// Devuelve el motivo, o `null` si el organizador decide mantener el evento.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog();

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _reason = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('¿Cancelar este evento?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Avisaremos a las personas que confirmaron. Esta acción no se puede deshacer.'),
        const SizedBox(height: 16),
        TextField(
          key: const Key('cancelEvent.reason'),
          controller: _reason,
          minLines: 1,
          maxLines: 3,
          maxLength: 500,
          onChanged: (_) {
            if (_showError) setState(() => _showError = false);
          },
          decoration: InputDecoration(
            labelText: 'Motivo (lo verán los asistentes)',
            errorText: _showError ? 'Escribe el motivo.' : null,
          ),
        ),
        const SizedBox(height: 16),
        // Como en el Figma «24b»: la acción destructiva en tinta y, debajo, la que no cambia nada.
        FilledButton(
          key: const Key('cancelEvent.confirm'),
          style: FilledButton.styleFrom(backgroundColor: FestaTheme.ink, foregroundColor: Colors.white),
          onPressed: _confirm,
          child: const Text('Sí, cancelar evento'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Mantener evento')),
      ],
    ),
  );
}
