import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../location/domain/geo_point.dart';
import 'mapbox_map_view.dart';

/// Pide a la vista del mapa que mueva la cámara. Así las pantallas no dependen del SDK de Mapbox
/// y en las pruebas se puede usar un mapa falso.
class MapCameraController extends ChangeNotifier {
  GeoPoint? _target;

  /// Último punto pedido; la vista lo lee cuando se le notifica.
  GeoPoint? get target => _target;

  void flyTo(GeoPoint point) {
    _target = point;
    notifyListeners();
  }
}

/// Lo que la vista del mapa necesita para dibujarse.
@immutable
class MapViewConfig {
  const MapViewConfig({required this.initialCenter, required this.showUserLocation, required this.camera});

  final GeoPoint initialCenter;

  /// Muestra el punto de ubicación del usuario. Solo debe ser `true` si hay consentimiento y permiso.
  final bool showUserLocation;

  final MapCameraController camera;
}

typedef MapViewBuilder = Widget Function(MapViewConfig config);

/// Construye la vista del mapa. En producción es Mapbox; las pruebas lo sobrescriben.
final mapViewBuilderProvider = Provider<MapViewBuilder>(
  (ref) =>
      (config) => MapboxMapView(config: config),
);
