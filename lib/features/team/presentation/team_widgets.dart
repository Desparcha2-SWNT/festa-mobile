import 'package:flutter/material.dart';

import '../../../app/design/design.dart';

// Piezas comunes de las pantallas del equipo Festa: revisión de comercios (SCRUM-61) y de reportes (SCRUM-110).

/// Dato de una solicitud o un reporte: etiqueta pequeña y el valor debajo, como en el Figma 29.
class TeamField extends StatelessWidget {
  const TeamField({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: FestaSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodySmall?.copyWith(color: FestaColors.textSecondary)),
          const SizedBox(height: FestaSpace.xxs),
          Text(value, style: text.bodyLarge),
        ],
      ),
    );
  }
}

class TeamInfoBox extends StatelessWidget {
  const TeamInfoBox(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: FestaColors.bgSubtle, borderRadius: FestaRadius.mdAll),
    child: Padding(
      padding: const EdgeInsets.all(FestaSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 20, color: FestaColors.textSecondary),
          const SizedBox(width: FestaSpace.xs),
          Expanded(
            child: Text(text, style: const TextStyle(color: FestaColors.textSecondary)),
          ),
        ],
      ),
    ),
  );
}

/// Mensaje centrado de lista vacía o de error, con una acción opcional.
class TeamMessage extends StatelessWidget {
  const TeamMessage({required this.title, required this.body, this.action, super.key});

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(FestaSpace.xxl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: FestaSpace.xs),
        Text(body, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: FestaSpace.xl), action!],
      ],
    ),
  );
}
