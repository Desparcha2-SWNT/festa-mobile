import 'package:festa/features/location/application/user_location_provider.dart';
import 'package:festa/features/location/domain/geo_point.dart';
import 'package:festa/features/location/domain/user_location.dart';
import 'package:festa/features/map/presentation/map_screen.dart';
import 'package:festa/features/map/presentation/map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';

void main() {
  late List<MapViewConfig> builtWith;

  setUp(() => builtWith = []);

  /// Abre el mapa con una vista falsa que registra cómo se construyó. [locations] se entrega en
  /// orden, una por cada vez que se pide la ubicación.
  Future<void> pumpMap(WidgetTester tester, List<UserLocation> locations) async {
    var requests = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userLocationProvider.overrideWith((ref) async => locations[requests++ % locations.length]),
          mapViewBuilderProvider.overrideWithValue((config) {
            builtWith.add(config);
            return const SizedBox.expand(key: Key('fakeMap'));
          }),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('con la ubicación del dispositivo centra el mapa allí y muestra al usuario', (tester) async {
    await pumpMap(tester, [const UserLocation.device(testDevicePoint)]);

    expect(builtWith.last.initialCenter, testDevicePoint);
    expect(builtWith.last.showUserLocation, isTrue);
    expect(find.textContaining('mostrando cerca de la Escuela'), findsNothing);
  });

  testWidgets('sin ubicación centra el mapa en la Escuela, sin punto del usuario, y lo avisa', (tester) async {
    await pumpMap(tester, [const UserLocation.fallback(LocationFallbackReason.permissionDenied)]);

    expect(builtWith.last.initialCenter, pilotLocation);
    expect(builtWith.last.showUserLocation, isFalse);
    expect(find.text('Ubicación desactivada · mostrando cerca de la Escuela'), findsOneWidget);
  });

  testWidgets('recentrar vuelve a pedir la ubicación y mueve la cámara allí', (tester) async {
    const moved = GeoPoint(latitude: 4.70, longitude: -74.05);
    await pumpMap(tester, [const UserLocation.device(testDevicePoint), const UserLocation.device(moved)]);

    await tester.tap(find.byKey(const Key('map.recenter')));
    await tester.pumpAndSettle();

    expect(builtWith.last.camera.target, moved);
  });
}
