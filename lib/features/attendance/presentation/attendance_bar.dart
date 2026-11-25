import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/design.dart';
import '../../../core/network/api_exception.dart';
import '../../events/domain/event.dart';
import '../application/attendance_providers.dart';

/// SCRUM-70: «Confirmo que voy» en el detalle de un evento gratis, con los cupos ocupados.
/// Los eventos con boleta se compran aparte (SCRUM-26), y uno cancelado o terminado ya no admite cambios.
class AttendanceBar extends ConsumerStatefulWidget {
  const AttendanceBar({required this.event, super.key});

  final Event event;

  /// Solo un evento gratis, publicado y que no ha terminado acepta confirmaciones (regla de booking).
  static bool appliesTo(Event event) =>
      !event.ticketed && event.status == EventStatus.published && event.endsAt.isAfter(DateTime.now());

  @override
  ConsumerState<AttendanceBar> createState() => _AttendanceBarState();
}

class _AttendanceBarState extends ConsumerState<AttendanceBar> {
  bool _sending = false;

  Future<void> _run(Future<void> Function(AttendanceController c) action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await action(ref.read(attendanceControllerProvider(widget.event.id).notifier));
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar tu asistencia?'),
        content: const Text('Liberas tu cupo para que otra persona pueda ir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Seguir yendo')),
          FilledButton(
            key: const Key('attendance.cancel.confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar asistencia'),
          ),
        ],
      ),
    );
    if (ok ?? false) await _run((c) => c.cancel(), 'Cancelaste tu asistencia.');
  }

  @override
  Widget build(BuildContext context) {
    final provider = attendanceControllerProvider(widget.event.id);
    final text = Theme.of(context).textTheme;
    // Celebra solo el paso de "no voy" a "voy" que hace la persona, no la carga inicial.
    ref.listen(provider, (previous, next) {
      if (previous?.value?.confirmed == false && next.value?.confirmed == true) {
        FestaCelebration.show(context, title: '¡Vas a este plan!', message: 'Te esperamos en ${widget.event.title}');
      }
    });
    return switch (ref.watch(provider)) {
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          FestaAnimatedCount(
            value: value.attendeeCount,
            builder: (context, shown) => Text(
              value.capacity == null
                  ? '$shown ${shown == 1 ? 'persona va' : 'personas van'}'
                  : '$shown de ${value.capacity} cupos ocupados',
              key: const Key('attendance.count'),
              style: text.bodySmall?.copyWith(color: FestaColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: FestaSpace.xs),
          AnimatedSwitcher(
            duration: FestaMotion.of(context, FestaMotion.base),
            switchInCurve: FestaMotion.emphasized,
            switchOutCurve: FestaMotion.exit,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(animation), child: child),
            ),
            child: value.confirmed
                ? Column(
                    key: const ValueKey('attendance.state.going'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: FestaColors.textSuccess, size: 20),
                          const SizedBox(width: FestaSpace.xs),
                          Text('Vas a este plan', key: const Key('attendance.going'), style: text.titleSmall),
                        ],
                      ),
                      const SizedBox(height: FestaSpace.xs),
                      OutlinedButton(
                        key: const Key('attendance.cancel'),
                        onPressed: _sending ? null : _confirmCancel,
                        child: const Text('Cancelar asistencia'),
                      ),
                    ],
                  )
                : FilledButton(
                    key: const Key('attendance.confirm'),
                    onPressed: _sending || value.full
                        ? null
                        : () => _run((c) => c.confirm(), '¡Listo! Quedó en tus planes.'),
                    child: Text(value.full ? 'Sin cupos' : 'Confirmo que voy'),
                  ),
          ),
        ],
      ),
      AsyncError(:final error) => TextButton.icon(
        key: const Key('attendance.retry'),
        onPressed: () => ref.invalidate(provider),
        icon: const Icon(Icons.refresh),
        label: Text(
          error is ApiException ? '${error.message} Reintentar' : 'No pudimos cargar tu asistencia. Reintentar',
        ),
      ),
      _ => const FilledButton(onPressed: null, child: Text('Confirmo que voy')),
    };
  }
}
