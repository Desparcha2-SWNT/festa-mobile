import 'package:flutter/material.dart';

/// Tema base de Festa. Centraliza colores y estilos para que las pantallas no los repitan.
abstract final class FestaTheme {
  static const _seed = Color(0xFFE4572E);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(64, 48))),
  );
}
