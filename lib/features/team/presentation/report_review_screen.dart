import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/design.dart';
import '../../../core/network/api_exception.dart';
import '../../events/application/events_providers.dart';
import '../../events/presentation/event_detail_screen.dart';
import '../../reports/domain/report.dart';
import '../application/team_providers.dart';
import '../data/team_reports_api.dart';
import '../domain/team_report.dart';
import 'report_queue_screen.dart';
import 'submitted_formatters.dart';
import 'team_widgets.dart';

/// SCRUM-110 (RF14): un reporte abierto, con lo reportado (el evento o la cuenta) para revisarlo a mano, y la
/// decisión del equipo: ocultar el evento o suspender la cuenta (SCRUM-111), o descartarlo. Cierra la pantalla
/// con el mensaje que la cola muestra.
class ReportReviewScreen extends ConsumerStatefulWidget {
  const ReportReviewScreen({required this.report, super.key, this.now});

  final TeamReport report;
  final DateTime Function()? now;

  @override
  ConsumerState<ReportReviewScreen> createState() => _ReportReviewScreenState();
}

class _ReportReviewScreenState extends ConsumerState<ReportReviewScreen> {
  bool _sending = false;

  Future<void> _dismiss() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar el reporte?'),
        content: const Text('Se cierra sin cambiar nada en el evento ni en la cuenta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            key: const Key('team.report.dismiss.confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await _send((api) => api.dismiss(widget.report.reportId), 'Reporte descartado.');
  }

  Future<void> _act() async {
    final report = widget.report;
    final decision = await showDialog<_Decision>(
      context: context,
      builder: (_) => _ActionDialog(target: report.target),
    );
    if (decision == null) return;
    switch (report.target) {
      case ReportTarget.event:
        await _send(
          (api) => api.hideEvent(report.reportId, reason: decision.reason),
          'Evento oculto: ya no aparece en el mapa ni en la búsqueda.',
        );
      case ReportTarget.user:
        final duration = decision.duration;
        final until = duration == null ? null : (widget.now ?? DateTime.now)().add(duration);
        await _send(
          (api) => api.suspendUser(report.reportId, reason: decision.reason, until: until),
          duration == null ? 'Cuenta suspendida sin fecha de fin.' : 'Cuenta suspendida por ${duration.inDays} días.',
        );
    }
  }

  Future<void> _send(Future<void> Function(TeamReportsApi api) action, String done) async {
    // Como en la revisión de comercios: lo que se usa después del `await` se toma antes, y mientras se envía
    // el botón atrás queda bloqueado (PopScope) para que la decisión no quede a medias.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final api = ref.read(teamReportsApiProvider);
    setState(() => _sending = true);
    try {
      await action(api);
      container.invalidate(openReportsProvider);
      if (mounted) navigator.pop(done);
    } on ApiException catch (e) {
      final message = e.fieldErrors.values.firstOrNull ?? e.message;
      // Con respuesta del servidor la cola pudo cambiar (otra persona del equipo ya lo cerró). Sin red se deja
      // todo igual para reintentar.
      if (e.statusCode != null) container.invalidate(openReportsProvider);
      if (!mounted) return;
      if (e.statusCode == 404 || e.statusCode == 409) {
        // El reporte ya no está abierto: se vuelve a la cola con el mensaje del servidor.
        navigator.pop(message);
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(message)));
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final report = widget.report;
    final comment = report.comment?.trim();
    final created = report.createdAt;
    final now = (widget.now ?? DateTime.now)();
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        appBar: AppBar(title: const Text('Reporte')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(FestaSpace.xl, FestaSpace.xs, FestaSpace.xl, FestaSpace.xl),
          children: [
            Text(report.reason.label, style: text.headlineMedium),
            const SizedBox(height: FestaSpace.md),
            switch (report.target) {
              ReportTarget.event => _ReportedEvent(eventId: report.targetId),
              ReportTarget.user => _ReportedAccount(accountId: report.targetId),
            },
            if (comment != null && comment.isNotEmpty) TeamField(label: 'Comentario de quien reporta', value: comment),
            if (created != null) TeamField(label: 'Reportado', value: submittedLong(created, now)),
            const SizedBox(height: FestaSpace.xs),
            TeamInfoBox(switch (report.target) {
              ReportTarget.event =>
                'Revisa el evento antes de decidir. Al ocultarlo deja de aparecer en el mapa y la búsqueda; descartar '
                    'cierra el reporte sin cambiar nada.',
              ReportTarget.user =>
                'Revisa la cuenta antes de decidir. Al suspenderla no puede iniciar sesión, se cierran sus sesiones y '
                    'sus eventos dejan de aparecer; descartar cierra el reporte sin cambiar nada.',
            }),
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
                  key: const Key('team.report.act'),
                  onPressed: _sending ? null : _act,
                  child: Text(switch (report.target) {
                    ReportTarget.event => 'Ocultar evento',
                    ReportTarget.user => 'Suspender cuenta',
                  }),
                ),
                const SizedBox(height: FestaSpace.sm),
                OutlinedButton(
                  key: const Key('team.report.dismiss'),
                  onPressed: _sending ? null : _dismiss,
                  child: const Text('Descartar reporte'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El evento reportado: su título y quién lo organiza, con un enlace para abrirlo. Si event-service no lo
/// devuelve (por ejemplo, porque ya está oculto), se dice y se puede decidir igual.
class _ReportedEvent extends ConsumerWidget {
  const _ReportedEvent({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = switch (ref.watch(eventDetailProvider(eventId))) {
      AsyncData(value: final event) => '${event.title} · organiza ${event.organizerName}',
      AsyncError() => 'No pudimos cargar el evento: puede que ya esté oculto o cancelado.',
      _ => 'Cargando el evento…',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TeamField(key: const Key('team.report.subject'), label: ReportTarget.event.label, value: value),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('team.report.openEvent'),
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => EventDetailScreen(eventId: eventId))),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Ver evento'),
          ),
        ),
      ],
    );
  }
}

/// La cuenta reportada: nombre y correo según auth-service, y si ya está suspendida.
class _ReportedAccount extends ConsumerWidget {
  const _ReportedAccount({required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = switch (ref.watch(reportedAccountProvider(accountId))) {
      AsyncData(value: final account) => [
        if (account.displayName.isNotEmpty) account.displayName,
        if (account.email.isNotEmpty) account.email,
        if (account.suspended) 'ya está suspendida',
      ].join(' · '),
      AsyncError() => 'No pudimos cargar la cuenta ($accountId).',
      _ => 'Cargando la cuenta…',
    };
    return TeamField(key: const Key('team.report.subject'), label: ReportTarget.user.label, value: value);
  }
}

/// Lo que decide el equipo al actuar: el motivo (opcional) y, para una cuenta, cuánto dura la suspensión
/// (`null` = sin fecha de fin).
class _Decision {
  const _Decision({this.reason, this.duration});

