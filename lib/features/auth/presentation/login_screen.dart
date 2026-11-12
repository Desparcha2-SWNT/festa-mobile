import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/design.dart';
import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../application/session_controller.dart';
import 'auth_validators.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/password_field.dart';

/// SCRUM-51: inicio de sesión con correo y contraseña.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _submitting = false;

  /// Tras el primer intento de envío los errores se actualizan mientras el usuario escribe.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  ApiException? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // Al quedar autenticado, el router lleva al inicio.
      await ref.read(sessionControllerProvider.notifier).login(email: _email.text.trim(), password: _password.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // El error de credenciales se muestra sobre el campo de correo (como en el Figma).
    final credentialsError = _error != null ? 'Correo o contraseña incorrectos.' : null;

    return AuthScaffold(
      title: 'Qué bueno verte\nde nuevo',
      subtitle: 'Entra para encontrar el plan de hoy.',
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner de error de credenciales (justo encima del campo correo, como Figma)
              if (credentialsError != null) ...[
                _CredentialsError(message: credentialsError),
                const SizedBox(height: 12),
              ],
              TextFormField(
                key: const Key('login.email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: AuthValidators.email,
                decoration: const InputDecoration(labelText: 'Correo'),
              ),
              const SizedBox(height: 16),
              PasswordField(
                key: const Key('login.password'),
                controller: _password,
                label: 'Contraseña',
                validator: AuthValidators.requiredPassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              // Botón principal — muestra "Iniciando sesión..." cuando carga (como Figma 2c)
              FilledButton(
                key: const Key('login.submit'),
                onPressed: _submitting ? null : _submit,
                child: _submitting ? const Text('Iniciando sesión...') : const Text('Iniciar sesión'),
              ),
              const SizedBox(height: 20),
              // Divisor con círculo (Figma: separador entre botones)
              const _OrDivider(),
              const SizedBox(height: 20),
              // Botón de Google (el backend soporta POST /auth/google; la app aún no implementa el flujo)
              OutlinedButton.icon(
                key: const Key('login.google'),
                onPressed: _submitting
                    ? null
                    : () {
                        // TODO(SCRUM-?): implementar flujo OAuth de Google en la app
                      },
                icon: const _GoogleLogo(),
                label: const Text('Continuar con Google'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _submitting ? null : () => context.go(Routes.register),
                child: const Text('¿No tienes cuenta? Regístrate'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banner de error de credenciales (rojo, con ícono, encima del campo correo).
class _CredentialsError extends StatelessWidget {
  const _CredentialsError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: FestaColors.bgErrorSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: FestaColors.error),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: FestaColors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(color: FestaColors.error, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Divisor circular entre los dos botones (Figma: un círculo ○ centrado).
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('○', style: TextStyle(color: FestaColors.textDisabled, fontSize: 12)),
        ),
        Expanded(child: Divider()),
      ],
    );
  }
}

/// Logo de Google en SVG simplificado (sin dependencia externa).
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 20, height: 20, child: CustomPaint(painter: _GoogleLogoPainter()));
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Arco rojo (superior)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -1.57,
      3.14,
      false,
      Paint()
        ..color = const Color(0xFFEA4335)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18,
    );
    // Arco verde (inferior izq)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      1.57,
      1.57,
      false,
      Paint()
        ..color = const Color(0xFF34A853)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18,
    );
    // Arco amarillo (inferior der)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      0,
      1.57,
      false,
      Paint()
        ..color = const Color(0xFFFBBC05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18,
    );
    // Línea azul horizontal (ala derecha)
    final paint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, Offset(size.width, center.dy), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
