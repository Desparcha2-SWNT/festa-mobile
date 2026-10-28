import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../application/session_controller.dart';
import '../domain/account.dart';
import 'auth_validators.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/password_field.dart';

/// SCRUM-50: registro con correo y contraseña.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  AccountType _accountType = AccountType.user;
  bool _submitting = false;
  ApiException? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // Al quedar autenticado, el router lleva al inicio.
      await ref
          .read(sessionControllerProvider.notifier)
          .register(
            email: _email.text.trim(),
            password: _password.text,
            displayName: _name.text.trim(),
            accountType: _accountType,
          );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fieldErrors = _error?.fieldErrors ?? const {};
    return AuthScaffold(
      title: 'Crea tu cuenta',
      subtitle: 'Regístrate para descubrir y crear planes.',
      errorMessage: _error?.message,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<AccountType>(
                segments: const [
                  ButtonSegment(value: AccountType.user, label: Text('Persona'), icon: Icon(Icons.person_outline)),
                  ButtonSegment(
                    value: AccountType.merchant,
                    label: Text('Comercio'),
                    icon: Icon(Icons.storefront_outlined),
                  ),
                ],
                selected: {_accountType},
                onSelectionChanged: _submitting ? null : (s) => setState(() => _accountType = s.single),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('register.name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                validator: AuthValidators.displayName,
                decoration: InputDecoration(
                  labelText: _accountType == AccountType.merchant ? 'Nombre del comercio' : 'Nombre',
                  errorText: fieldErrors['displayName'],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('register.email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: AuthValidators.email,
                decoration: InputDecoration(labelText: 'Correo electrónico', errorText: fieldErrors['email']),
              ),
              const SizedBox(height: 16),
              PasswordField(
                key: const Key('register.password'),
                controller: _password,
                label: 'Contraseña',
                validator: AuthValidators.newPassword,
                errorText: fieldErrors['password'],
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 16),
              PasswordField(
                key: const Key('register.confirmPassword'),
                controller: _confirmPassword,
                label: 'Confirma la contraseña',
                validator: AuthValidators.confirmPassword(() => _password.text),
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('register.submit'),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Crear cuenta'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _submitting ? null : () => context.go(Routes.login),
                child: const Text('¿Ya tienes cuenta? Inicia sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
