/// Sistema de diseño de Festa: tokens del Figma ("Festa — Diseño de la app").
///
/// Importa solo este archivo desde las pantallas:
/// `import '<ruta>/app/design/design.dart';`
///
/// Reglas del equipo:
/// - Nada de `Color(0x...)`, `Colors.*`, tamaños de fuente ni radios sueltos en las pantallas:
///   usa [FestaColors], [FestaSpace], [FestaRadius] y `Theme.of(context).textTheme`.
/// - Si falta un valor, se agrega primero al Figma (Fundamentos) y luego aquí, no al revés.
library;

export 'colors.dart';
export 'spacing.dart';
export 'typography.dart';
