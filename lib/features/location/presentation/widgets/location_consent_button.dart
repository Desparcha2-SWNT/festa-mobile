import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/location_consent_controller.dart';
import '../../domain/location_consent.dart';

/// Activa o desactiva la ubicación desde cualquier cuenta (Ley 1581: el titular puede cambiar su
/// decisión cuando quiera). Lo usan usuarios y comercios.
class LocationConsentButton extends ConsumerWidget {
  const LocationConsentButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granted = ref.watch(locationConsentControllerProvider).value == LocationConsent.granted;
    if (granted) {
      return IconButton(
        key: const Key('home.location.revoke'),
        tooltip: 'Desactivar ubicación',
        icon: const Icon(Icons.location_off_outlined),
        onPressed: () => _confirmRevoke(context, ref),
      );
    }
    return IconButton(
      key: const Key('home.location.grant'),
      tooltip: 'Activar ubicación',
      icon: const Icon(Icons.my_location),
      onPressed: () => ref.read(locationConsentControllerProvider.notifier).grant(),
    );
  }

  Future<void> _confirmRevoke(BuildContext context, WidgetRef ref) async {
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
}
