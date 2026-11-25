import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/design.dart';
import '../application/team_providers.dart';
import 'merchant_review_screen.dart';

/// «Equipo Festa»: las tareas de revisión manual del equipo, solo para cuentas con rol `admin`.
/// Por ahora, la verificación de comercios (RF3, SCRUM-61). La cola de reportes (RF14) se agrega aquí.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingMerchantsProvider);
    final count = switch (pending) {
      AsyncData(:final value) => value.isEmpty ? 'Ninguno pendiente' : '${value.length} por revisar',
      AsyncError() => 'No pudimos cargar la lista',
      _ => 'Cargando…',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Equipo Festa')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: FestaSpace.sm),
        children: [
          ListTile(
            key: const Key('team.merchants'),
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Comercios por verificar'),
            subtitle: Text(count, key: const Key('team.merchants.count')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MerchantReviewScreen())),
          ),
        ],
      ),
    );
  }
}
