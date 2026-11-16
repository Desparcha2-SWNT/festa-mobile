import 'package:flutter/painting.dart';

/// Colores del Figma ("Festa — Diseño de la app", página Fundamentos).
///
/// Úsalos en vez de escribir `Color(0x...)` en las pantallas. Si el Figma cambia, se cambia aquí.
/// Las dos capas del Figma se conservan: [FestaPalette] (primitivos) y [FestaColors] (semánticos,
/// los que se usan en las pantallas).
abstract final class FestaPalette {
  static const magenta50 = Color(0xFFFFF2F8);
  static const magenta100 = Color(0xFFFFE3F0);
  static const magenta500 = Color(0xFFF0127E);
  static const magenta700 = Color(0xFFC20A65);

  static const ink900 = Color(0xFF111111);
  static const ink700 = Color(0xFF3A3A3F);
  static const ink500 = Color(0xFF5A5A5A);
  static const ink300 = Color(0xFFB8B8C0);
  static const ink200 = Color(0xFFDEDEE3);
  static const ink100 = Color(0xFFF1F1F4);

  static const paper = Color(0xFFFAFAFA);
  static const white = Color(0xFFFFFFFF);

  static const mint500 = Color(0xFF5CF2A8);
  static const mint100 = Color(0xFFE6FFF3);
  static const lilac200 = Color(0xFFD9CCFF);
  static const purple500 = Color(0xFFA66CFF);
  static const coral300 = Color(0xFFFF9EA6);
  static const yellow400 = Color(0xFFFFD23F);
  static const green600 = Color(0xFF1E9E5A);
  static const red600 = Color(0xFFD64545);
  static const amber700 = Color(0xFFB7791F);
  static const red100 = Color(0xFFFBE4E1);
}

/// Colores semánticos (colección "Color" del Figma, modo Claro).
abstract final class FestaColors {
  // Fondos
  static const bg = FestaPalette.white; // bg/default
  static const bgSubtle = FestaPalette.paper; // bg/subtle
  static const bgMuted = FestaPalette.ink100; // bg/muted
  static const bgBrand = FestaPalette.magenta500; // bg/brand
  static const bgBrandSoft = FestaPalette.magenta100; // bg/brand-soft
  static const bgInverse = FestaPalette.ink900; // bg/inverse
  static const bgIa = FestaPalette.lilac200; // bg/ia (lila = IA)
  static const bgFree = FestaPalette.mint100; // bg/free (menta = gratis)
  static const bgLive = FestaPalette.yellow400; // bg/live (amarillo = Parche en Vivo)
  static const bgErrorSoft = FestaPalette.red100; // bg/error-soft

  // Texto
  static const textPrimary = FestaPalette.ink900; // text/primary
  static const textSecondary = FestaPalette.ink500; // text/secondary
  static const textDisabled = FestaPalette.ink300; // text/disabled
  static const textOnBrand = FestaPalette.ink900; // text/on-brand: negro sobre magenta (AA 4,6:1)
  static const textOnInverse = FestaPalette.white; // text/on-inverse
  static const textBrand = FestaPalette.magenta700; // text/brand
  static const textSuccess = FestaPalette.green600; // text/success
  static const textError = FestaPalette.red600; // text/error

  // Bordes
  static const border = FestaPalette.ink200; // border/default
  static const borderStrong = FestaPalette.ink900; // border/strong
  static const borderBrand = FestaPalette.magenta500; // border/brand

  // Retroalimentación y acentos
  static const success = FestaPalette.green600; // feedback/success
  static const error = FestaPalette.red600; // feedback/error
  static const warning = FestaPalette.amber700; // feedback/warning
  static const accentIa = FestaPalette.purple500; // accent/ia
  static const accentCoral = FestaPalette.coral300; // accent/coral
}
