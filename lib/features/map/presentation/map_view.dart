import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../location/domain/geo_point.dart';
import 'mapbox_map_view.dart';

/// Pide a la vista del mapa que mueva la cámara. Así las pantallas no dependen del SDK de Mapbox
/// y en las pruebas se puede usar un mapa falso.
class MapCameraController extends ChangeNotifier {
  GeoPoint? _target;
  bool _closeUp = false;

  /// Último punto pedido; la vista lo lee cuando se le notifica.
  GeoPoint? get target => _target;

  /// Si la cámara debe acercarse lo suficiente para ver un evento suelto (fuera de su clúster).
  bool get closeUp => _closeUp;

  void flyTo(GeoPoint point, {bool closeUp = false}) {
    _target = point;
    _closeUp = closeUp;
    notifyListeners();
  }
}

/// Punto que la vista dibuja sobre el mapa. [id] es lo que devuelve al tocarlo.
@immutable
class MapMarker {
  const MapMarker({required this.id, required this.point, required this.color});

  final String id;
  final GeoPoint point;
  final Color color;
}

/// Lo que la vista del mapa necesita para dibujarse.
@immutable
class MapViewConfig {
  const MapViewConfig({
    required this.initialCenter,
    required this.showUserLocation,
    required this.camera,
    this.markers = const [],
    this.onMarkerTap,
    this.onMapTap,
  });

  final GeoPoint initialCenter;

  /// Muestra el punto de ubicación del usuario. Solo debe ser `true` si hay consentimiento y permiso.
  final bool showUserLocation;

  final MapCameraController camera;
  final List<MapMarker> markers;
  final ValueChanged<String>? onMarkerTap;

  /// Toque en el mapa fuera de los marcadores, con el punto tocado (para elegir una ubicación).
  final ValueChanged<GeoPoint>? onMapTap;
}

typedef MapViewBuilder = Widget Function(MapViewConfig config);

/// Construye la vista del mapa. En producción es Mapbox; las pruebas lo sobrescriben.
final mapViewBuilderProvider = Provider<MapViewBuilder>(
  (ref) =>
      (config) => MapboxMapView(config: config),
);
