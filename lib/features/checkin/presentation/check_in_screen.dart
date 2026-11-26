import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/design.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/http_providers.dart';
import '../data/check_in_api.dart';
import '../domain/check_in_result.dart';
import 'qr_scanner_view.dart';

final checkInApiProvider = Provider<CheckInApi>((ref) => CheckInApi(ref.watch(authenticatedDioProvider)));

/// SCRUM-92: el organizador escanea el QR de cada entrada en la puerta. Cada lectura se valida en booking,
/// que la marca como usada una sola vez, y el resultado se muestra hasta que se pide la siguiente.
class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  bool _checking = false;
  CheckInResult? _result;
  String? _error;

  /// Sube con cada rechazo: es lo que dispara la sacudida, así un redibujo cualquiera no la repite.
  int _rejections = 0;

  Future<void> _onCode(String qr) async {
    // Mientras se valida uno o se muestra su resultado, la cámara no manda otro.
    if (_checking || _result != null || _error != null) return;
    setState(() => _checking = true);
    try {
      final result = await ref.read(checkInApiProvider).checkIn(eventId: widget.eventId, qr: qr);
      // En la puerta se mira poco la pantalla: válido y rechazado vibran distinto.
      unawaited(result.valid ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact());
      if (mounted) {
        setState(() {
          _result = result;
          if (!result.valid) _rejections++;
        });
      }
    } on ApiException catch (e) {
      unawaited(HapticFeedback.heavyImpact());
      if (mounted) {
        setState(() {
          _error = e.message;
          _rejections++;
        });
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _next() => setState(() {
    _result = null;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final buildScanner = ref.watch(qrScannerBuilderProvider);
    final waiting = _result == null && _error == null;
    return Scaffold(
      backgroundColor: FestaColors.bgInverse,
      appBar: AppBar(title: const Text('Escanear entradas')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: buildScanner(_onCode)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(FestaSpace.md),
              child: AnimatedSwitcher(
                duration: FestaMotion.of(context, FestaMotion.base),
                switchInCurve: FestaMotion.emphasized,
                switchOutCurve: FestaMotion.exit,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                ),
                child: waiting
                    ? Text(
                        _checking ? 'Validando…' : 'Apunta la cámara al QR de la entrada.',
                        key: const Key('checkIn.hint'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: FestaColors.textOnInverse),
                      )
                    // Un rechazo se sacude: se entiende "no" antes de leer el motivo.
                    : FestaShake(
                        key: const ValueKey('checkIn.result'),
                        trigger: (_result?.valid ?? false) ? null : _rejections,
                        child: _ResultCard(result: _result, error: _error, onNext: _next),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.error, required this.onNext});

  final CheckInResult? result;
  final String? error;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ok = result?.valid ?? false;
    final title = result?.message ?? 'No pudimos validar la entrada';
    final used = result?.firstUsedAt?.toLocal();
    final detail =
        error ??
        (used == null
            ? null
            : 'Entró a las ${used.hour % 12 == 0 ? 12 : used.hour % 12}:${used.minute.toString().padLeft(2, '0')} '
                  '${used.hour < 12 ? 'a. m.' : 'p. m.'}');
    return DecoratedBox(
      key: Key(ok ? 'checkIn.valid' : 'checkIn.rejected'),
      decoration: BoxDecoration(
        color: ok ? FestaColors.bgFree : FestaColors.bgErrorSoft,
        borderRadius: FestaRadius.mdAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(FestaSpace.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // El ícono crece con rebote al aparecer el resultado.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.3, end: 1),
              duration: FestaMotion.of(context, FestaMotion.slow),
              curve: FestaMotion.emphasized,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Icon(
                ok ? Icons.check_circle : Icons.cancel,
                size: FestaSpace.xxxl,
                color: ok ? FestaColors.textSuccess : FestaColors.textError,
              ),
            ),
            const SizedBox(height: FestaSpace.xs),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (detail != null) ...[const SizedBox(height: FestaSpace.xxs), Text(detail, textAlign: TextAlign.center)],
            const SizedBox(height: FestaSpace.md),
            FilledButton(key: const Key('checkIn.next'), onPressed: onNext, child: const Text('Escanear otra')),
          ],
        ),
      ),
    );
  }
}
