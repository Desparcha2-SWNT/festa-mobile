import 'package:flutter/widgets.dart';

import 'colors.dart';

/// Movimiento de Festa: duraciones y curvas de las animaciones. Úsalas en vez de escribir `Duration` o
/// `Curves.*` sueltos en las pantallas, igual que con los colores.
///
/// Todas las animaciones respetan el ajuste "reducir animaciones" del teléfono ([reduced]): con él activo
/// no hay movimiento, solo el estado final.
abstract final class FestaMotion {
  /// Respuesta al toque (presionar una tarjeta o un botón).
  static const fast = Duration(milliseconds: 150);

  /// Cambios de estado y entradas de elementos.
  static const base = Duration(milliseconds: 280);

  /// Cambios grandes: una tarjeta que aparece, un resultado que se revela.
  static const slow = Duration(milliseconds: 420);

  /// Celebración completa cuando algo sale bien (ver `FestaCelebration`).
  static const celebrate = Duration(milliseconds: 1700);

  /// Retraso entre elementos de una lista que entran en cascada.
  static const stagger = Duration(milliseconds: 45);

  /// Entrada y cambios de estado.
  static const standard = Curves.easeOutCubic;

  /// Para lo que aparece con "rebote": un check, un sello, un número.
  static const emphasized = Curves.easeOutBack;

  /// Para lo que se va.
  static const exit = Curves.easeInCubic;

  /// Colores del confeti: los acentos de marca del Figma.
  static const confetti = [
    FestaPalette.magenta500,
    FestaPalette.purple500,
    FestaPalette.mint500,
    FestaPalette.yellow400,
    FestaPalette.coral300,
    FestaPalette.lilac200,
  ];

  /// `true` si el teléfono pide reducir animaciones (accesibilidad).
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], o cero si el teléfono pide reducir animaciones.
  static Duration of(BuildContext context, Duration duration) => reduced(context) ? Duration.zero : duration;
}
