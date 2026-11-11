import 'package:flutter/material.dart';

/// Tema base de Festa. Centraliza colores y estilos para que las pantallas no los repitan.
///
/// Colores de la página «Fundamentos» del Figma. El texto sobre el magenta de marca va en
/// tinta y no en blanco: el blanco no alcanza el contraste 4.5:1.
abstract final class FestaTheme {
  static const brand = Color(0xFFF0127E);
  static const brandDark = Color(0xFFC20A65);
  static const brandSoft = Color(0xFFFFE3F0);
  static const ink = Color(0xFF111111);
  static const success = Color(0xFF1E9E5A);

  static ThemeData light() => _build(
    ColorScheme.fromSeed(seedColor: brand).copyWith(
      primary: brand,
      onPrimary: ink,
      primaryContainer: brandSoft,
      onPrimaryContainer: brandDark,
      tertiary: success,
    ),
  );

  static ThemeData dark() => _build(
    ColorScheme.fromSeed(seedColor: brand, brightness: Brightness.dark).copyWith(primary: brand, onPrimary: ink),
  );

  static ThemeData _build(ColorScheme colorScheme) {
    const buttonSize = Size(64, 48);
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(24));
    return ThemeData(
      colorScheme: colorScheme,
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: buttonSize, shape: buttonShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.onSurface),
        ),
      ),
    );
  }
}
