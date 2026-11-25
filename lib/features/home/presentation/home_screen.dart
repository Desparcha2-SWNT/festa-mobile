import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/account.dart';
import '../../location/presentation/widgets/location_consent_button.dart';
import '../../location/presentation/widgets/location_fallback_banner.dart';
import '../../team/presentation/team_screen.dart';

/// Pantalla de inicio provisional: confirma la sesión y permite cerrarla (SCRUM-51).
/// La reemplazará el mapa de eventos.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(sessionControllerProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Festa'),
        actions: [
          // Activar o desactivar la ubicación (Ley 1581): lo que promete la pantalla de consentimiento.
          const LocationConsentButton(),
          IconButton(
            key: const Key('home.chat'),
            tooltip: 'Hablar con Festi',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => context.push(Routes.chat),
          ),
          IconButton(
            key: const Key('home.plans'),
            tooltip: 'Mis planes',
            icon: const Icon(Icons.event_note_outlined),
            onPressed: () => context.push(Routes.plans),
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
            // SCRUM-61: las cuentas del equipo Festa entran a su revisión manual (comercios por verificar).
            if (account?.role == Role.admin) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                key: const Key('home.team'),
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TeamScreen())),
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Equipo Festa'),
              ),
            ],
          ],
        ),
      ),
    );
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
