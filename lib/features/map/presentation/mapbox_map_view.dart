import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/config/app_config.dart';
import '../../location/domain/geo_point.dart';
import 'map_view.dart';
import 'markers_geojson.dart';

/// Mapa de Mapbox (SCRUM-73). Es la única pieza de la app que conoce el SDK.
class MapboxMapView extends StatefulWidget {
  const MapboxMapView({super.key, required this.config});

  final MapViewConfig config;

  @override
  State<MapboxMapView> createState() => _MapboxMapViewState();
}

class _MapboxMapViewState extends State<MapboxMapView> {
  /// Nivel de barrio: se ven las calles alrededor del usuario y los eventos agrupados por zona.
  static const _zoom = 13.0;

  // SCRUM-77: los eventos cercanos entre sí se agrupan en un clúster con el número de eventos.
  // Por encima de _clusterMaxZoom siempre se ven sueltos, así que _closeUpZoom, que se usa al
  // elegir un evento, queda por encima para que el evento no quede escondido en su clúster.
  static const _clusterMaxZoom = 14.0;
  static const _closeUpZoom = 15.0;

  /// Radio en píxeles dentro del cual los puntos se agrupan.
  static const _clusterRadius = 50.0;

  static const _markersSourceId = 'festa-events';
  static const _markersLayerId = 'festa-events-circles';
  static const _clustersLayerId = 'festa-events-clusters';
  static const _clusterCountLayerId = 'festa-events-cluster-count';

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
    if (target == null) return;
    final zoom = widget.config.camera.closeUp ? _closeUpZoom : _zoom;
    _viewport.moveTo(_cameraAt(target, zoom: zoom), transition: const FlyViewportTransition());
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
    map.addInteraction(
      TapInteraction(FeaturesetDescriptor(layerId: _clustersLayerId), _expandCluster),
      interactionID: 'tap_event_clusters',
    );
    map.addInteraction(
      TapInteraction.onMap((context) {
        final point = context.point.coordinates;
        widget.config.onMapTap?.call(GeoPoint(latitude: point.lat.toDouble(), longitude: point.lng.toDouble()));
      }),
      interactionID: 'tap_map',
    );
  }

  /// Al tocar un clúster el mapa se acerca justo hasta donde sus eventos se separan.
  Future<void> _expandCluster(FeaturesetFeature cluster, MapContentGestureContext context) async {
    final map = _map;
    if (map == null) return;
    final expansion = await map.getGeoJsonClusterExpansionZoom(_markersSourceId, {
      'type': 'Feature',
      'geometry': cluster.geometry,
      'properties': cluster.properties,
    });
    final zoom = double.tryParse(expansion.value ?? '') ?? _closeUpZoom;
    final center = context.point.coordinates;
    _viewport.moveTo(
      _cameraAt(
        GeoPoint(latitude: center.lat.toDouble(), longitude: center.lng.toDouble()),
        zoom: zoom,
      ),
      transition: const FlyViewportTransition(),
    );
  }

  /// Cargar un estilo borra las fuentes y capas propias, así que se agregan en cada carga.
  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _map;
    if (map == null) return;
    _markersReady = false;
    await map.addSource(
      GeoJsonSource(
        id: _markersSourceId,
        data: markersGeoJson(widget.config.markers),
        cluster: true,
        clusterRadius: _clusterRadius,
        clusterMaxZoom: _clusterMaxZoom,
      ),
    );
    const isCluster = ['has', 'point_count'];
    await map.addLayer(
      CircleLayer(
        id: _markersLayerId,
        sourceId: _markersSourceId,
        slot: 'top',
        filter: const ['!', isCluster],
        circleRadius: 9,
        circleColorExpression: ['get', 'color'],
        circleStrokeWidth: 2,
        circleStrokeColor: Colors.white.toARGB32(),
      ),
    );
    // Círculos de marca (Figma) que crecen con el número de eventos agrupados.
    await map.addLayer(
      CircleLayer(
        id: _clustersLayerId,
        sourceId: _markersSourceId,
        slot: 'top',
        filter: isCluster,
        circleColor: FestaTheme.brand.toARGB32(),
        circleRadiusExpression: const [
          'step',
          ['get', 'point_count'],
          18.0,
          10,
          22.0,
          50,
          26.0,
        ],
        circleStrokeWidth: 2,
        circleStrokeColor: Colors.white.toARGB32(),
      ),
    );
    // El número va en tinta: el blanco sobre el magenta no alcanza el contraste mínimo.
    await map.addLayer(
      SymbolLayer(
        id: _clusterCountLayerId,
        sourceId: _markersSourceId,
        slot: 'top',
        filter: isCluster,
        textFieldExpression: const ['get', 'point_count_abbreviated'],
        textSize: 14,
        textColor: FestaTheme.ink.toARGB32(),
        textAllowOverlap: true,
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
    await (source as GeoJsonSource).updateGeoJSON(markersGeoJson(widget.config.markers));
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

  static CameraViewportState _cameraAt(GeoPoint point, {double zoom = _zoom}) => CameraViewportState(
    center: Point(coordinates: Position(point.longitude, point.latitude)),
    zoom: zoom,
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
