import 'package:flutter/painting.dart';

/// Espaciado del Figma (colección "Espaciado"). Usa estos valores en `padding`, `SizedBox`, etc.
abstract final class FestaSpace {
  static const double xxs = 4; // space/2xs
  static const double xs = 8; // space/xs
  static const double sm = 12; // space/sm
  static const double md = 16; // space/md
  static const double lg = 20; // space/lg
  static const double xl = 24; // space/xl
  static const double xxl = 32; // space/2xl
  static const double xxxl = 40; // space/3xl
}

/// Radios del Figma (colección "Radios").
abstract final class FestaRadius {
  static const double sm = 8; // radius/sm
  static const double md = 12; // radius/md
  static const double lg = 20; // radius/lg
  static const double xl = 28; // radius/xl
  static const double full = 999; // radius/full

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
}
