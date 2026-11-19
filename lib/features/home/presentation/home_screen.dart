import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../auth/application/session_controller.dart';
import '../../location/application/location_consent_controller.dart';
import '../../location/domain/location_consent.dart';
import '../../location/presentation/widgets/location_fallback_banner.dart';

/// Pantalla de inicio provisional: confirma la sesión y permite cerrarla (SCRUM-51).
/// La reemplazará el mapa de eventos.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(sessionControllerProvider).value;
    final locationGranted = ref.watch(locationConsentControllerProvider).value == LocationConsent.granted;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Festa'),
        actions: [
          // Revocar el consentimiento de ubicación (Ley 1581): lo que promete la pantalla de consentimiento.
          if (locationGranted)
            IconButton(
              key: const Key('home.location.revoke'),
              tooltip: 'Desactivar ubicación',
              icon: const Icon(Icons.location_off_outlined),
              onPressed: () => _confirmRevokeLocation(context, ref),
            ),
          IconButton(
            key: const Key('home.profile'),
            tooltip: 'Mi perfil',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(Routes.profile),
          ),
          IconButton(
            key: const Key('home.logout'),
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              account == null ? '' : 'Hola, ${account.displayName}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const LocationFallbackBanner(),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRevokeLocation(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Desactivar la ubicación?'),
        content: const Text(
          'Festa dejará de usar tu ubicación y mostrará eventos sin distancia. Puedes volver a activarla cuando quieras.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Desactivar')),
        ],
      ),
    );
    if (confirmed ?? false) await ref.read(locationConsentControllerProvider.notifier).decline();
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que volver a iniciar sesión para usar Festa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (confirmed ?? false) await ref.read(sessionControllerProvider.notifier).logout();
  }
}
