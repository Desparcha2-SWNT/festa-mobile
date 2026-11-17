// Ramas de GeolocatorDeviceLocation con un GeolocatorPlatform falso (sin dispositivo).
import 'package:festa/features/location/data/device_location.dart';
import 'package:festa/features/location/domain/geo_point.dart';
import 'package:festa/features/location/domain/user_location.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

/// Plataforma falsa: cada prueba cambia los campos que necesita. Hereda de GeolocatorPlatform
/// porque el paquete exige que las implementaciones lo extiendan.
class _FakeGeolocator extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  /// Un [Position] para devolverlo, o una [Exception] para simular que no llega a tiempo.
  Object? current;
  Position? lastKnown;

  int permissionRequests = 0;
  LocationSettings? lastSettings;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    lastSettings = locationSettings;
    final value = current;
    if (value is Exception) throw value;
    return value! as Position;
  }

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async => lastKnown;
}

Position _position({double lat = 4.6, double lng = -74.0}) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime.utc(2026, 11, 17),
  accuracy: 5,
  altitude: 2600,
  altitudeAccuracy: 1,
  heading: 0,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
);

void main() {
  late _FakeGeolocator platform;

  setUp(() {
    platform = _FakeGeolocator();
    GeolocatorPlatform.instance = platform;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  const location = GeolocatorDeviceLocation();

  test('con el servicio de ubicación apagado falla con serviceDisabled sin pedir posición', () async {
    platform.serviceEnabled = false;

    await expectLater(
      location.currentPosition(),
      throwsA(isA<LocationUnavailableException>().having((e) => e.reason, 'reason', LocationFallbackReason.serviceDisabled)),
    );
    expect(platform.lastSettings, isNull);
  });

  test('si el permiso está denegado y no se concede al pedirlo, falla con permissionDenied', () async {
    platform.permission = LocationPermission.denied;

    await expectLater(
      location.currentPosition(),
      throwsA(isA<LocationUnavailableException>().having((e) => e.reason, 'reason', LocationFallbackReason.permissionDenied)),
    );
    expect(platform.permissionRequests, 1);
  });

  test('si el permiso está denegado para siempre no vuelve a pedirlo y falla con permissionDenied', () async {
    platform.permission = LocationPermission.deniedForever;

    await expectLater(
      location.currentPosition(),
      throwsA(isA<LocationUnavailableException>().having((e) => e.reason, 'reason', LocationFallbackReason.permissionDenied)),
    );
    expect(platform.permissionRequests, 0);
  });

  test('con permiso y posición nueva devuelve esa posición', () async {
    platform.current = _position(lat: 4.7829, lng: -74.0421);

    final point = await location.currentPosition();

    expect(point, const GeoPoint(latitude: 4.7829, longitude: -74.0421));
  });

  test('en Android pide el LocationManager del sistema, no Google Play Services', () async {
    platform.current = _position();

    await location.currentPosition();

    final settings = platform.lastSettings;
    expect(settings, isA<AndroidSettings>());
    expect((settings! as AndroidSettings).forceLocationManager, isTrue);
  });

  test('si no llega una posición nueva a tiempo usa la última conocida', () async {
    platform.current = Exception('sin señal');
    platform.lastKnown = _position(lat: 4.65, lng: -74.1);

    final point = await location.currentPosition();

    expect(point, const GeoPoint(latitude: 4.65, longitude: -74.1));
  });

  test('si no hay posición nueva ni última conocida falla con unavailable', () async {
    platform.current = Exception('sin señal');
    platform.lastKnown = null;

    await expectLater(
      location.currentPosition(),
      throwsA(isA<LocationUnavailableException>().having((e) => e.reason, 'reason', LocationFallbackReason.unavailable)),
    );
  });
}
