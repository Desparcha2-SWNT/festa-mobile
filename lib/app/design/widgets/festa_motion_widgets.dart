import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../colors.dart';
import '../motion.dart';
import '../spacing.dart';

/// Hace aparecer [child] subiendo un poco y desvaneciéndose. En una lista, pasa el [index] de cada elemento
/// para que entren en cascada (los primeros 8; del 9 en adelante entran juntos).
class FestaFadeSlideIn extends StatefulWidget {
  const FestaFadeSlideIn({required this.child, this.index = 0, this.offset = 0.08, super.key});

  final Widget child;
  final int index;

  /// Cuánto sube al entrar, como fracción de su propia altura.
  final double offset;

  @override
  State<FestaFadeSlideIn> createState() => _FestaFadeSlideInState();
}

class _FestaFadeSlideInState extends State<FestaFadeSlideIn> with SingleTickerProviderStateMixin {
  static const _maxStaggered = 8;

  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    final delay = FestaMotion.stagger * math.min(widget.index, _maxStaggered);
    final total = delay + FestaMotion.slow;
    _controller = AnimationController(vsync: this, duration: total);
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay.inMicroseconds / total.inMicroseconds, 1, curve: FestaMotion.standard),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Se decide aquí y no en initState porque necesita el MediaQuery.
    if (_controller.isDismissed) {
      FestaMotion.reduced(context) ? _controller.value = 1 : _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: SlideTransition(
      position: Tween(begin: Offset(0, widget.offset), end: Offset.zero).animate(_curve),
      child: widget.child,
    ),
  );
}

/// Se "hunde" un poco mientras se presiona, para que tocar una tarjeta se sienta. No maneja el toque: el
/// [child] sigue siendo el que tiene el `onTap` (InkWell, botón…).
class FestaPressable extends StatefulWidget {
  const FestaPressable({required this.child, this.scale = 0.97, super.key});

  final Widget child;
  final double scale;

  @override
  State<FestaPressable> createState() => _FestaPressableState();
}

class _FestaPressableState extends State<FestaPressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down ? widget.scale : 1,
      duration: FestaMotion.of(context, FestaMotion.fast),
      curve: FestaMotion.standard,
      child: widget.child,
    ),
  );
}

/// Sacude [child] de lado a lado cada vez que cambia [trigger] (por ejemplo, el id de un rechazo). Sirve
/// para decir "esto no" sin texto extra, junto al mensaje de error.
class FestaShake extends StatefulWidget {
  const FestaShake({required this.trigger, required this.child, super.key});

  /// Cualquier valor; la sacudida ocurre cuando cambia y no es `null`.
  final Object? trigger;
  final Widget child;

  @override
  State<FestaShake> createState() => _FestaShakeState();
}

class _FestaShakeState extends State<FestaShake> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: FestaMotion.slow);

  @override
  void initState() {
    super.initState();
    if (widget.trigger != null) WidgetsBinding.instance.addPostFrameCallback((_) => _shake());
  }

  @override
  void didUpdateWidget(FestaShake old) {
    super.didUpdateWidget(old);
    if (widget.trigger != null && widget.trigger != old.trigger) _shake();
  }

  void _shake() {
    if (!mounted || FestaMotion.reduced(context)) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      // Onda que se apaga: tres vaivenes cada vez más cortos.
      final t = _controller.value;
      final dx = math.sin(t * math.pi * 6) * (1 - t) * FestaSpace.sm;
      return Transform.translate(offset: Offset(dx, 0), child: child);
    },
  );
}

/// Número que cuenta hasta su valor nuevo cuando cambia (por ejemplo, los asistentes de un evento).
class FestaAnimatedCount extends StatelessWidget {
  const FestaAnimatedCount({required this.value, required this.builder, super.key});

  final int value;

  /// Arma el texto con el número que se está mostrando en ese momento.
  final Widget Function(BuildContext context, int shown) builder;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.toDouble()),
    duration: FestaMotion.of(context, FestaMotion.slow),
    curve: FestaMotion.standard,
    builder: (context, shown, _) => builder(context, shown.round()),
  );
}

/// Bloque gris con un brillo que lo recorre, para mostrar dónde va a aparecer el contenido mientras carga.
/// Reemplaza al indicador circular en listas y tarjetas.
class FestaSkeleton extends StatefulWidget {
  const FestaSkeleton({this.width, this.height = 16, this.radius, super.key});

  final double? width;
  final double height;
  final BorderRadius? radius;

  @override
  State<FestaSkeleton> createState() => _FestaSkeletonState();
}

class _FestaSkeletonState extends State<FestaSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    FestaMotion.reduced(context) ? _controller.stop() : _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Cargando',
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final x = _controller.value * 3 - 1; // el brillo cruza de -1 a 2
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.radius ?? BorderRadius.circular(widget.height / 3),
            gradient: LinearGradient(
              begin: Alignment(x - 1, 0),
              end: Alignment(x + 1, 0),
              colors: const [FestaColors.bgMuted, FestaColors.bgSubtle, FestaColors.bgMuted],
            ),
          ),
        );
      },
    ),
  );
}

/// Tres puntos que rebotan mientras alguien "escribe" (la IA del chat). Lila = IA, como en el Figma.
/// Se repite sin fin: muéstralo solo mientras de verdad se espera la respuesta.
class FestaTypingDots extends StatefulWidget {
  const FestaTypingDots({this.color = FestaPalette.purple500, super.key});

  final Color color;

  @override
  State<FestaTypingDots> createState() => _FestaTypingDotsState();
}

class _FestaTypingDotsState extends State<FestaTypingDots> with SingleTickerProviderStateMixin {
  static const _dot = 8.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    FestaMotion.reduced(context) ? _controller.stop() : _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Escribiendo',
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                // Cada punto sube un poco después del anterior.
                offset: Offset(0, -math.max(0, math.sin((_controller.value - i * 0.18) * 2 * math.pi)) * 5),
                child: Container(
                  width: _dot,
                  height: _dot,
                  decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
