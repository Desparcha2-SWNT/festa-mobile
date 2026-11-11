import 'geo_point.dart';

/// Punto que se usa cuando no hay ubicación del dispositivo: la entrada principal de la Escuela
/// Colombiana de Ingeniería, sede del piloto.
const pilotLocation = GeoPoint(latitude: 4.7826, longitude: -74.0425);

/// Por qué la app no está usando la ubicación real del dispositivo.
enum LocationFallbackReason {
  /// El usuario eligió «Ahora no» en la pantalla de consentimiento.
  consentDeclined,

  /// El sistema operativo negó el permiso de ubicación.
  permissionDenied,

  /// El GPS / servicio de ubicación del dispositivo está apagado.
  serviceDisabled,

  /// El dispositivo no logró obtener una posición (sin señal, tiempo agotado).
  unavailable,
}

/// Ubicación que usa la app para buscar eventos cercanos.
///
/// Es la del dispositivo si el usuario dio su consentimiento y el sistema la entregó; si no,
/// es [pilotLocation] y [fallbackReason] dice por qué, para que la UI pueda informarlo.
class UserLocation {
  const UserLocation.device(this.point) : fallbackReason = null;

  const UserLocation.fallback(LocationFallbackReason this.fallbackReason) : point = pilotLocation;

  final GeoPoint point;
  final LocationFallbackReason? fallbackReason;

  bool get isFallback => fallbackReason != null;
}
