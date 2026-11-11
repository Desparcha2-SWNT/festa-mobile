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
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: _timeLimit),
      );
      return GeoPoint(latitude: position.latitude, longitude: position.longitude);
    } on Exception {
      // Tiempo agotado, sin señal o error de la plataforma: para el usuario es lo mismo.
      throw const LocationUnavailableException(LocationFallbackReason.unavailable);
    }
  }
}
