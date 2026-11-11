import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/config/app_config.dart';
import '../../location/domain/geo_point.dart';
import 'map_view.dart';

/// Mapa de Mapbox (SCRUM-73). Es la única pieza de la app que conoce el SDK.
class MapboxMapView extends StatefulWidget {
  const MapboxMapView({super.key, required this.config});

  final MapViewConfig config;

  @override
  State<MapboxMapView> createState() => _MapboxMapViewState();
}

class _MapboxMapViewState extends State<MapboxMapView> {
  /// Nivel de barrio: se ven las calles y los lugares alrededor del usuario.
  static const _zoom = 14.0;

  final _viewport = ViewportController();
  MapboxMap? _map;

  @override
  void initState() {
    super.initState();
    widget.config.camera.addListener(_onCameraRequest);
  }

  @override
  void didUpdateWidget(MapboxMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.camera != widget.config.camera) {
      oldWidget.config.camera.removeListener(_onCameraRequest);
      widget.config.camera.addListener(_onCameraRequest);
    }
    if (oldWidget.config.showUserLocation != widget.config.showUserLocation) _updateUserLocation();
  }

  @override
  void dispose() {
    widget.config.camera.removeListener(_onCameraRequest);
    _viewport.dispose();
    super.dispose();
  }

  void _onCameraRequest() {
    final target = widget.config.camera.target;
    if (target != null) _viewport.moveTo(_cameraAt(target), transition: const FlyViewportTransition());
  }

  void _onMapCreated(MapboxMap map) {
    _map = map;
    _updateUserLocation();
    // La barra de escala no está en el diseño y se monta sobre la barra de estado.
    map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
  }

  void _updateUserLocation() {
    _map?.location.updateSettings(
      LocationComponentSettings(
        enabled: widget.config.showUserLocation,
        pulsingEnabled: true,
        pulsingColor: FestaTheme.brand.toARGB32(),
        // En el slot de abajo de los eventos (que van en `top`): en el campus el usuario suele
        // estar sobre un clúster y taparía su número.
        slot: 'middle',
      ),
    );
  }

  static CameraViewportState _cameraAt(GeoPoint point) => CameraViewportState(
    center: Point(coordinates: Position(point.longitude, point.latitude)),
    zoom: _zoom,
  );

  @override
  Widget build(BuildContext context) {
    if (AppConfig.mapboxAccessToken.isEmpty) return const _MissingTokenNotice();
    return MapWidget(
      viewport: _cameraAt(widget.config.initialCenter),
      viewportController: _viewport,
      onMapCreated: _onMapCreated,
    );
  }
}

/// Sin token Mapbox no puede dibujar el mapa; mejor decirlo que mostrar una pantalla en blanco.
class _MissingTokenNotice extends StatelessWidget {
  const _MissingTokenNotice();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('El mapa no está configurado: falta MAPBOX_ACCESS_TOKEN (ver README).', textAlign: TextAlign.center),
    ),
  );
}
