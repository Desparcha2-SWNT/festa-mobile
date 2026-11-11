import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/user_location_provider.dart';
import '../../domain/user_location.dart';

/// Avisa que se está usando la ubicación del piloto y por qué. No ocupa espacio cuando la app
/// tiene la ubicación real del dispositivo.
class LocationFallbackBanner extends ConsumerWidget {
  const LocationFallbackBanner({super.key});

  static String message(LocationFallbackReason reason) => switch (reason) {
    LocationFallbackReason.consentDeclined ||
    LocationFallbackReason.permissionDenied => 'Ubicación desactivada · mostrando cerca de la Escuela',
    LocationFallbackReason.serviceDisabled => 'GPS apagado · mostrando cerca de la Escuela',
    LocationFallbackReason.unavailable => 'No encontramos tu ubicación · mostrando cerca de la Escuela',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reason = ref.watch(userLocationProvider).value?.fallbackReason;
    if (reason == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            message(reason),
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
      ),
    );
  }
}
