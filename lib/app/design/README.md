# Sistema de diseño de Festa (front)

Tokens del Figma **"Festa — Diseño de la app"** (página *Fundamentos*), hechos código. Todo el que programe
una pantalla usa esto, para que la app se vea igual que el diseño.

```dart
import '../../../app/design/design.dart';   // ajusta la ruta relativa

Container(
  padding: const EdgeInsets.all(FestaSpace.md),
  decoration: BoxDecoration(color: FestaColors.bgBrandSoft, borderRadius: FestaRadius.mdAll),
  child: Text('Hola', style: Theme.of(context).textTheme.titleMedium),
);
```

| Qué | Dónde | Figma |
|---|---|---|
| Colores | `FestaColors` (semánticos) y `FestaPalette` (primitivos) | variables *Primitivos* y *Color* |
| Espaciado | `FestaSpace` (4, 8, 12, 16, 20, 24, 32, 40) | *Espaciado* |
| Radios | `FestaRadius` (8, 12, 20, 28, completo) | *Radios* |
| Texto | `Theme.of(context).textTheme` (mapeado a los 9 estilos) o `FestaText` | 9 estilos de texto |
| Movimiento | `FestaMotion` (duraciones, curvas, colores del confeti) y los widgets de `widgets/` | — (no está en el Figma todavía) |
| Tema | `FestaTheme` (`lib/app/theme.dart`): botones, campos de texto, colores base | componentes |
| Fuentes | `assets/fonts/` (Bricolage Grotesque y Plus Jakarta Sans, OFL) | tipografías |
| Logo y corona | `assets/images/logo_festa.png` (solo splash) y `corona_festa.png` (resto) | — |

## Reglas

1. **Nada suelto en las pantallas:** ni `Color(0x...)`, ni `Colors.*`, ni `fontSize`, ni radios o espacios con números
   propios. Usa los tokens. (La única excepción son los colores de marca de terceros, como el logo de Google.)
2. **Los botones y campos ya vienen del tema.** Usa `FilledButton`, `OutlinedButton`, `TextButton` y `TextFormField`
   sin estilos propios; si necesitas una variante, agrégala al tema.
3. **Si falta un valor, primero se agrega al Figma** (Fundamentos) y luego aquí, no al revés. Así Figma y código no se
   separan.
4. **Texto sobre magenta va en negro** (`FestaColors.textOnBrand`): el blanco no cumple contraste AA.
5. **Colores con significado:** lila = IA, menta = gratis, amarillo = Parche en Vivo.
6. Conserva las llaves de las pruebas (`Key('login.email')`, etc.) al restilizar.

## Movimiento

La app se mueve para confirmar lo que pasó, no para decorar. Widgets listos (exportados desde `design.dart`):

| Widget | Cuándo |
|---|---|
| `FestaCelebration.show(context, title: …)` | Algo importante salió bien: confirmar asistencia, publicar un evento, enviar una solicitud. Check animado y confeti de marca; no bloquea los toques. **Su título debe ser distinto al texto del SnackBar** (el SnackBar se mantiene para el lector de pantalla y las pruebas). |
| `FestaFadeSlideIn(index: i)` | Elementos de una lista que entran en cascada. |
| `FestaPressable` | Tarjetas tocables: se hunden un poco al presionar. |
| `FestaShake(trigger: …)` | Algo se rechazó (QR inválido, formulario con errores). |
| `FestaAnimatedCount` | Números que cambian (asistentes, cupos). |
| `FestaSkeleton` | Mientras carga una lista o tarjeta, en vez del indicador circular. |

Reglas:

1. **Respeta "reducir animaciones" del teléfono.** Los widgets ya lo hacen con `FestaMotion.reduced`; si animas a mano, usa `FestaMotion.of(context, duración)`.
2. **Duraciones y curvas de `FestaMotion`,** no `Duration` ni `Curves` sueltos.
3. **Nada que se repita sin fin en una pantalla que ya cargó** (hace que `pumpAndSettle` nunca termine en las pruebas). `FestaSkeleton` solo mientras carga.
4. **Liviano:** pocas piezas animadas a la vez (gama baja, RNF9).

## Pendiente

- Llevar los tokens de movimiento (`FestaMotion`) al Figma (Fundamentos).

- Modo oscuro: el Figma solo define el modo claro. `FestaTheme.dark()` existe pero no está diseñado.
- Componentes compartidos del Figma que aún no existen como widgets: tarjeta de evento, chip de interés, barra
  superior y barras de navegación (usuario y organizador). Créalos en `lib/app/design/` cuando una pantalla los necesite.
