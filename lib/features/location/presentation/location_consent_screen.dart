import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/location_consent_controller.dart';

/// SCRUM-127: pide el consentimiento explícito antes de tocar la ubicación del dispositivo
/// (RNF5, Ley 1581). Diseño: Figma «15 · Permiso de ubicación».
///
/// Se muestra una sola vez por cuenta. Al decidir, el router lleva al inicio; el diálogo de
/// permiso del sistema aparece después, solo si el usuario eligió permitir.
class LocationConsentScreen extends ConsumerStatefulWidget {
  const LocationConsentScreen({super.key});

  @override
  ConsumerState<LocationConsentScreen> createState() => _LocationConsentScreenState();
}

class _LocationConsentScreenState extends ConsumerState<LocationConsentScreen> {
  bool _submitting = false;

  Future<void> _decide(Future<void> Function(LocationConsentController controller) decision) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await decision(ref.read(locationConsentControllerProvider.notifier));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // La explicación queda centrada en el espacio libre y se desplaza en pantallas bajas;
                  // los botones siempre quedan visibles abajo, como en el diseño.
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _LocationIcon(),
                            const SizedBox(height: 24),
                            Text(
                              'Encuentra planes cerca de ti',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Usamos tu ubicación solo mientras usas la app, para mostrarte eventos cercanos. '
                              'Puedes cambiarlo cuando quieras.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.merge(secondaryText),
                            ),
                            const SizedBox(height: 24),
                            const _Promise('Solo con tu permiso'),
                            const SizedBox(height: 8),
                            const _Promise('No la compartimos con otros usuarios'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('locationConsent.allow'),
                    onPressed: _submitting ? null : () => _decide((controller) => controller.grant()),
                    child: const Text('Permitir ubicación'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('locationConsent.decline'),
                    onPressed: _submitting ? null : () => _decide((controller) => controller.decline()),
                    child: const Text('Ahora no'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sin ubicación te mostramos eventos cerca de la Escuela.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.merge(secondaryText),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationIcon extends StatelessWidget {
  const _LocationIcon();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.primaryContainer, shape: BoxShape.circle),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Icon(Icons.location_on_outlined, size: 40, color: colors.primary),
        ),
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.check, size: 20, color: theme.colorScheme.tertiary),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
