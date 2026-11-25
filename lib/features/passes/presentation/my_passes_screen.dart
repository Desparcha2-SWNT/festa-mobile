import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/design/design.dart';
import '../../../core/network/api_exception.dart';
import '../../plans/presentation/plan_formatters.dart';
import '../application/passes_providers.dart';
import '../domain/pass.dart';

/// SCRUM-90: «Mis entradas». Cada asistencia gratis o boleta con su QR para mostrar en la entrada.
class MyPassesScreen extends ConsumerWidget {
  const MyPassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Mis entradas')),
    body: switch (ref.watch(myPassesProvider)) {
      AsyncData(:final value) => RefreshIndicator(
        onRefresh: () => ref.refresh(myPassesProvider.future),
        child: value.isEmpty
            ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [_EmptyView()])
            : ListView.separated(
                key: const Key('passes.list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: FestaSpace.sm),
                itemCount: value.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _PassTile(pass: value[i]),
              ),
      ),
      AsyncError(:final error) => _ErrorView(
        message: error is ApiException ? error.message : 'Intenta de nuevo.',
        onRetry: () => ref.invalidate(myPassesProvider),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    },
  );
}

class _PassTile extends StatelessWidget {
  const _PassTile({required this.pass});

  final Pass pass;

  @override
  Widget build(BuildContext context) {
    final starts = pass.eventStartsAt;
    final kind = pass.ticket ? 'Boleta' : 'Asistencia gratis';
    final (label, color) = switch (pass) {
      _ when pass.status == PassStatus.used => ('Usada', FestaColors.textSecondary),
      _ when pass.status == PassStatus.revoked => ('Cancelada', FestaColors.textError),
      _ when pass.eventEnded => ('Evento terminado', FestaColors.textSecondary),
      _ => ('Ver QR', FestaColors.textBrand),
    };
    return ListTile(
      key: Key('passes.item.${pass.passId}'),
      leading: Icon(Icons.qr_code_2, color: pass.usable ? FestaColors.textBrand : FestaColors.textDisabled),
      title: Text(pass.eventTitle),
      subtitle: Text(starts == null ? kind : '$kind · ${formatPlanDate(starts)}'),
      trailing: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      enabled: pass.opens,
      onTap: pass.opens
          ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PassQrScreen(pass: pass)))
          : null,
    );
  }
}

/// «Mi boleto» (Figma 10 y 10b): el QR de una entrada, grande y sobre fondo blanco para que el escáner
/// lo lea con cualquier tema, con su estado arriba. Una entrada usada se abre sin QR (booking no lo manda)
/// y lo dice.
class PassQrScreen extends StatelessWidget {
  const PassQrScreen({required this.pass, super.key});

  final Pass pass;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final starts = pass.eventStartsAt;
    final used = pass.status == PassStatus.used;
    final qr = pass.qr;
    return Scaffold(
      appBar: AppBar(title: Text(pass.ticket ? 'Mi boleto' : 'Mi entrada')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth - 2 * FestaSpace.xl, 320.0);
          return ListView(
            padding: const EdgeInsets.all(FestaSpace.xl),
            children: [
              Center(child: _StatusChip(used: used)),
              const SizedBox(height: FestaSpace.md),
              Text(pass.eventTitle, style: text.titleLarge, textAlign: TextAlign.center),
              if (starts != null) ...[
                const SizedBox(height: FestaSpace.xxs),
                Text(
                  formatPassSchedule(starts, pass.eventEndsAt),
                  key: const Key('passes.schedule'),
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
              ],
              const SizedBox(height: FestaSpace.xl),
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: used ? FestaColors.bgMuted : FestaColors.bg,
                    borderRadius: FestaRadius.mdAll,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(FestaSpace.md),
                    child: qr == null
                        ? SizedBox.square(
                            key: const Key('passes.qr.used'),
                            dimension: size,
                            child: const Icon(Icons.qr_code_2, size: 120, color: FestaColors.textDisabled),
                          )
                        : QrImageView(
                            key: const Key('passes.qr'),
                            data: qr,
                            size: size,
                            backgroundColor: FestaColors.bg,
                            semanticsLabel: 'Código QR de tu entrada',
                          ),
                  ),
                ),
              ),
              const SizedBox(height: FestaSpace.xl),
              Text(
                used
                    ? 'Este boleto ya se escaneó. Un código solo sirve una vez.'
                    : 'Un solo uso: una vez escaneado, el código queda invalidado. Sube el brillo al entrar.',
                key: const Key('passes.hint'),
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: FestaColors.textSecondary),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Chip de estado del Figma: «Válido · 1 persona» o «Ya usado».
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.used});

  final bool used;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('passes.status'),
    padding: const EdgeInsets.symmetric(horizontal: FestaSpace.sm, vertical: FestaSpace.xxs),
    decoration: BoxDecoration(color: used ? FestaColors.bgMuted : FestaColors.bgFree, borderRadius: FestaRadius.smAll),
    child: Text(
      used ? 'Ya usado' : 'Válido · 1 persona',
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: used ? FestaColors.textSecondary : FestaColors.textSuccess),
    ),
  );
}

