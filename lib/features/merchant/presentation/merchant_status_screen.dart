import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../application/merchant_controller.dart';
import '../domain/merchant_profile.dart';

/// SCRUM-59: estado de la verificación mientras el comercio no está aprobado. Diseño: Figma
/// «23 · Verificación · Pendiente» y «23c · Verificación · Rechazada». Cuando el equipo Festa lo
/// aprueba, el router deja entrar a la app.
class MerchantStatusScreen extends ConsumerWidget {
  const MerchantStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchant = ref.watch(merchantControllerProvider);
    final controller = ref.read(merchantControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.reload,
          child: switch (merchant) {
            AsyncData(value: MerchantProfile(status: MerchantStatus.rejected, :final rejectionReason)) => _Rejected(
              reason: rejectionReason,
            ),
            AsyncData() => const _Pending(),
            AsyncError(:final error) when !merchant.isLoading => _LoadError(
              message: error is ApiException ? error.message : 'No pudimos consultar tu comercio.',
              onRetry: controller.reload,
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

class _Pending extends StatelessWidget {
  const _Pending();

  @override
  Widget build(BuildContext context) => _StatusLayout(
    icon: Icons.schedule,
    iconColor: const Color(0xFF111111),
    iconBackground: const Color(0xFFFFD23F),
    title: 'Estamos revisando tu perfil',
    body: [
      const _Message(
        'El equipo de Festa verifica cada comercio a mano. Te avisaremos por notificación y correo. '
        'Desliza hacia abajo para consultar de nuevo.',
      ),
      const SizedBox(height: 24),
      const _Milestone('Perfil enviado', done: true),
      const _Milestone('En revisión', current: true),
      const _Milestone('Verificado: ya puedes publicar eventos'),
    ],
    action: OutlinedButton(
      key: const Key('merchantStatus.edit'),
      onPressed: () => context.push(Routes.merchantForm),
      child: const Text('Editar mi perfil'),
    ),
  );
}

class _Rejected extends StatelessWidget {
  const _Rejected({required this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _StatusLayout(
      icon: Icons.close,
      iconColor: colors.error,
      iconBackground: colors.errorContainer,
      title: 'No pudimos verificar tu perfil',
      body: [
        if (reason != null)
          DecoratedBox(
            decoration: BoxDecoration(color: colors.errorContainer, borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Motivo',
                    style: TextStyle(color: colors.error, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(reason!, style: TextStyle(color: colors.onErrorContainer)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        const _Message('Corrige tu perfil y vuelve a enviarlo para una nueva revisión.'),
      ],
      action: FilledButton(
        key: const Key('merchantStatus.fix'),
        onPressed: () => context.push(Routes.merchantForm),
        child: const Text('Corregir y reenviar'),
      ),
    );
  }
}

/// Ícono, título y contenido arriba (desplazable para poder refrescar); el botón siempre abajo.
class _StatusLayout extends StatelessWidget {
  const _StatusLayout({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.body,
    required this.action,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final List<Widget> body;
  final Widget action;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: iconBackground,
                child: Icon(icon, size: 36, color: iconColor),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              key: const Key('merchant.status.title'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ...body,
          ],
        ),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 16), child: action),
    ],
  );
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

class _Milestone extends StatelessWidget {
  const _Milestone(this.label, {this.done = false, this.current = false});

  final String label;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, color) = done
        ? (Icons.check_circle, colors.primary)
        : current
        ? (Icons.circle, const Color(0xFFFFD23F))
        : (Icons.circle, colors.surfaceContainerHighest);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(color: done || current ? colors.onSurface : colors.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 120),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      Center(
        child: FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
      ),
    ],
  );
}
