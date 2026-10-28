import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_controller.dart';

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
          IconButton(
            key: const Key('home.logout'),
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: Center(
        child: Text(
          account == null ? '' : 'Hola, ${account.displayName}',
          style: Theme.of(context).textTheme.headlineSmall,
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
