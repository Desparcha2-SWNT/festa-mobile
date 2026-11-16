import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_controller.dart';
import '../application/merchant_providers.dart';

/// Verificación del comercio (RF3): el equipo de Festa revisa a mano cada solicitud.
class MerchantPendingScreen extends ConsumerWidget {
  const MerchantPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(merchantStatusProvider);
    final (icon, title, body) = status.when(
      loading: () => (Icons.hourglass_top, 'Estamos revisando tu perfil', 'Consultando el estado de tu comercio…'),
      error: (_, _) => (Icons.cloud_off, 'No pudimos consultar el estado', 'Revisa tu conexión e inténtalo de nuevo.'),
      data: (s) => s.approved
          ? (Icons.verified, 'Tu comercio está verificado', 'Ya puedes publicar eventos en Festa.')
          : s.rejected
          ? (
              Icons.error_outline,
              'Tu solicitud fue rechazada',
              s.rejectionReason ?? 'Corrige los datos y vuelve a enviarla.',
            )
          : (
              Icons.hourglass_top,
              'Estamos revisando tu perfil',
              'El equipo de Festa revisa tu comercio a mano. Te avisamos el resultado.',
            ),
    );
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                key: const Key('merchant.status.title'),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              OutlinedButton(
                key: const Key('merchant.status.refresh'),
                onPressed: () => ref.invalidate(merchantStatusProvider),
                child: const Text('Actualizar estado'),
              ),
              TextButton(
                key: const Key('merchant.status.logout'),
                onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
