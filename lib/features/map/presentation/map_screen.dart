import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/design.dart';
import '../../../app/routes.dart';
import '../../events/application/events_providers.dart';
import '../../events/domain/event.dart';
import '../../events/presentation/event_category_color.dart';
import '../../events/presentation/event_filters_sheet.dart';
import '../../events/presentation/widgets/event_preview_card.dart';
import '../../location/application/user_location_provider.dart';
import '../../location/presentation/widgets/location_fallback_banner.dart';
import 'map_view.dart';

/// Mapa de eventos cercanos. Diseño: Figma «8 · Mapa con clústeres».
///
/// - SCRUM-73: centrado en la ubicación del usuario, con botón para recentrar.
/// - SCRUM-75: cada evento cercano es un marcador; al tocarlo aparece su tarjeta y desde ella el detalle.
/// - SCRUM-77: los eventos cercanos entre sí se agrupan en clústeres que se separan al acercar el mapa
///   (lo resuelve `MapboxMapView`).
/// El buscador y los filtros llegan con sus propias historias.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _camera = MapCameraController();

  // Los marcadores se rehacen solo cuando cambia la lista de eventos, no en cada build: la vista
  // actualiza el mapa cada vez que recibe una lista distinta.
  List<Event>? _markersSource;
  List<MapMarker> _markers = const [];

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  List<MapMarker> _markersFor(List<Event> events) {
    if (!identical(events, _markersSource)) {
      _markersSource = events;
      _markers = [for (final e in events) MapMarker(id: e.id, point: e.location, color: e.category.color)];
    }
    return _markers;
  }

  void _onMarkerTap(List<Event> events, String id) {
    final event = events.where((e) => e.id == id).firstOrNull;
    if (event != null) ref.read(selectedEventProvider.notifier).select(event);
  }

  /// Vuelve a pedir la ubicación (el usuario pudo haber activado el GPS o dado el permiso) y
  /// lleva la cámara allí.
  Future<void> _recenter() async {
    ref.invalidate(userLocationProvider);
    final location = await ref.read(userLocationProvider.future);
    _camera.flyTo(location.point);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(selectedEventProvider, (_, event) {
      if (event != null) _camera.flyTo(event.location, closeUp: true);
    });

    final locationState = ref.watch(userLocationProvider);
    final location = locationState.value;
    if (location == null) {
      if (!locationState.hasError) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      // Sin ubicación ni error mostrable, el mapa quedaría cargando para siempre: se ofrece reintentar.
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No pudimos obtener tu ubicación.'),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('map.location.retry'),
                onPressed: () => ref.invalidate(userLocationProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final nearby = ref.watch(exploreEventsProvider);
    final events = nearby.value?.events ?? const <Event>[];
    final offlineSince = nearby.value?.offlineSince;
    final filters = ref.watch(eventFiltersProvider);
    final selected = ref.watch(selectedEventProvider);
    final buildMapView = ref.watch(mapViewBuilderProvider);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: buildMapView(
              MapViewConfig(
                initialCenter: selected?.location ?? location.point,
                showUserLocation: !location.isFallback,
                camera: _camera,
                markers: _markersFor(events),
                onMarkerTap: (id) => _onMarkerTap(events, id),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const LocationFallbackBanner(),
                  if (nearby.hasError && !nearby.isLoading) ...[
                    const SizedBox(height: 8),
                    _EventsLoadError(onRetry: () => ref.invalidate(nearbyEventsProvider)),
                  ] else if (offlineSince != null) ...[
                    const SizedBox(height: 8),
                    _OfflineBanner(
                      savedAt: offlineSince,
                      retrying: nearby.isLoading,
                      onRetry: () => ref.invalidate(nearbyEventsProvider),
                    ),
                  ],
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // SCRUM-79 y 81: los filtros cambian la búsqueda; el distintivo cuenta los activos.
                        Badge(
                          isLabelVisible: filters.isActive,
                          label: Text('${filters.activeCount}'),
                          child: FloatingActionButton.small(
                            heroTag: 'map.filters',
                            key: const Key('map.filters'),
                            tooltip: 'Filtrar eventos',
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            onPressed: () => showEventFiltersSheet(context),
                            child: const Icon(Icons.tune),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'map.recenter',
                          key: const Key('map.recenter'),
                          tooltip: 'Centrar en mi ubicación',
                          backgroundColor: Theme.of(context).colorScheme.surface,
                          onPressed: _recenter,
                          child: const Icon(Icons.near_me_outlined),
                        ),
                      ],
                    ),
                  ),
                  // La tarjeta del evento elegido sube desde abajo; al elegir otro, se cruzan.
                  AnimatedSwitcher(
                    duration: FestaMotion.of(context, FestaMotion.base),
                    switchInCurve: FestaMotion.standard,
                    switchOutCurve: FestaMotion.exit,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(animation),
                        child: child,
                      ),
                    ),
                    child: selected == null
                        ? const SizedBox.shrink()
                        : Padding(
                            key: ValueKey(selected.id),
                            padding: const EdgeInsets.only(top: 8),
                            child: FestaPressable(
                              child: EventPreviewCard(
                                event: selected,
                                onTap: () => context.push(Routes.eventDetail(selected.id)),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsLoadError extends StatelessWidget {
  const _EventsLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          children: [
            Expanded(
              child: Text('No pudimos cargar los eventos.', style: TextStyle(color: colors.onErrorContainer)),
            ),
            TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

/// SCRUM-140 (Figma 4c, «Explorar · Sin conexión»): sin red, el mapa muestra el último listado guardado.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.savedAt, required this.retrying, required this.onRetry});

  final DateTime savedAt;
  final bool retrying;
  final VoidCallback onRetry;

  static const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  /// «20 nov, 3:05 p. m.» en la hora del teléfono.
  static String formatSavedAt(DateTime at) {
    final local = at.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minutes = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'a. m.' : 'p. m.';
    return '${local.day} ${_months[local.month - 1]}, $hour12:$minutes $period';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('map.offline'),
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 20, color: colors.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sin conexión: estos son los eventos que cargaste el ${formatSavedAt(savedAt)}',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
            TextButton(
              key: const Key('map.offline.retry'),
              onPressed: retrying ? null : onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
