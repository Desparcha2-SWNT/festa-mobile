import 'package:flutter/material.dart';

import 'design/design.dart';

/// Tema base de Festa, construido con los tokens del Figma (`lib/app/design/`).
/// Las pantallas no deben repetir colores ni estilos: usan este tema y los tokens.
abstract final class FestaTheme {
  /// Magenta principal (#F0127E). Se conserva por compatibilidad: prefiere [FestaColors.bgBrand].
  static const primary = FestaColors.bgBrand;

  /// Tinta (#111111). Se conserva por compatibilidad: prefiere [FestaColors.textPrimary].
  static const ink = FestaColors.textPrimary;

  static ThemeData light() => _build(Brightness.light);

  // El Figma solo define el modo claro; el oscuro queda pendiente. Mientras tanto la app siempre usa el claro.
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: FestaColors.bgBrand,
      brightness: brightness,
    ).copyWith(primary: FestaColors.bgBrand, onPrimary: FestaColors.textOnBrand, error: FestaColors.error);
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: FestaRadius.mdAll,
      borderSide: BorderSide(color: color, width: width),
    );
    return ThemeData(
      fontFamily: FestaText.bodyFont,
      textTheme: FestaText.textTheme,
      colorScheme: scheme,
      scaffoldBackgroundColor: FestaColors.bg,
      inputDecorationTheme: InputDecorationTheme(
        border: border(FestaColors.border),
        enabledBorder: border(FestaColors.border),
        focusedBorder: border(FestaColors.borderBrand, 2),
        errorBorder: border(FestaColors.error),
        focusedErrorBorder: border(FestaColors.error, 2),
        filled: true,
        fillColor: FestaColors.bg,
        labelStyle: FestaText.bodyL.copyWith(color: FestaColors.textSecondary),
        hintStyle: FestaText.bodyL.copyWith(color: FestaColors.textDisabled),
        errorStyle: FestaText.caption.copyWith(color: FestaColors.textError),
        contentPadding: const EdgeInsets.symmetric(horizontal: FestaSpace.md, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          backgroundColor: FestaColors.bgBrand,
          foregroundColor: FestaColors.textOnBrand, // negro sobre magenta (AA)
          disabledBackgroundColor: FestaColors.bgMuted,
          disabledForegroundColor: FestaColors.textDisabled,
          shape: const StadiumBorder(),
          textStyle: FestaText.labelL,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          foregroundColor: FestaColors.textPrimary,
          side: const BorderSide(color: FestaColors.border, width: 1.5),
          shape: const StadiumBorder(),
          textStyle: FestaText.labelL,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: FestaColors.textBrand, textStyle: FestaText.labelM),
      ),
    );
  }
}
