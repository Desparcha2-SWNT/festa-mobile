import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../app/design/design.dart';
import '../../../app/routes.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/account.dart';
import '../../events/application/events_providers.dart';
import '../../events/domain/event.dart';
import '../../events/presentation/widgets/event_preview_card.dart';
import '../../location/presentation/widgets/location_consent_button.dart';
import '../../location/presentation/widgets/location_fallback_banner.dart';
import '../../team/presentation/merchant_review_screen.dart';
import '../../team/presentation/report_queue_screen.dart';

/// Pestaña «Explorar»: saludo, accesos del equipo Festa y los planes cercanos en lista (los mismos del mapa).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(sessionControllerProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Festa'),
        actions: [
          // Activar o desactivar la ubicación (Ley 1581): lo que promete la pantalla de consentimiento.
          const LocationConsentButton(),
          IconButton(
            key: const Key('home.chat'),
            tooltip: 'Hablar con Festi',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => context.push(Routes.chat),
          ),
          IconButton(
            key: const Key('home.plans'),
            tooltip: 'Mis planes',
            icon: const Icon(Icons.event_note_outlined),
            onPressed: () => context.push(Routes.plans),
          ),
          IconButton(
            key: const Key('home.passes'),
            tooltip: 'Mis entradas',
            icon: const Icon(Icons.qr_code_2_outlined),
            onPressed: () => context.push(Routes.passes),
          ),
          IconButton(
            key: const Key('home.profile'),
            tooltip: 'Mi perfil',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(Routes.profile),
          ),
          IconButton(
            key: const Key('home.logout'),
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(exploreEventsProvider.future),
        child: ListView(
          key: const Key('home.list'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              account == null ? '' : 'Hola, ${account.displayName}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const LocationFallbackBanner(),
            // SCRUM-61: las cuentas del equipo Festa entran a la revisión de comercios (Figma 28).
            if (account?.role == Role.admin) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                key: const Key('home.team'),
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MerchantReviewScreen())),
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Revisión de comercios'),
              ),
              const SizedBox(height: FestaSpace.xs),
              // SCRUM-110: la cola de reportes (RF14) que el equipo revisa a mano.
              FilledButton.tonalIcon(
                key: const Key('home.reports'),
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReportQueueScreen())),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Reportes'),
              ),
            ],
            const SizedBox(height: 24),
            Text('Planes cerca de ti', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const _NearbyEvents(),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que volver a iniciar sesión para usar Festa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (confirmed ?? false) await ref.read(sessionControllerProvider.notifier).logout();
  }
}

/// Los eventos cercanos en lista, con la misma fuente que el mapa (y su caché sin conexión).
class _NearbyEvents extends ConsumerWidget {
  const _NearbyEvents();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final explore = ref.watch(exploreEventsProvider);
    return switch (explore) {
      AsyncData(:final value) when value.events.isEmpty => _EmptyNearby(onAsk: () => context.push(Routes.chat)),
      AsyncData(:final value) => Column(
        key: const Key('home.events'),
        children: [
          for (final Event event in value.events)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: EventPreviewCard(event: event, onTap: () => context.push(Routes.eventDetail(event.id))),
            ),
        ],
      ),
      AsyncError() when !explore.isLoading => Column(
        key: const Key('home.eventsError'),
        children: [
          const Text('No pudimos cargar los planes cercanos.'),
          TextButton(onPressed: () => ref.invalidate(exploreEventsProvider), child: const Text('Reintentar')),
        ],
      ),
      _ => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _EmptyNearby extends StatelessWidget {
  const _EmptyNearby({required this.onAsk});

  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('home.eventsEmpty'),
    children: [
      Text(
        'Todavía no hay planes publicados cerca. Prueba con otro radio en el mapa o pregúntale a Festi.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 8),
      TextButton.icon(onPressed: onAsk, icon: const Icon(Icons.auto_awesome), label: const Text('Hablar con Festi')),
    ],
  );
}
