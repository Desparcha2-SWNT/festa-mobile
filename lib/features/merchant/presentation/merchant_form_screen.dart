import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../../location/domain/geo_point.dart';
import '../../map/presentation/widgets/location_picker_field.dart';
import '../application/merchant_controller.dart';
import '../domain/merchant_profile.dart';

/// SCRUM-59: formulario del perfil de comercio (RF3). Diseño: Figma «3e» y «3f» (pasos 2 y 3 del
/// registro de un comercio; el paso 1 es crear la cuenta).
///
/// Sirve para el primer envío y para corregir un perfil rechazado o editar uno verificado. El
/// teléfono y el NIT del Figma están marcados como «Propuesta» y user-service aún no los recibe.
class MerchantFormScreen extends ConsumerStatefulWidget {
  const MerchantFormScreen({super.key});

  @override
  ConsumerState<MerchantFormScreen> createState() => _MerchantFormScreenState();
}

enum _Step { business, description }

class _MerchantFormScreenState extends ConsumerState<MerchantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _description;
  late MerchantCategory _category;
  GeoPoint? _location;

  /// Si es el primer envío (parte del registro) o una corrección de un perfil existente.
  late final bool _firstSubmission;

  _Step _step = _Step.business;
  bool _submitting = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    final current = ref.read(merchantControllerProvider).value?.draft;
    _firstSubmission = current == null;
    _name = TextEditingController(
      text: current?.businessName ?? ref.read(sessionControllerProvider).value?.displayName,
    );
    _address = TextEditingController(text: current?.address);
    _description = TextEditingController(text: current?.description);
    _category = current?.category ?? MerchantCategory.cultural;
    _location = current?.location;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _description.dispose();
    super.dispose();
  }

  bool _validate() {
    if (_formKey.currentState!.validate()) return true;
    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    return false;
  }

  void _continue() {
    if (!_validate()) return;
    setState(() {
      _step = _Step.description;
      _autovalidateMode = AutovalidateMode.disabled;
    });
  }

  void _back() {
    if (_step == _Step.description) {
      setState(() => _step = _Step.business);
    } else if (context.canPop()) {
      context.pop();
    }
  }

  Future<void> _submit() async {
    if (_submitting || !_validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(merchantControllerProvider.notifier)
          .save(
            MerchantDraft(
              businessName: _name.text.trim(),
              category: _category,
              address: _address.text.trim(),
              location: _location!,
              description: _description.text.trim(),
            ),
          );
      // Se navega según el estado que devolvió el servidor y no con pop: al cambiar el perfil el
      // router se refresca y puede volver a armar la pila de pantallas.
      if (!mounted) return;
      final verified = ref.read(merchantControllerProvider).value?.status == MerchantStatus.verified;
      context.go(verified ? Routes.myMerchant : Routes.merchantStatus);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        // Los datos del negocio están en el primer paso: si el servidor marca uno, se vuelve allí.
        if (e.fieldErrors.keys.any((field) => field != 'description')) _step = _Step.business;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _stepLabel() => switch ((_step, _firstSubmission)) {
    (_Step.business, true) => 'Paso 2 de 3 · Datos del negocio',
    (_Step.description, true) => 'Paso 3 de 3 · Descripción',
    (_Step.business, false) => 'Datos del negocio',
    (_Step.description, false) => 'Descripción',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fieldErrors = _error?.fieldErrors ?? const {};
    final showBack = _step == _Step.description || context.canPop();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: showBack ? BackButton(onPressed: _back) : null,
        title: Text(_firstSubmission ? 'Tu comercio' : 'Editar mi comercio'),
        actions: [
          if (_firstSubmission)
            TextButton(
              onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
              child: const Text('Cerrar sesión'),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidateMode,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(_stepLabel(), style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: 16),
              if (_error != null && fieldErrors.isEmpty) ...[
                Text(_error!.message, style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 16),
              ],
              if (_step == _Step.business) ..._businessFields(fieldErrors) else ..._descriptionFields(fieldErrors),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: FilledButton(
            key: const Key('merchantForm.next'),
            onPressed: _submitting ? null : (_step == _Step.business ? _continue : _submit),
            child: _submitting
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_step == _Step.business ? 'Continuar' : 'Enviar a revisión'),
          ),
        ),
      ),
    );
  }

  List<Widget> _businessFields(Map<String, String> fieldErrors) => [
    TextFormField(
      key: const Key('merchantForm.name'),
      controller: _name,
      textCapitalization: TextCapitalization.words,
      maxLength: 120,
      validator: (value) => (value ?? '').trim().isEmpty ? 'Escribe el nombre del comercio.' : null,
      decoration: InputDecoration(labelText: 'Nombre del comercio', errorText: fieldErrors['businessName']),
    ),
    const SizedBox(height: 8),
    TextFormField(
      key: const Key('merchantForm.address'),
      controller: _address,
      maxLength: 300,
      validator: (value) => (value ?? '').trim().isEmpty ? 'Escribe la dirección del lugar.' : null,
      decoration: InputDecoration(labelText: 'Dirección', errorText: fieldErrors['address']),
    ),
    const SizedBox(height: 8),
    LocationPickerField(initialValue: _location, onChanged: (point) => _location = point),
    const SizedBox(height: 16),
    Text('Categoría', style: Theme.of(context).textTheme.titleSmall),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in MerchantCategory.values)
          ChoiceChip(
            label: Text(category.label),
            selected: _category == category,
            onSelected: (_) => setState(() => _category = category),
          ),
      ],
    ),
  ];

  List<Widget> _descriptionFields(Map<String, String> fieldErrors) => [
    TextFormField(
      key: const Key('merchantForm.description'),
      controller: _description,
      minLines: 3,
      maxLines: 6,
      maxLength: 2000,
      decoration: InputDecoration(
        labelText: 'Descripción (opcional)',
        alignLabelWithHint: true,
        errorText: fieldErrors['description'],
      ),
    ),
    const SizedBox(height: 16),
    _InfoBox(
      _firstSubmission
          ? 'Al enviar, el equipo de Festa revisa tu comercio a mano. Te avisamos el resultado.'
          : 'Si cambias el nombre, la categoría o la dirección, el equipo de Festa volverá a revisar tu comercio.',
    ),
  ];
}

class _InfoBox extends StatelessWidget {
  const _InfoBox(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: FestaTheme.infoSurface, borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 20, color: FestaTheme.ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: const TextStyle(color: FestaTheme.ink)),
            ),
          ],
        ),
      ),
    );
  }
}
