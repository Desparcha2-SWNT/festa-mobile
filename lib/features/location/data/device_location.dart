import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/geo_point.dart';
import '../domain/user_location.dart';

/// No se pudo obtener la ubicación del dispositivo; [reason] dice por qué.
class LocationUnavailableException implements Exception {
  const LocationUnavailableException(this.reason);

  final LocationFallbackReason reason;

  @override
  String toString() => 'LocationUnavailableException($reason)';
}

/// Acceso a la ubicación del dispositivo. Solo se debe llamar después de que el usuario dio su
/// consentimiento en la app, porque puede mostrar el diálogo de permiso del sistema.
abstract interface class DeviceLocation {
  /// Lanza [LocationUnavailableException] si el permiso se niega, el servicio está apagado o
  /// no se obtiene una posición a tiempo.
  Future<GeoPoint> currentPosition();
}

class GeolocatorDeviceLocation implements DeviceLocation {
  const GeolocatorDeviceLocation();

  static const _timeLimit = Duration(seconds: 10);

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// En Android se usa el LocationManager del sistema y no el de Google Play Services: este
  /// último pide activar «Precisión de la ubicación» de Google en cada consulta y falla si el
  /// usuario no acepta, aunque ya haya dado el permiso de ubicación.
  static LocationSettings get _settings => _isAndroid
      ? AndroidSettings(accuracy: LocationAccuracy.high, timeLimit: _timeLimit, forceLocationManager: true)
      : const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: _timeLimit);

  @override
  Future<GeoPoint> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationUnavailableException(LocationFallbackReason.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw const LocationUnavailableException(LocationFallbackReason.permissionDenied);
    }

    try {
      final position = await Geolocator.getCurrentPosition(locationSettings: _settings);
      return GeoPoint(latitude: position.latitude, longitude: position.longitude);
    } on Exception {
      // Sin posición nueva a tiempo (interiores, sin señal): la última conocida sirve para buscar
      // eventos cercanos. Si tampoco hay, para el usuario es lo mismo: no hay ubicación.
      final last = await Geolocator.getLastKnownPosition(forceAndroidLocationManager: _isAndroid);
      if (last == null) throw const LocationUnavailableException(LocationFallbackReason.unavailable);
      return GeoPoint(latitude: last.latitude, longitude: last.longitude);
    }
  }
}
