import 'package:flutter/material.dart';

/// Tema base de Festa. Centraliza colores y estilos para que las pantallas no los repitan.
abstract final class FestaTheme {
  /// Magenta principal de Festa (#F0127E). Coincide con el logo y el Figma.
  static const primary = Color(0xFFF0127E);

  /// Tinta oscura para texto sobre fondo claro (#111111).
  static const ink = Color(0xFF111111);

  /// Títulos (Bricolage Grotesque) y texto (Plus Jakarta Sans), como en el Figma.
  static const headingFont = 'BricolageGrotesque';
  static const bodyFont = 'PlusJakartaSans';

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static TextTheme _textTheme(Brightness brightness) {
    final base = ThemeData(brightness: brightness).textTheme.apply(fontFamily: bodyFont);
    TextStyle? heading(TextStyle? style) => style?.copyWith(fontFamily: headingFont, fontWeight: FontWeight.w700);
    return base.copyWith(
      displayLarge: heading(base.displayLarge),
      displayMedium: heading(base.displayMedium),
      displaySmall: heading(base.displaySmall),
      headlineLarge: heading(base.headlineLarge),
      headlineMedium: heading(base.headlineMedium),
      headlineSmall: heading(base.headlineSmall),
      titleLarge: heading(base.titleLarge),
    );
  }

  static ThemeData _build(Brightness brightness) => ThemeData(
    fontFamily: bodyFont,
    textTheme: _textTheme(brightness),
    colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: brightness),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD1D1D1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        backgroundColor: primary,
        foregroundColor: ink, // negro sobre magenta (cumple AA: 4.6:1)
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: bodyFont, fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        foregroundColor: ink,
        side: const BorderSide(color: Color(0xFFD1D1D1), width: 1.5),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: bodyFont, fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: primary)),
  );
}
