import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    return AuthScaffold(
      title: 'Inicia sesión',
      subtitle: 'Encuentra los planes que hay cerca de ti.',
      errorMessage: _error?.message,
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('login.email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: AuthValidators.email,
                decoration: InputDecoration(labelText: 'Correo electrónico', errorText: _error?.fieldErrors['email']),
              ),
              const SizedBox(height: 16),
              PasswordField(
                key: const Key('login.password'),
                controller: _password,
                label: 'Contraseña',
                validator: AuthValidators.requiredPassword,
                errorText: _error?.fieldErrors['password'],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('login.submit'),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Iniciar sesión'),
              ),
              const SizedBox(height: 12),
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
