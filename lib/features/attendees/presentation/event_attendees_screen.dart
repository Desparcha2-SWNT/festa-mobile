import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/design.dart';
import '../../../core/network/api_exception.dart';
import '../application/attendees_providers.dart';
import '../domain/attendee.dart';
import 'attendee_formatters.dart';

/// Asistentes del evento (SCRUM-141, pantalla 26 del Figma): la lista que ve el organizador, con
/// cuántas boletas tiene cada persona y si ya entró.
class EventAttendeesScreen extends ConsumerWidget {
  const EventAttendeesScreen({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = attendeesControllerProvider(eventId);
    final attendees = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(title: const Text('Asistentes')),
      body: switch (attendees) {
        AsyncData(:final value) => RefreshIndicator(
          // El error del refresh ya queda en el estado del provider y se muestra con «Reintentar»;
          // aquí solo se evita que el RefreshIndicator lo deje sin capturar.
          onRefresh: () => ref.refresh(provider.future).then((_) {}, onError: (Object _) {}),
          child: _AttendeeList(state: value, onLoadMore: () => _loadMore(context, ref)),
        ),
        AsyncError(:final error) => _ErrorView(error: error, onRetry: () => ref.invalidate(provider)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _loadMore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(attendeesControllerProvider(eventId).notifier).loadMore();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      // Una página que no se puede leer (p. ej. un JSON inesperado) no es una ApiException: sin este
      // caso el error escapaba sin que la persona viera nada. La lista ya cargada se conserva.
      messenger.showSnackBar(const SnackBar(content: Text('No pudimos cargar más asistentes. Intenta de nuevo.')));
    }
  }
}

class _AttendeeList extends StatelessWidget {
  const _AttendeeList({required this.state, required this.onLoadMore});

  final AttendeesState state;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    final summary = _Summary(state: state);
    if (state.items.isEmpty) {
      return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [summary, const _EmptyView()]);
    }
    return ListView.separated(
      key: const Key('attendees.list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: FestaSpace.xl),
      itemCount: state.items.length + (state.hasMore ? 2 : 1),
      separatorBuilder: (_, index) => index == 0 ? const SizedBox.shrink() : const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == 0) return summary;
        final i = index - 1;
        if (i < state.items.length) return _AttendeeTile(attendee: state.items[i]);
        return Padding(
          padding: const EdgeInsets.all(FestaSpace.md),
          child: _LoadMoreButton(remaining: state.total - state.items.length, onLoadMore: onLoadMore),
        );
      },
    );
  }
}

/// «Ver más» con feedback: mientras la página pedida está en camino muestra un indicador y no se puede
/// volver a pulsar.
class _LoadMoreButton extends StatefulWidget {
  const _LoadMoreButton({required this.remaining, required this.onLoadMore});

  final int remaining;
  final Future<void> Function() onLoadMore;

  @override
  State<_LoadMoreButton> createState() => _LoadMoreButtonState();
}

class _LoadMoreButtonState extends State<_LoadMoreButton> {
  bool _loading = false;

  Future<void> _press() async {
    setState(() => _loading = true);
    try {
      await widget.onLoadMore();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: const Key('attendees.loadMore'),
      onPressed: _loading ? null : _press,
      child: _loading
          ? const SizedBox(
              key: Key('attendees.loadingMore'),
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text('Ver más (${widget.remaining})'),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.state});

  final AttendeesState state;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final count = state.attendeeCount;
    final capacity = state.capacity;
    return Padding(
      padding: const EdgeInsets.fromLTRB(FestaSpace.md, FestaSpace.md, FestaSpace.md, FestaSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            capacity == null ? '$count ${count == 1 ? 'asistente' : 'asistentes'}' : '$count de $capacity cupos',
            key: const Key('attendees.count'),
            style: text.titleLarge,
          ),
          if (capacity != null) ...[
            const SizedBox(height: FestaSpace.xs),
            ClipRRect(
              borderRadius: FestaRadius.smAll,
              child: LinearProgressIndicator(
                value: capacity == 0 ? 0 : (count / capacity).clamp(0, 1).toDouble(),
                minHeight: FestaSpace.xs,
                backgroundColor: FestaColors.bgMuted,
                color: FestaColors.bgBrand,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttendeeTile extends StatelessWidget {
  const _AttendeeTile({required this.attendee});

  final Attendee attendee;

  @override
  Widget build(BuildContext context) {
    final name = attendee.displayName?.trim();
    final hasName = name != null && name.isNotEmpty;
    final kind = attendee.source == AttendanceSource.ticket
        ? (attendee.tickets == 1 ? '1 boleta' : '${attendee.tickets} boletas')
        : 'Asistencia gratis';
    return ListTile(
      key: Key('attendees.item.${attendee.attendanceId}'),
      leading: CircleAvatar(
        backgroundColor: FestaColors.bgBrandSoft,
        foregroundColor: FestaColors.textBrand,
        child: hasName ? Text(_initials(name)) : const Icon(Icons.person_outline),
      ),
      title: Text(
        hasName ? name : 'Asistente sin nombre',
        style: hasName ? null : const TextStyle(color: FestaColors.textSecondary),
      ),
      subtitle: Text('$kind · ${formatConfirmedAt(attendee.confirmedAt)}'),
      trailing: _CheckInBadge(attendee: attendee),
    );
  }

  static String _initials(String name) {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
    return parts.map((p) => p.characters.first.toUpperCase()).join();
  }
}

class _CheckInBadge extends StatelessWidget {
  const _CheckInBadge({required this.attendee});

  final Attendee attendee;

  @override
  Widget build(BuildContext context) {
    if (attendee.checkedIn == 0) return const SizedBox.shrink();
    final label = attendee.fullyCheckedIn ? 'Ingresó' : '${attendee.checkedIn}/${attendee.tickets} ingresaron';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: FestaSpace.xs, vertical: FestaSpace.xxs),
      decoration: BoxDecoration(color: FestaColors.bgFree, borderRadius: FestaRadius.smAll),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: FestaColors.textSuccess)),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(FestaSpace.xxl),
    child: Column(
      children: [
        const Icon(Icons.groups_outlined, size: FestaSpace.xxxl * 1.4, color: FestaColors.textSecondary),
        const SizedBox(height: FestaSpace.md),
        Text(
          'Todavía no hay asistentes',
          key: const Key('attendees.empty'),
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FestaSpace.xs),
        const Text(
          'Cuando alguien confirme su asistencia o compre una boleta, aparecerá aquí.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final status = error is ApiException ? (error as ApiException).statusCode : null;
    // 403 y 404 no se arreglan reintentando.
    final (title, body, canRetry) = switch (status) {
      403 => ('No puedes ver esta lista', 'Solo el organizador del evento puede ver sus asistentes.', false),
      404 => ('No encontramos el evento', 'Puede que se haya eliminado.', false),
      _ => (
        'No pudimos cargar los asistentes',
        error is ApiException ? (error as ApiException).message : 'Intenta de nuevo.',
        true,
      ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FestaSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              canRetry ? Icons.cloud_off : Icons.lock_outline,
              size: FestaSpace.xxxl * 1.4,
              color: FestaColors.textSecondary,
            ),
            const SizedBox(height: FestaSpace.md),
            Text(
              title,
              key: const Key('attendees.error'),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FestaSpace.xs),
            Text(body, textAlign: TextAlign.center),
            if (canRetry) ...[
              const SizedBox(height: FestaSpace.xl),
              OutlinedButton(key: const Key('attendees.retry'), onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}
