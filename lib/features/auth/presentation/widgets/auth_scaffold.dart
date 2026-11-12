import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Estructura común de las pantallas de acceso (login, registro).
/// Muestra la corona de Festa, título grande, subtítulo y el formulario centrado.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.child, this.errorMessage});

  final String title;
  final String subtitle;
  final String? errorMessage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Corona de Festa
                  const _FestaCrown(),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: FestaTheme.ink,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(subtitle, style: theme.textTheme.bodyLarge?.copyWith(color: const Color(0xFF555555))),
                  const SizedBox(height: 28),
                  if (errorMessage != null) ...[_ErrorBanner(message: errorMessage!), const SizedBox(height: 16)],
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Corona rosa de Festa (como en el Figma; el logo completo va solo en el splash).
///
/// Va dentro de un [Align] porque en una columna con `stretch` la imagen recibiría el ancho completo
/// y se vería gigante, ignorando su tamaño.
class _FestaCrown extends StatelessWidget {
  const _FestaCrown();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Image(image: AssetImage('assets/images/corona_festa.png'), height: 44, semanticLabel: 'Festa'),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFCDD2)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message, style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