/// «Mi entrada» desde «Mis planes» (Figma 21, botón «Ver mi QR»): busca la entrada del plan entre las del
/// usuario y la muestra.
class PassForEventScreen extends ConsumerWidget {
  const PassForEventScreen({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passes = ref.watch(myPassesProvider);
    if (passes case AsyncData(:final value)) {
      final pass = passForEvent(value, eventId);
      if (pass != null) return PassQrScreen(pass: pass);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mi entrada')),
      body: switch (passes) {
        AsyncData() => const _Message(
          key: Key('passes.forEvent.missing'),
          title: 'No encontramos el QR de este plan',
          body: 'Si acabas de confirmar, espera un momento y vuelve a intentarlo.',
        ),
        AsyncError(:final error) => _ErrorView(
          message: error is ApiException ? error.message : 'Intenta de nuevo.',
          onRetry: () => ref.invalidate(myPassesProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// La entrada de un evento: primero una que se pueda mostrar; si no, una ya usada.
Pass? passForEvent(List<Pass> passes, String eventId) {
  final ofEvent = [
    for (final pass in passes)
      if (pass.eventId == eventId) pass,
  ];
  for (final pass in ofEvent) {
    if (pass.usable) return pass;
  }
  for (final pass in ofEvent) {
    if (pass.status == PassStatus.used) return pass;
  }
  return null;
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(FestaSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: FestaSpace.xs),
          Text(body, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

/// «jue 14 nov · 3:05 p. m. a 6:05 p. m.»; si termina otro día, con la fecha completa de fin.
String formatPassSchedule(DateTime starts, DateTime? ends) {
  final from = formatPlanDate(starts);
  if (ends == null) return from;
  final s = starts.toLocal();
  final e = ends.toLocal();
  final sameDay = s.year == e.year && s.month == e.month && s.day == e.day;
  return sameDay ? '$from a ${formatPlanTime(e)}' : '$from a ${formatPlanDate(e)}';
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(FestaSpace.xxl),
    child: Column(
      children: [
        const Icon(Icons.qr_code_2, size: FestaSpace.xxxl * 1.4, color: FestaColors.textSecondary),
        const SizedBox(height: FestaSpace.md),
        Text(
          'Todavía no tienes entradas',
          key: const Key('passes.empty'),
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FestaSpace.xs),
        const Text(
          'Cuando confirmes tu asistencia o compres una boleta, tu QR aparecerá aquí.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(FestaSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('No pudimos cargar tus entradas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: FestaSpace.xs),
          Text(message, key: const Key('passes.error'), textAlign: TextAlign.center),
          const SizedBox(height: FestaSpace.xl),
          OutlinedButton(key: const Key('passes.retry'), onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}
