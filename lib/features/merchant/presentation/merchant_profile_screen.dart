import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../application/merchant_profile_controller.dart';
import '../domain/merchant_profile.dart';

class MerchantProfileScreen extends ConsumerWidget {
  const MerchantProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(merchantProfileControllerProvider);
    return profile.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _LoadError(
        message: error is ApiException ? error.message : 'No pudimos cargar tu perfil de comercio.',
        onRetry: () => ref.read(merchantProfileControllerProvider.notifier).refresh(),
      ),
      data: (merchant) => merchant == null
          ? const _MerchantProfileForm()
          : switch (merchant.verificationStatus) {
              'PENDING' => _StatusView(
                profile: merchant,
                icon: Icons.hourglass_top,
                title: 'Perfil pendiente de verificación',
                message: 'El equipo Festa revisará la información. Desliza hacia abajo para consultar el resultado.',
              ),
              'VERIFIED' => _StatusView(
                profile: merchant,
                icon: Icons.verified_outlined,
                title: '¡Tu comercio está aprobado!',
                message: 'Tu perfil ya está verificado y puedes publicar eventos como comercio.',
              ),
              'REJECTED' => _MerchantProfileForm(existingProfile: merchant, rejectionReason: merchant.rejectionReason),
              _ => _LoadError(
                message: 'El estado de verificación recibido no es válido.',
                onRetry: () => ref.read(merchantProfileControllerProvider.notifier).refresh(),
              ),
            },
    );
  }
}

class _MerchantProfileForm extends ConsumerStatefulWidget {
  const _MerchantProfileForm({this.existingProfile, this.rejectionReason});

  final MerchantProfile? existingProfile;
  final String? rejectionReason;

  @override
  ConsumerState<_MerchantProfileForm> createState() => _MerchantProfileFormState();
}

class _MerchantProfileFormState extends ConsumerState<_MerchantProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _businessName;
  late final TextEditingController _address;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _description;
  String? _category;
  bool _submitting = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    final profile = widget.existingProfile;
    _businessName = TextEditingController(text: profile?.businessName);
    _address = TextEditingController(text: profile?.address);
    _latitude = TextEditingController(text: profile?.latitude.toString());
    _longitude = TextEditingController(text: profile?.longitude.toString());
    _description = TextEditingController(text: profile?.description);
    _category = profile?.category;
  }

  @override
  void dispose() {
    _businessName.dispose();
    _address.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    final profile = MerchantProfileInput(
      businessName: _businessName.text.trim(),
      category: _category!,
      address: _address.text.trim(),
      latitude: double.parse(_latitude.text.trim()),
      longitude: double.parse(_longitude.text.trim()),
      description: _description.text.trim(),
    );

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final controller = ref.read(merchantProfileControllerProvider.notifier);
      if (widget.existingProfile == null) {
        await controller.submit(profile);
      } else {
        await controller.updateProfile(profile);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existingProfile == null ? 'Crea el perfil de tu comercio' : 'Corrige tu perfil de comercio',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Completa la información para que el equipo Festa pueda verificar tu negocio.'),
          if (widget.rejectionReason case final reason?) ...[
            const SizedBox(height: 16),
            _Notice(
              icon: Icons.info_outline,
              title: 'Solicitud rechazada',
              message: reason,
              color: Theme.of(context).colorScheme.errorContainer,
            ),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: 16),
            _Notice(
              icon: Icons.error_outline,
              title: 'No pudimos guardar el perfil',
              message: error.message,
              color: Theme.of(context).colorScheme.errorContainer,
            ),
          ],
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('merchant.businessName'),
            controller: _businessName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            maxLength: 120,
            validator: (value) => value == null || value.trim().isEmpty ? 'El nombre es obligatorio.' : null,
            decoration: const InputDecoration(labelText: 'Nombre del negocio'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('merchant.category'),
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: [
              for (final entry in MerchantCategory.values.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            validator: (value) => value == null ? 'Selecciona una categoría.' : null,
            onChanged: _submitting ? null : (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('merchant.address'),
            controller: _address,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            maxLength: 300,
            validator: (value) => value == null || value.trim().isEmpty ? 'La dirección es obligatoria.' : null,
            decoration: const InputDecoration(labelText: 'Dirección'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('merchant.latitude'),
            controller: _latitude,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            textInputAction: TextInputAction.next,
            validator: (value) => _coordinateError(value, minimum: -90, maximum: 90, name: 'latitud'),
            decoration: const InputDecoration(labelText: 'Latitud', hintText: 'Ej. 4.6097'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('merchant.longitude'),
            controller: _longitude,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            textInputAction: TextInputAction.next,
            validator: (value) => _coordinateError(value, minimum: -180, maximum: 180, name: 'longitud'),
            decoration: const InputDecoration(labelText: 'Longitud', hintText: 'Ej. -74.0817'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('merchant.description'),
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 2000,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('merchant.submit'),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.existingProfile == null ? 'Enviar a verificación' : 'Enviar de nuevo'),
          ),
        ],
      ),
    ),
  );

  String? _coordinateError(String? value, {required double minimum, required double maximum, required String name}) {
    final coordinate = double.tryParse(value?.trim() ?? '');
    if (coordinate == null || !coordinate.isFinite) return 'Ingresa una $name válida.';
    if (coordinate < minimum || coordinate > maximum) return 'La $name debe estar entre $minimum y $maximum.';
    return null;
  }
}

class _StatusView extends ConsumerWidget {
  const _StatusView({required this.profile, required this.icon, required this.title, required this.message});

  final MerchantProfile profile;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () => ref.read(merchantProfileControllerProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Icon(icon, size: 48, color: colors.primary),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.businessName, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(MerchantCategory.values[profile.category] ?? profile.category),
                  Text(profile.address),
                  Text('${profile.latitude}, ${profile.longitude}'),
                  if (profile.description.isNotEmpty) ...[const SizedBox(height: 8), Text(profile.description)],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Desliza hacia abajo para actualizar el estado.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
        ],
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.message, required this.color});

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(message),
            ],
          ),
        ),
      ],
    ),
  );
}
