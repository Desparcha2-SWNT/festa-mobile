import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/design.dart';
import '../../../app/routes.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../application/profile_providers.dart';
import '../domain/user_profile.dart';

/// Perfil e intereses (Figma «12»): quién eres, qué planes te gustan y cómo recomendarte (RF2).
///
/// Nombre y correo vienen de la cuenta (auth-service) y no se editan aquí: el perfil de user-service
/// solo guarda intereses y preferencias (más bio, foto y teléfono, que el Figma no muestra).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  /// Lo que el usuario está editando. Se llena con lo guardado cuando el perfil termina de cargar.
  Set<Interest>? _interests;
  UserPreferences? _preferences;
  UserProfile? _saved;

  bool _saving = false;
  ApiException? _error;

  bool get _dirty =>
      _saved != null && (!_sameSet(_interests!, _saved!.interests) || _preferences != _saved!.preferences);

  static bool _sameSet(Set<Interest> a, Set<Interest> b) => a.length == b.length && a.containsAll(b);

  void _adopt(UserProfile profile) {
    _saved = profile;
    _interests = {...profile.interests};
    _preferences = profile.preferences;
  }

  Future<void> _save() async {
    if (_saving || !_dirty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await saveProfile(ref, interests: _interests!, preferences: _preferences!);
      _saved = UserProfile(interests: {..._interests!}, preferences: _preferences!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cambios guardados.')));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que volver a iniciar sesión para usar Festa.'),
        actions: [
          TextButton(
            key: const Key('profile.logout.cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('profile.logout.confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await ref.read(sessionControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    // Adopta lo guardado la primera vez que carga (y no pisa lo que el usuario ya editó).
    if (_saved == null && profile.hasValue) _adopt(profile.requireValue);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go(Routes.home)),
        title: const Text('Mi perfil'),
      ),
      body: SafeArea(
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _LoadError(
            message: error is ApiException ? error.message : 'No pudimos cargar tu perfil.',
            onRetry: () => ref.invalidate(profileProvider),
          ),
          data: (_) => _buildForm(context),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final account = ref.watch(sessionControllerProvider).value;
    final interests = _interests!;
    final preferences = _preferences!;

    return ListView(
      padding: const EdgeInsets.all(FestaSpace.xl),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: FestaColors.bgBrandSoft,
              child: Text(_initials(account?.displayName), style: theme.textTheme.titleMedium),
            ),
            const SizedBox(width: FestaSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account?.displayName ?? '', key: const Key('profile.name'), style: theme.textTheme.titleLarge),
                  Text(
                    account?.email ?? '',
                    key: const Key('profile.email'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: FestaColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: FestaSpace.xxl),
        Text('Mis intereses', style: theme.textTheme.titleMedium),
        const SizedBox(height: FestaSpace.xxs),
        Text(
          'Con esto Festi te recomienda planes. Puedes elegir varios.',
          style: theme.textTheme.bodyMedium?.copyWith(color: FestaColors.textSecondary),
        ),
        const SizedBox(height: FestaSpace.sm),
        Wrap(
          spacing: FestaSpace.xs,
          runSpacing: FestaSpace.xs,
          children: [
            for (final interest in Interest.values)
              FilterChip(
                key: Key('profile.interest.${interest.name}'),
                label: Text(interest.label),
                selected: interests.contains(interest),
                onSelected: _saving
                    ? null
                    : (selected) => setState(() {
                        selected ? interests.add(interest) : interests.remove(interest);
                      }),
              ),
          ],
        ),
        const SizedBox(height: FestaSpace.xl),
        Text('Presupuesto por plan', style: theme.textTheme.titleMedium),
        const SizedBox(height: FestaSpace.sm),
        Wrap(
          spacing: FestaSpace.xs,
          runSpacing: FestaSpace.xs,
          children: [
            for (final budget in BudgetRange.values)
              ChoiceChip(
                key: Key('profile.budget.${budget.name}'),
                label: Text(budget.label),
                selected: preferences.budgetRange == budget,
                onSelected: _saving
                    ? null
                    : (_) => setState(() => _preferences = preferences.copyWith(budgetRange: budget)),
              ),
          ],
        ),
        const SizedBox(height: FestaSpace.xl),
        Text('Distancia máxima', style: theme.textTheme.titleMedium),
        const SizedBox(height: FestaSpace.xxs),
        Text(
          'Hasta ${preferences.maxDistanceKm} km de donde estés',
          key: const Key('profile.distance.label'),
          style: theme.textTheme.bodyMedium?.copyWith(color: FestaColors.textSecondary),
        ),
        Slider(
          key: const Key('profile.distance'),
          min: 1,
          max: 30,
          divisions: 29,
          value: preferences.maxDistanceKm.clamp(1, 30).toDouble(),
          label: '${preferences.maxDistanceKm} km',
          onChanged: _saving
              ? null
              : (v) => setState(() => _preferences = preferences.copyWith(maxDistanceKm: v.round())),
        ),
        if (_error != null) ...[
          const SizedBox(height: FestaSpace.sm),
          Text(
            _error!.message,
            key: const Key('profile.error'),
            style: const TextStyle(color: FestaColors.textError),
          ),
        ],
        const SizedBox(height: FestaSpace.lg),
        FilledButton(
          key: const Key('profile.save'),
          onPressed: _saving || !_dirty ? null : _save,
          child: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
        ),
        const SizedBox(height: FestaSpace.sm),
        OutlinedButton(
          key: const Key('profile.logout'),
          onPressed: _saving ? null : _confirmLogout,
          child: const Text('Cerrar sesión'),
        ),
      ],
    );
  }

  static String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FestaSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, key: const Key('profile.loadError'), textAlign: TextAlign.center),
            const SizedBox(height: FestaSpace.md),
            OutlinedButton(key: const Key('profile.retry'), onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
