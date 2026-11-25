import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/design.dart';
import '../../../core/network/api_exception.dart';
import '../../reports/domain/report.dart';
import '../application/team_providers.dart';
import '../domain/team_report.dart';
import 'report_review_screen.dart';
import 'submitted_formatters.dart';
import 'team_widgets.dart';

/// SCRUM-110 (RF14): la cola de reportes abiertos que el equipo Festa revisa a mano. Sigue el patrón de la
/// revisión de comercios (Figma 28); el Figma no tiene una pantalla propia para los reportes.
class ReportQueueScreen extends ConsumerWidget {
  const ReportQueueScreen({super.key, this.now});

  /// Hora de referencia para «hace 2 h»; en las pruebas se fija.
  final DateTime Function()? now;

  Future<void> _open(BuildContext context, TeamReport report) async {
    final messenger = ScaffoldMessenger.of(context);
    final decision = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ReportReviewScreen(report: report, now: now),
      ),
    );
    if (decision != null) messenger.showSnackBar(SnackBar(content: Text(decision)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(openReportsProvider);
    final count = reports.value?.length;
    return Scaffold(
      appBar: AppBar(title: Text(count == null ? 'Reportes' : 'Reportes ($count)')),
      body: switch (reports) {
        AsyncData(:final value) => RefreshIndicator(
          // El error ya se muestra con el estado `AsyncError`: el future del refresco no debe quedar sin manejar.
          onRefresh: () => ref.refresh(openReportsProvider.future).then((_) {}, onError: (Object _) {}),
          child: value.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    TeamMessage(
                      key: Key('team.reports.empty'),
                      title: 'No hay reportes por revisar',
                      body: 'Cuando alguien reporte un evento o una cuenta, aparecerá aquí.',
                    ),
                  ],
                )
              : ListView.separated(
                  key: const Key('team.reports.list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(FestaSpace.md),
                  itemCount: value.length,
                  separatorBuilder: (_, _) => const SizedBox(height: FestaSpace.sm),
                  itemBuilder: (context, i) => _ReportCard(
                    report: value[i],
                    now: (now ?? DateTime.now)(),
                    onTap: () => _open(context, value[i]),
                  ),
                ),
        ),
        AsyncError(:final error) => Center(
          child: TeamMessage(
            key: const Key('team.reports.error'),
            title: 'No pudimos cargar los reportes',
            body: error is ApiException ? error.message : 'Intenta de nuevo.',
            action: OutlinedButton(
              key: const Key('team.reports.retry'),
              onPressed: () => ref.invalidate(openReportsProvider),
              child: const Text('Reintentar'),
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// «Evento reportado · Información falsa», el comentario (si hay) y cuándo llegó.
class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.now, required this.onTap});

  final TeamReport report;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final comment = report.comment?.trim();
    final created = report.createdAt;
    return Card(
      key: Key('team.report.${report.reportId}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(FestaSpace.md),
          child: Row(
            children: [
              Icon(report.target.icon, color: FestaColors.textSecondary),
              const SizedBox(width: FestaSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${report.target.label} · ${report.reason.label}', style: text.titleMedium),
                    if (comment != null && comment.isNotEmpty) ...[
                      const SizedBox(height: FestaSpace.xxs),
                      Text('«$comment»', maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                    ],
                    if (created != null) ...[
                      const SizedBox(height: FestaSpace.xxs),
                      Text(
                        'Reportado ${submittedShort(created, now)}',
                        style: text.bodySmall?.copyWith(color: FestaColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: FestaSpace.xs),
              const Icon(Icons.chevron_right, color: FestaColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cómo se nombra cada tipo de reporte en las pantallas del equipo.
extension ReportTargetLabel on ReportTarget {
  String get label => switch (this) {
    ReportTarget.event => 'Evento reportado',
    ReportTarget.user => 'Cuenta reportada',
  };

  IconData get icon => switch (this) {
    ReportTarget.event => Icons.event_outlined,
    ReportTarget.user => Icons.person_outline,
  };
}
