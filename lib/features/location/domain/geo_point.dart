/// Coordenada geográfica en grados decimales (WGS 84), el mismo sistema que usan Mapbox y PostGIS.
class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) => other is GeoPoint && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}