  final String? reason;
  final Duration? duration;
}

/// SCRUM-111: confirma la acción sobre el reporte. Pide un motivo opcional (queda en el registro de moderación)
/// y, para suspender una cuenta, la duración.
class _ActionDialog extends StatefulWidget {
  const _ActionDialog({required this.target});

  final ReportTarget target;

  @override
  State<_ActionDialog> createState() => _ActionDialogState();
}

class _ActionDialogState extends State<_ActionDialog> {
  static const maxLength = 500;

  /// Duraciones de suspensión que ofrece la pantalla; `null` es sin fecha de fin.
  static const durations = <(String, Duration?)>[
    ('7 días', Duration(days: 7)),
    ('30 días', Duration(days: 30)),
    ('Sin fecha de fin', null),
  ];

  final _reason = TextEditingController();
  Duration? _duration = const Duration(days: 7);

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  // Igual que el rechazo de comercios: user-service cuenta con `@Size(max = 500)` en unidades UTF-16.
  int get _length => _reason.text.trim().length;

  bool get _tooLong => _length > maxLength;

  bool get _event => widget.target == ReportTarget.event;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_event ? '¿Ocultar el evento?' : '¿Suspender la cuenta?'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_event) ...[
            Text('Duración', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: FestaSpace.xs),
            Wrap(
              spacing: FestaSpace.xs,
              runSpacing: FestaSpace.xs,
              children: [
                for (final (label, duration) in durations)
                  ChoiceChip(
                    key: Key('team.report.duration.${duration?.inDays ?? 'none'}'),
                    label: Text(label),
                    selected: _duration == duration,
                    onSelected: (_) => setState(() => _duration = duration),
                  ),
              ],
            ),
            const SizedBox(height: FestaSpace.md),
          ],
          TextField(
            key: const Key('team.report.reason'),
            controller: _reason,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Motivo (opcional)',
              hintText: 'Queda en el registro de moderación.',
              counterText: '$_length/$maxLength',
              errorText: _tooLong ? 'El motivo pasa de $maxLength caracteres (los emojis cuentan doble).' : null,
              errorMaxLines: 2,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(
        key: const Key('team.report.act.confirm'),
        onPressed: _tooLong
            ? null
            : () => Navigator.pop(context, _Decision(reason: _reason.text.trim(), duration: _event ? null : _duration)),
        child: Text(_event ? 'Ocultar' : 'Suspender'),
      ),
    ],
  );
}
