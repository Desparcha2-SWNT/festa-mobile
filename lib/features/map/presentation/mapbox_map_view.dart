import 'dart:convert';

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

  // Los eventos van en una fuente GeoJSON con una capa de círculos (y no como anotaciones) para
  // poder agruparlos en clústeres por zona (SCRUM-77) activando `cluster` en la misma fuente.
  static const _markersSourceId = 'festa-events';
  static const _markersLayerId = 'festa-events-circles';

  final _viewport = ViewportController();
  MapboxMap? _map;

  /// La fuente de marcadores existe solo después de cargar el estilo.
  bool _markersReady = false;

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
    if (!identical(oldWidget.config.markers, widget.config.markers)) _updateMarkers();
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
    map.addInteraction(
      TapInteraction(FeaturesetDescriptor(layerId: _markersLayerId), (feature, _) {
        final id = feature.properties['id'];
        if (id is String) widget.config.onMarkerTap?.call(id);
      }),
      interactionID: 'tap_event_markers',
    );
  }

  /// Cargar un estilo borra las fuentes y capas propias, así que se agregan en cada carga.
  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _map;
    if (map == null) return;
    _markersReady = false;
    await map.addSource(GeoJsonSource(id: _markersSourceId, data: _markersGeoJson()));
    await map.addLayer(
      CircleLayer(
        id: _markersLayerId,
        sourceId: _markersSourceId,
        slot: 'top',
        circleRadius: 9,
        circleColorExpression: ['get', 'color'],
        circleStrokeWidth: 2,
        circleStrokeColor: Colors.white.toARGB32(),
      ),
    );
    _markersReady = true;
    // Los eventos pudieron cambiar mientras se agregaban la fuente y las capas (son asíncronas);
    // esas actualizaciones se ignoraron porque la fuente no estaba lista, así que se sincroniza aquí.
    await _updateMarkers();
  }

  Future<void> _updateMarkers() async {
    final map = _map;
    if (map == null || !_markersReady) return;
    final source = await map.getSource(_markersSourceId);
    await (source as GeoJsonSource).updateGeoJSON(_markersGeoJson());
  }

  String _markersGeoJson() => jsonEncode({
    'type': 'FeatureCollection',
    'features': [
      for (final marker in widget.config.markers)
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [marker.point.longitude, marker.point.latitude],
          },
          'properties': {'id': marker.id, 'color': _hex(marker.color)},
        },
    ],
  });

  static String _hex(Color color) => '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

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
      onStyleLoadedListener: _onStyleLoaded,
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
