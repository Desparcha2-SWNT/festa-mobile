import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../events/application/events_providers.dart';
import '../../events/domain/event.dart';
import '../../events/presentation/event_category_color.dart';
import '../../events/presentation/widgets/event_preview_card.dart';
import '../../location/application/user_location_provider.dart';
import '../../location/presentation/widgets/location_fallback_banner.dart';
import 'map_view.dart';

/// Mapa de eventos cercanos. Diseño: Figma «8 · Mapa con clústeres».
///
/// - SCRUM-73: centrado en la ubicación del usuario, con botón para recentrar.
/// - SCRUM-75: cada evento cercano es un marcador; al tocarlo aparece su tarjeta y desde ella el detalle.
/// Los clústeres, el buscador y los filtros llegan con sus propias historias.
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
      if (event != null) _camera.flyTo(event.location);
    });

    final location = ref.watch(userLocationProvider).value;
    if (location == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final nearby = ref.watch(nearbyEventsProvider);
    final events = nearby.value ?? const <Event>[];
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
                  ],
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FloatingActionButton.small(
                      key: const Key('map.recenter'),
                      tooltip: 'Centrar en mi ubicación',
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      onPressed: _recenter,
                      child: const Icon(Icons.near_me_outlined),
                    ),
                  ),
                  if (selected != null) ...[
                    const SizedBox(height: 8),
                    EventPreviewCard(event: selected, onTap: () => context.push(Routes.eventDetail(selected.id))),
                  ],
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
