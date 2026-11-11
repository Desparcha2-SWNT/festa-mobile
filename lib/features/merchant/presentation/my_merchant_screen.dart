import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../auth/application/session_controller.dart';
import '../application/merchant_controller.dart';

/// SCRUM-59: perfil del comercio verificado. Diseño: Figma «24c · Mi comercio».
class MyMerchantScreen extends ConsumerWidget {
  const MyMerchantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(merchantControllerProvider).value;
    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final draft = profile.draft;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('Mi comercio', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      avatar: Icon(Icons.check, size: 16, color: theme.colorScheme.tertiary),
                      label: const Text('Verificado'),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  _Field('Nombre', draft.businessName),
                  _Field('Categoría', draft.category.label),
                  _Field('Dirección', draft.address),
                  if (draft.description.isNotEmpty) _Field('Descripción', draft.description),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: OutlinedButton(
                key: const Key('myMerchant.edit'),
                onPressed: () => context.push(Routes.merchantForm),
                child: const Text('Editar perfil'),
              ),
            ),
            TextButton(
              onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
