import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/design.dart';
import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../merchant/data/merchant_api.dart';
import '../application/session_controller.dart';
import '../domain/account.dart';
import 'auth_validators.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/password_field.dart';

const _privacyRequired = 'Debes autorizar el tratamiento de tus datos personales para registrarte.';
const _privacyText =
    'Autorizo el tratamiento de mis datos personales según la Política de privacidad de Festa '
    '(versión 1.0). Puedo conocerlos, actualizarlos y suprimirlos cuando quiera.';

/// Pantalla de registro. Persona = 1 pantalla. Comercio = asistente de 3 pasos.
/// SCRUM-50: registro con correo y contraseña. SCRUM-126: exige la autorización de datos.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  AccountType _accountType = AccountType.user;

  // Paso 1 (ambos roles)
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _acceptedPrivacy = false;

  // Paso 2 (comercio)
  final _address = TextEditingController();
  String? _category; // valor en español, se mapea al enum del backend al enviar
  static const _categories = ['Cultural', 'Musical', 'Deportivo', 'Gastronómico', 'Otro'];
  static const _categoryApiValues = {
    'Cultural': 'CULTURAL',
    'Musical': 'MUSICAL',
    'Deportivo': 'DEPORTIVO',
    'Gastronómico': 'GASTRONOMICO',
    'Otro': 'OTRO',
  };
  static const _bogotaLatitude = 4.7110;
  static const _bogotaLongitude = -74.0721;

  // Paso 3 (comercio)
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _nitOrUrl = TextEditingController();

  // Control del asistente
  int _step = 1; // 1, 2 o 3
  bool _submitting = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  ApiException? _error;

  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _address.dispose();
    _description.dispose();
    _phone.dispose();
    _nitOrUrl.dispose();
    super.dispose();
  }

  Future<void> _submitPersona() async {
    if (!_formKey1.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .register(
            email: _email.text.trim(),
            password: _password.text,
            displayName: _name.text.trim(),
            accountType: AccountType.user,
            acceptedPrivacyPolicy: _acceptedPrivacy,
          );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _nextStep() {
    final key = _step == 1 ? _formKey1 : _formKey2;
    if (!key.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    if (_step == 2 && _category == null) {
      setState(() {}); // fuerza el rebuild para mostrar el error de categoría
      return;
    }
    setState(() {
      _step++;
      _autovalidateMode = AutovalidateMode.disabled;
    });
  }

  Future<void> _submitComercio() async {
    if (!_formKey3.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // Cuenta en auth-service y solicitud en user-service (ver SessionController.registerMerchant).
      await ref
          .read(sessionControllerProvider.notifier)
          .registerMerchant(
            email: _email.text.trim(),
            password: _password.text,
            acceptedPrivacyPolicy: _acceptedPrivacy, // validado localmente; no va al back
            request: MerchantRequest(
              businessName: _name.text.trim(),
              category: _categoryApiValues[_category]!,
              address: _address.text.trim(),
              // TODO: sustituir por las coordenadas del selector de mapa (Mapbox, RF5). Mientras tanto,
              // centro de Bogota, para que el backend acepte la solicitud.
              latitude: _bogotaLatitude,
              longitude: _bogotaLongitude,
              description: _description.text.trim(),
            ),
          );
      // El router lleva al comercio a su verificación cuando la sesión queda publicada.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_accountType == AccountType.user) {
      return _buildPersona();
    }
    return switch (_step) {
      1 => _buildComercioStep1(),
      2 => _buildComercioStep2(),
      _ => _buildComercioStep3(),
    };
  }

  // ─── PERSONA ────────────────────────────────────────────────────────────────

  Widget _buildPersona() {
    return AuthScaffold(
      title: 'Crea tu cuenta',
      subtitle: 'Regístrate para descubrir y crear planes.',
      child: Form(
        key: _formKey1,
        autovalidateMode: _autovalidateMode,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AccountTypeSelector(
                value: _accountType,
                onChanged: _submitting
                    ? null
                    : (t) => setState(() {
                        _accountType = t;
                        _step = 1;
                      }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('register.name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                validator: AuthValidators.displayName,
                decoration: const InputDecoration(labelText: 'Nombre'),
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
                decoration: InputDecoration(labelText: 'Correo electrónico', errorText: _error?.fieldErrors['email']),
              ),
              const SizedBox(height: 16),
              PasswordField(
                key: const Key('register.password'),
                controller: _password,
                label: 'Contraseña',
                validator: AuthValidators.newPassword,
                errorText: _error?.fieldErrors['password'],
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
                onFieldSubmitted: (_) => _submitPersona(),
              ),
              const SizedBox(height: 16),
              _PrivacyCheckbox(
                key: const Key('register.privacy'),
                value: _acceptedPrivacy,
                enabled: !_submitting,
                onChanged: (v) => setState(() => _acceptedPrivacy = v),
              ),
              if (_error?.message != null) ...[const SizedBox(height: 12), _ErrorBanner(message: _error!.message)],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('register.submit'),
                onPressed: _submitting ? null : _submitPersona,
                child: _submitting ? const Text('Creando cuenta...') : const Text('Crear cuenta'),
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

  // ─── COMERCIO PASO 1 ────────────────────────────────────────────────────────

  Widget _buildComercioStep1() {
    return AuthScaffold(
      title: 'Crea tu cuenta',
      subtitle: 'Regístrate para publicar tus eventos en Festa.',
      child: Form(
        key: _formKey1,
        autovalidateMode: _autovalidateMode,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AccountTypeSelector(
                value: _accountType,
                onChanged: _submitting
                    ? null
                    : (t) => setState(() {
                        _accountType = t;
                        _step = 1;
                      }),
              ),
              const SizedBox(height: 4),
              const _StepIndicator(current: 1, total: 3, label: 'Tu cuenta'),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('register.name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.organizationName],
                textInputAction: TextInputAction.next,
                validator: AuthValidators.displayName,
                decoration: const InputDecoration(labelText: 'Nombre del comercio'),
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
                decoration: const InputDecoration(labelText: 'Correo electrónico'),
              ),
              const SizedBox(height: 16),
              PasswordField(
                key: const Key('register.password'),
                controller: _password,
                label: 'Contraseña',
                validator: AuthValidators.newPassword,
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
                onFieldSubmitted: (_) => _nextStep(),
              ),
              const SizedBox(height: 16),
              _PrivacyCheckbox(
                key: const Key('register.privacy'),
                value: _acceptedPrivacy,
                enabled: !_submitting,
                onChanged: (v) => setState(() => _acceptedPrivacy = v),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('register.next1'),
                onPressed: _submitting ? null : _nextStep,
                child: const Text('Continuar'),
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

  // ─── COMERCIO PASO 2 ────────────────────────────────────────────────────────

  Widget _buildComercioStep2() {
    final categoryError = _category == null && _autovalidateMode != AutovalidateMode.disabled;
    return AuthScaffold(
      title: 'Crear cuenta',
      subtitle: '',
      child: Form(
        key: _formKey2,
        autovalidateMode: _autovalidateMode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BackButton(onPressed: () => setState(() => _step--)),
            const _StepIndicator(current: 2, total: 3, label: 'Datos del negocio'),
            const SizedBox(height: 20),
            const Text('Dirección', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('register.address'),
              controller: _address,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa la dirección del comercio.' : null,
              decoration: const InputDecoration(hintText: 'Escuela Colombiana de Ingeniería, Bogotá'),
            ),
            const SizedBox(height: 8),
            // Placeholder del mapa (se implementa con Mapbox en la historia del mapa)
            Container(
              height: 140,
              decoration: BoxDecoration(color: FestaColors.bgMuted, borderRadius: BorderRadius.circular(12)),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, color: FestaColors.bgBrand, size: 32),
                    SizedBox(height: 4),
                    Text(
                      'Toca el mapa para fijar la ubicación exacta del lugar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: FestaColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Categoría', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final selected = _category == cat;
                return FilterChip(
                  key: Key('register.category.$cat'),
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = cat),
                  selectedColor: FestaColors.bgBrand,
                  labelStyle: TextStyle(
                    color: selected ? FestaColors.textPrimary : null,
                    fontWeight: selected ? FontWeight.w600 : null,
                  ),
                  checkmarkColor: FestaColors.textPrimary,
                );
              }).toList(),
            ),
            if (categoryError) ...[
              const SizedBox(height: 6),
              const Text('Selecciona una categoría.', style: TextStyle(color: FestaColors.error, fontSize: 12)),
            ],
            const SizedBox(height: 28),
            FilledButton(key: const Key('register.next2'), onPressed: _nextStep, child: const Text('Continuar')),
          ],
        ),
      ),
    );
  }

  // ─── COMERCIO PASO 3 ────────────────────────────────────────────────────────

  Widget _buildComercioStep3() {
    return AuthScaffold(
      title: 'Crear cuenta',
      subtitle: '',
      child: Form(
        key: _formKey3,
        autovalidateMode: _autovalidateMode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BackButton(onPressed: () => setState(() => _step--)),
            const _StepIndicator(current: 3, total: 3, label: 'Contacto y verificación'),
            const SizedBox(height: 20),
            TextFormField(
              key: const Key('register.description'),
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Encuéntrate donde el programa muestra proyectos, conferencias y actividades de integración',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 4),
            // Teléfono y NIT/RUT marcados como "Propuesta" en el Figma:
            // el backend (festa-user-service) aún no los soporta. Se muestran pero
            // no se envían hasta que el equipo decida (ver CLAUDE.md § Figma pendientes 3).
            _ProposalBadge(
              child: TextFormField(
                key: const Key('register.phone'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Teléfono de contacto', hintText: '+57 300 000 00 00'),
              ),
            ),
            const SizedBox(height: 16),
            _ProposalBadge(
              child: TextFormField(
                key: const Key('register.nitOrUrl'),
                controller: _nitOrUrl,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submitComercio(),
                decoration: const InputDecoration(labelText: 'NIT/RUT o enlace de tu página', hintText: 'https://'),
              ),
            ),
            const SizedBox(height: 12),
            // Aviso de verificación manual (como en el Figma)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: FestaColors.bgIa, borderRadius: BorderRadius.circular(10)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: FestaColors.accentIa),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Al terminar crearemos tu cuenta y el equipo de Festa revisará tu comercio a mano. Te avisamos el resultado.',
                      style: TextStyle(fontSize: 12, color: FestaColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            if (_error?.message != null) ...[const SizedBox(height: 12), _ErrorBanner(message: _error!.message)],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('register.submit'),
              onPressed: _submitting ? null : _submitComercio,
              child: _submitting ? const Text('Enviando...') : const Text('Crear cuenta y enviar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── WIDGETS REUTILIZABLES ───────────────────────────────────────────────────

/// Selector Persona / Comercio (chips segmentados del Figma).
class _AccountTypeSelector extends StatelessWidget {
  const _AccountTypeSelector({required this.value, required this.onChanged});
  final AccountType value;
  final ValueChanged<AccountType>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AccountType>(
      segments: const [
        ButtonSegment(value: AccountType.user, label: Text('Persona'), icon: Icon(Icons.person_outline)),
        ButtonSegment(value: AccountType.merchant, label: Text('Comercio'), icon: Icon(Icons.storefront_outlined)),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: onChanged == null ? null : (s) => onChanged!(s.single),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return FestaColors.bgBrand;
          return null;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return FestaColors.textPrimary;
          return null;
        }),
      ),
    );
  }
}

/// Indicador de paso "Paso N de 3 · Etiqueta" (como la barra del Figma).
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total, required this.label});
  final int current;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            'Paso $current de $total',
            style: const TextStyle(color: FestaColors.bgBrand, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '· $label',
              style: const TextStyle(color: FestaColors.textSecondary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Flecha de retroceso para los pasos del asistente.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Volver',
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Envuelve un campo con la etiqueta "Propuesta" (campos aún no soportados en el backend).
class _ProposalBadge extends StatelessWidget {
  const _ProposalBadge({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: FestaColors.bgLive,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: FestaColors.bgLive),
          ),
          child: const Text('Propuesta', style: TextStyle(fontSize: 11, color: FestaColors.textPrimary)),
        ),
        child,
      ],
    );
  }
}

/// Checkbox de política de privacidad (Ley 1581 de 2012, SCRUM-126).
class _PrivacyCheckbox extends StatelessWidget {
  const _PrivacyCheckbox({super.key, required this.value, required this.onChanged, required this.enabled});
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FormField<bool>(
      key: key,
      initialValue: value,
      validator: (v) => v == true ? null : _privacyRequired,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            key: const Key('register.privacyCheckbox'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: value,
            onChanged: enabled
                ? (v) {
                    onChanged(v ?? false);
                    field.didChange(v ?? false);
                  }
                : null,
            title: const Text(_privacyText, style: TextStyle(fontSize: 13)),
          ),
          if (field.hasError) Text(field.errorText!, style: const TextStyle(color: FestaColors.error, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Banner de error genérico.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
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
