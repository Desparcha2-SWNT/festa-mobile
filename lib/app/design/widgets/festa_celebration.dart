import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../motion.dart';
import '../spacing.dart';
import '../typography.dart';

/// Celebración breve cuando algo sale bien: confirmar que vas, publicar un evento, enviar una solicitud.
///
/// Un círculo magenta aparece con rebote, se dibuja el check y sale confeti con los colores de marca. Dura
/// [FestaMotion.celebrate] y se quita sola. No bloquea los toques: la persona puede seguir usando la app.
///
/// No reemplaza el `SnackBar`: el mensaje del SnackBar sigue siendo el que lee el lector de pantalla. Por eso
/// el [title] de la celebración debe ser distinto al texto del SnackBar.
abstract final class FestaCelebration {
  /// Muestra la celebración sobre toda la app. Toma el `Overlay` raíz en el momento de la llamada, así que se
  /// puede llamar justo antes de navegar a otra pantalla.
  static void show(
    BuildContext context, {
    required String title,
    String? message,
    IconData? icon,
    bool confetti = true,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final reduced = FestaMotion.reduced(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => FestaCelebrationView(
        title: title,
        message: message,
        icon: icon,
        confetti: confetti && !reduced,
        reduced: reduced,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
    HapticFeedback.mediumImpact();
  }
}

/// La animación de [FestaCelebration]. Es pública solo para poder probarla; en las pantallas usa
/// [FestaCelebration.show].
class FestaCelebrationView extends StatefulWidget {
  const FestaCelebrationView({
    required this.title,
    required this.onDone,
    this.message,
    this.icon,
    this.confetti = true,
    this.reduced = false,
    super.key,
  });

  final String title;
  final String? message;

  /// Ícono del círculo. Si es `null` se dibuja un check animado.
  final IconData? icon;
  final bool confetti;
  final bool reduced;
  final VoidCallback onDone;

  @override
  State<FestaCelebrationView> createState() => _FestaCelebrationViewState();
}

class _FestaCelebrationViewState extends State<FestaCelebrationView> with SingleTickerProviderStateMixin {
  static const _badgeSize = 104.0;

  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: widget.reduced ? const Duration(milliseconds: 1100) : FestaMotion.celebrate,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onDone();
        });
    _particles = widget.confetti ? _Particle.burst(math.Random()) : const [];
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Valor de [curve] dentro del tramo [begin]–[end] de la animación completa.
  double _phase(double begin, double end, [Curve curve = Curves.linear]) =>
      curve.transform(((_controller.value - begin) / (end - begin)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // El Overlay raíz no tiene Material encima: sin él, el texto sale con el subrayado amarillo de
    // depuración y sin el estilo de la app.
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          liveRegion: true,
          label: [widget.title, ?widget.message].join('. '),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              // Entra rápido y se va al final.
              final visible = _phase(0, 0.1) * (1 - _phase(0.82, 1, FestaMotion.exit));
              final badge = widget.reduced ? 1.0 : _phase(0, 0.32, FestaMotion.emphasized);
              final check = widget.reduced ? 1.0 : _phase(0.16, 0.42, Curves.easeOutCubic);
              final ring = _phase(0.14, 0.62, Curves.easeOutCubic);
              final burst = _phase(0.1, 0.96);
              final caption = widget.reduced ? 1.0 : _phase(0.24, 0.5, FestaMotion.standard);
              return Opacity(
                opacity: visible,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: FestaColors.bg.withValues(alpha: 0.9)),
                    if (_particles.isNotEmpty)
                      RepaintBoundary(child: CustomPaint(painter: _ConfettiPainter(_particles, burst))),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: _badgeSize * 2,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (!widget.reduced)
                                  // Anillo que se expande y se desvanece detrás del círculo.
                                  Container(
                                    width: _badgeSize * (1 + ring * 0.9),
                                    height: _badgeSize * (1 + ring * 0.9),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: FestaColors.borderBrand.withValues(alpha: (1 - ring) * 0.6),
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                Transform.scale(
                                  scale: badge,
                                  child: Container(
                                    width: _badgeSize,
                                    height: _badgeSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: FestaColors.bgBrand,
                                      boxShadow: [
                                        BoxShadow(
                                          color: FestaColors.bgBrand.withValues(alpha: 0.22),
                                          blurRadius: 28,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: widget.icon == null
                                        ? CustomPaint(painter: _CheckPainter(check))
                                        : Opacity(
                                            opacity: check,
                                            child: Icon(widget.icon, size: 52, color: FestaColors.textOnBrand),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Opacity(
                            opacity: caption,
                            child: Transform.translate(
                              offset: Offset(0, (1 - caption) * FestaSpace.md),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: FestaSpace.xxl),
                                child: Column(
                                  children: [
                                    Text(widget.title, style: FestaText.titleL, textAlign: TextAlign.center),
                                    if (widget.message != null) ...[
                                      const SizedBox(height: FestaSpace.xs),
                                      Text(
                                        widget.message!,
                                        style: text.bodyLarge?.copyWith(color: FestaColors.textSecondary),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Check que se dibuja de izquierda a derecha según [progress] (0–1). Negro sobre magenta (contraste AA).
class _CheckPainter extends CustomPainter {
  _CheckPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.28, w * 0.52)
      ..lineTo(w * 0.44, w * 0.67)
      ..lineTo(w * 0.73, w * 0.36);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = FestaColors.textOnBrand
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.085
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

/// Un papelito del confeti. Sale del centro en una dirección, frena y cae con gravedad.
class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.spin,
    required this.round,
  });

  /// Pocas piezas a propósito: se ve lleno y no pesa en teléfonos de gama baja (RNF9).
  static const count = 32;

  static List<_Particle> burst(math.Random random) => List.generate(count, (i) {
    return _Particle(
      angle: (i / count) * 2 * math.pi + random.nextDouble() * 0.4,
      speed: 150 + random.nextDouble() * 170,
      size: 6 + random.nextDouble() * 6,
      color: FestaMotion.confetti[i % FestaMotion.confetti.length],
      spin: (random.nextDouble() - 0.5) * 12,
      round: random.nextBool(),
    );
  });

  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double spin;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.progress);

  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    // El estallido sale del centro del círculo, un poco arriba del centro de la pantalla.
    final origin = Offset(size.width / 2, size.height / 2 - 60);
    final travel = Curves.easeOutCubic.transform(progress);
    final gravity = progress * progress * 260;
    final fade = 1 - math.pow(progress, 3).toDouble();
    final paint = Paint();
    for (final p in particles) {
      final position = origin + Offset(math.cos(p.angle), math.sin(p.angle)) * p.speed * travel + Offset(0, gravity);
      paint.color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(p.spin * progress);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
