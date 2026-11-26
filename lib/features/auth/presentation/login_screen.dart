import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/design.dart';
import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../passes/application/passes_providers.dart';
import '../../passes/presentation/my_passes_screen.dart';
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
              const SizedBox(height: 16),
              TextButton(
                onPressed: _submitting ? null : () => context.go(Routes.register),
                child: const Text('¿No tienes cuenta? Regístrate'),
              ),
              // SCRUM-91: si la app abrió sin señal no pudo recuperar la sesión; el QR guardado sigue a mano.
              if (ref.watch(savedPassesOnDeviceProvider).value case final saved?) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('login.savedPasses'),
                  onPressed: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => SavedPassesScreen(saved: saved))),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Ver mis entradas guardadas'),
                ),
              ],
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
