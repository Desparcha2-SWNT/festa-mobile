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
      enabled: pass.usable || pass.status == PassStatus.used,
      onTap: pass.usable || pass.status == PassStatus.used
          ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PassQrScreen(pass: pass)))
          : null,
    );
  }
}

/// El QR de una entrada, grande y sobre fondo blanco para que el escáner lo lea con cualquier tema.
/// Un pase usado no lleva QR (booking no lo manda): se muestra el aviso en su lugar.
class PassQrScreen extends StatelessWidget {
  const PassQrScreen({required this.pass, super.key});

  final Pass pass;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final starts = pass.eventStartsAt;
    final ends = pass.eventEndsAt;
    final qr = pass.qr;
    return Scaffold(
      appBar: AppBar(title: const Text('Tu entrada')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth - 2 * FestaSpace.xl, 320.0);
          return ListView(
            padding: const EdgeInsets.all(FestaSpace.xl),
            children: [
              Text(pass.eventTitle, style: text.titleLarge, textAlign: TextAlign.center),
              if (starts != null) ...[
                const SizedBox(height: FestaSpace.xxs),
                Text(
                  ends == null ? formatPlanDate(starts) : '${formatPlanDate(starts)} – ${formatPlanTime(ends)}',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
              ],
              const SizedBox(height: FestaSpace.xl),
              if (qr != null) ...[
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: FestaColors.bg, borderRadius: FestaRadius.mdAll),
                    child: Padding(
                      padding: const EdgeInsets.all(FestaSpace.md),
                      child: QrImageView(
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
                  'Muéstralo en la entrada. Sirve una sola vez.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: FestaColors.textSecondary),
                ),
              ] else
                Text(
                  'Este boleto ya se escaneó. Un código solo sirve una vez.',
                  key: const Key('passes.used'),
                  textAlign: TextAlign.center,
                  style: text.bodyLarge,
                ),
            ],
          );
        },
      ),
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
