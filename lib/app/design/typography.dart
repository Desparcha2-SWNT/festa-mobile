import 'package:flutter/material.dart';

import 'colors.dart';

/// Estilos de texto del Figma (9 estilos). Títulos grandes en Bricolage Grotesque; el resto en
/// Plus Jakarta Sans. Fuentes empaquetadas en `assets/fonts/` (ver `pubspec.yaml`).
///
/// Prefiere `Theme.of(context).textTheme` (ya está mapeado aquí); usa estos directamente solo
/// cuando el estilo no tenga un equivalente en Material.
abstract final class FestaText {
  static const headingFont = 'BricolageGrotesque';
  static const bodyFont = 'PlusJakartaSans';

  static const displayL = TextStyle(
    fontFamily: headingFont,
    fontSize: 40,
    height: 44 / 40,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: FestaColors.textPrimary,
  );
  static const titleL = TextStyle(
    fontFamily: headingFont,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: FestaColors.textPrimary,
  );
  static const titleM = TextStyle(
    fontFamily: bodyFont,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w700,
    color: FestaColors.textPrimary,
  );
  static const titleS = TextStyle(
    fontFamily: bodyFont,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w700,
    color: FestaColors.textPrimary,
  );
  static const bodyL = TextStyle(
    fontFamily: bodyFont,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    color: FestaColors.textPrimary,
  );
  static const bodyM = TextStyle(
    fontFamily: bodyFont,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: FestaColors.textPrimary,
  );
  static const labelL = TextStyle(
    fontFamily: bodyFont,
    fontSize: 16,
    height: 20 / 16,
    fontWeight: FontWeight.w600,
    color: FestaColors.textPrimary,
  );
  static const labelM = TextStyle(
    fontFamily: bodyFont,
    fontSize: 14,
    height: 18 / 14,
    fontWeight: FontWeight.w600,
    color: FestaColors.textPrimary,
  );
  static const caption = TextStyle(
    fontFamily: bodyFont,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: FestaColors.textSecondary,
  );

  /// Mapeo a los estilos de Material, para que `Theme.of(context).textTheme` ya traiga el Figma.
  static const textTheme = TextTheme(
    displayLarge: displayL,
    displayMedium: titleL,
    headlineLarge: titleL,
    headlineMedium: titleL,
    headlineSmall: titleM,
    titleLarge: titleM,
    titleMedium: titleS,
    titleSmall: titleS,
    bodyLarge: bodyL,
    bodyMedium: bodyM,
    bodySmall: caption,
    labelLarge: labelL,
    labelMedium: labelM,
    labelSmall: caption,
  );
}
