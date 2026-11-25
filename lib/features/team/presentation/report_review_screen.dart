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
/// decisión del equipo. Cierra la pantalla con el mensaje que la cola muestra.
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
            const TeamInfoBox('Revisa lo reportado antes de decidir. Descartar cierra el reporte sin cambiar nada.'),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(FestaSpace.xl, FestaSpace.xs, FestaSpace.xl, FestaSpace.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
