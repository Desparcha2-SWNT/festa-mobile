import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../location/application/user_location_provider.dart';
import '../../location/presentation/widgets/location_fallback_banner.dart';
import 'map_view.dart';

/// SCRUM-73: mapa centrado en la ubicación del usuario. Diseño: Figma «8 · Mapa con clústeres»
/// (los marcadores, el buscador y los filtros llegan con sus propias historias).
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _camera = MapCameraController();

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
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
    final location = ref.watch(userLocationProvider).value;
    if (location == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final buildMapView = ref.watch(mapViewBuilderProvider);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: buildMapView(
              MapViewConfig(initialCenter: location.point, showUserLocation: !location.isFallback, camera: _camera),
            ),
          ),
          const SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(padding: EdgeInsets.all(16), child: LocationFallbackBanner()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        key: const Key('map.recenter'),
        tooltip: 'Centrar en mi ubicación',
        backgroundColor: Theme.of(context).colorScheme.surface,
        onPressed: _recenter,
        child: const Icon(Icons.near_me_outlined),
      ),
    );
  }
}
