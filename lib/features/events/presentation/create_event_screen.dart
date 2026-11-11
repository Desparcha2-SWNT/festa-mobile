import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../../merchant/application/merchant_controller.dart';
import '../../merchant/domain/merchant_profile.dart';
import '../application/events_providers.dart';
import '../domain/event.dart';
import '../domain/event_draft.dart';
import 'event_category_color.dart';
import 'event_formatters.dart';
import 'widgets/event_form.dart';

/// SCRUM-63: un comercio verificado crea un evento (RF4). Diseño: Figma «5 · Crear evento · Datos»
/// y «7 · Vista previa». El paso de descripción con IA (Figma «6») llega con SCRUM-101.
class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  /// Lo último que se llenó; se conserva al volver de la vista previa para seguir editando.
  EventDraft? _draft;
  bool _previewing = false;
  bool _publishing = false;
  ApiException? _error;

  /// El lugar arranca en el del comercio y la fecha en mañana por la noche: lo más común.
  EventDraft _defaults(MerchantDraft merchant) {
    final tomorrow = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));
    return EventDraft(
      title: '',
      venueName: '',
      venueAddress: merchant.address,
      location: merchant.location,
      startsAt: tomorrow.add(const Duration(hours: 18)),
      endsAt: tomorrow.add(const Duration(hours: 21)),
      category:
          EventCategory.values.where((c) => c.name == merchant.category.name).firstOrNull ?? EventCategory.cultural,
      description: '',
    );
  }

  /// [merchantId] es el id de la cuenta: hay un comercio por cuenta.
  Future<void> _publish(EventDraft draft, MerchantDraft merchant, String merchantId) async {
    if (_publishing) return;
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      await ref.read(eventsApiProvider).create(draft, merchantId: merchantId, organizerName: merchant.businessName);
      ref.invalidate(myEventsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Evento publicado!')));
      context.go(Routes.myEvents);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final merchant = ref.watch(merchantControllerProvider).value?.draft;
    final accountId = ref.watch(sessionControllerProvider.select((session) => session.value?.id));
    if (merchant == null || accountId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final draft = _draft;
    final previewing = _previewing && draft != null;
    void backToForm() => setState(() => _previewing = false);
    return PopScope(
      // Desde la vista previa, «atrás» vuelve a los datos sin perder lo escrito.
      canPop: !previewing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) backToForm();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(previewing ? 'Vista previa' : 'Crear evento')),
        body: previewing
            ? _Preview(
                draft: draft,
                error: _error?.message,
                publishing: _publishing,
                onPublish: () => _publish(draft, merchant, accountId),
                onEdit: backToForm,
              )
            : EventForm(
                initial: draft ?? _defaults(merchant),
                submitLabel: 'Continuar',
                header: const _StepLabel('Paso 1 de 2 · Datos del evento'),
                onSubmit: (value) => setState(() {
                  _draft = value;
                  _previewing = true;
                  _error = null;
                }),
              ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(text, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary));
  }
}

/// Así se verá el evento en el mapa (Figma «7 · Vista previa»).
class _Preview extends StatelessWidget {
  const _Preview({
    required this.draft,
    required this.error,
    required this.publishing,
    required this.onPublish,
    required this.onEdit,
  });

  final EventDraft draft;
  final String? error;
  final bool publishing;
  final VoidCallback onPublish;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final capacity = draft.capacity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const _StepLabel('Paso 2 de 2 · Revisa y publica'),
              const SizedBox(height: 16),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 120,
                      color: draft.category.color.withValues(alpha: 0.2),
                      alignment: Alignment.topLeft,
                      padding: const EdgeInsets.all(12),
                      child: Chip(
                        label: Text(draft.category.label),
                        backgroundColor: draft.category.color,
                        labelStyle: const TextStyle(color: Colors.white),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(draft.title, style: theme.textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            '${draft.venueName} · ${EventFormatters.date(draft.startsAt)}, '
                            '${EventFormatters.time(draft.startsAt)} a ${EventFormatters.time(draft.endsAt)}',
                            style: secondary,
                          ),
                          if (capacity != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Cupo: $capacity personas',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(draft.description),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Así se verá tu evento en el mapa de Festa. Puedes volver atrás para cambiar lo que quieras.',
                style: secondary,
              ),
              if (error != null) ...[
                const SizedBox(height: 16),
                Text(error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  key: const Key('createEvent.publish'),
                  onPressed: publishing ? null : onPublish,
                  child: publishing
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Publicar evento'),
                ),
                TextButton(onPressed: publishing ? null : onEdit, child: const Text('Volver a editar')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
