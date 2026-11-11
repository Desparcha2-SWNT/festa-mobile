import 'package:festa/app/routes.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/events/application/events_providers.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/events/presentation/event_category_color.dart';
import 'package:festa/features/events/presentation/event_detail_screen.dart';
import 'package:festa/features/location/application/user_location_provider.dart';
import 'package:festa/features/location/domain/geo_point.dart';
import 'package:festa/features/location/domain/user_location.dart';
import 'package:festa/features/map/presentation/map_screen.dart';
import 'package:festa/features/map/presentation/map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fakes.dart';

void main() {
  late List<MapViewConfig> builtWith;

  setUp(() => builtWith = []);

  /// Configuración con la que se construyó la vista del mapa la última vez.
  MapViewConfig map() => builtWith.last;

  /// Abre el mapa con una vista falsa que registra cómo se construyó. [locations] se entrega en
  /// orden, una por cada vez que se pide la ubicación.
  Future<void> pumpMap(
    WidgetTester tester, {
    List<UserLocation> locations = const [UserLocation.device(testDevicePoint)],
    Future<List<Event>> Function()? nearby,
  }) async {
    var requests = 0;
    final router = GoRouter(
      initialLocation: Routes.map,
      routes: [
        GoRoute(path: Routes.map, builder: (_, _) => const MapScreen()),
        GoRoute(
          path: Routes.eventDetailPattern,
          builder: (_, state) => EventDetailScreen(eventId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userLocationProvider.overrideWith((ref) async => locations[requests++ % locations.length]),
          nearbyEventsProvider.overrideWith((ref) => (nearby ?? () async => <Event>[])()),
          eventDetailProvider.overrideWith((ref, id) async => testEvent(id: id)),
          mapViewBuilderProvider.overrideWithValue((config) {
            builtWith.add(config);
            return const SizedBox.expand(key: Key('fakeMap'));
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('ubicación (SCRUM-73)', () {
    testWidgets('con la ubicación del dispositivo centra el mapa allí y muestra al usuario', (tester) async {
      await pumpMap(tester);

      expect(map().initialCenter, testDevicePoint);
      expect(map().showUserLocation, isTrue);
      expect(find.textContaining('mostrando cerca de la Escuela'), findsNothing);
    });

    testWidgets('sin ubicación centra el mapa en la Escuela, sin punto del usuario, y lo avisa', (tester) async {
      await pumpMap(tester, locations: [const UserLocation.fallback(LocationFallbackReason.permissionDenied)]);

      expect(map().initialCenter, pilotLocation);
      expect(map().showUserLocation, isFalse);
      expect(find.text('Ubicación desactivada · mostrando cerca de la Escuela'), findsOneWidget);
    });

    testWidgets('recentrar vuelve a pedir la ubicación y mueve la cámara allí', (tester) async {
      const moved = GeoPoint(latitude: 4.70, longitude: -74.05);
      await pumpMap(tester, locations: [const UserLocation.device(testDevicePoint), const UserLocation.device(moved)]);

      await tester.tap(find.byKey(const Key('map.recenter')));
      await tester.pumpAndSettle();

      expect(map().camera.target, moved);
    });
  });

  group('marcadores (SCRUM-75)', () {
    final feria = testEvent();
    final partido = testEvent(id: 'e2', title: 'Campeonato de fútbol', category: 'deportivo');

    testWidgets('cada evento cercano es un marcador del color de su categoría', (tester) async {
      await pumpMap(tester, nearby: () async => [feria, partido]);

      expect(map().markers.map((m) => m.id), ['e1', 'e2']);
      expect(map().markers.last.point, partido.location);
      expect(map().markers.last.color, EventCategory.deportivo.color);
    });

    testWidgets('al tocar un marcador aparece su tarjeta y la cámara va hacia él', (tester) async {
      await pumpMap(tester, nearby: () async => [feria, partido]);

      map().onMarkerTap!('e2');
      await tester.pumpAndSettle();

      expect(find.text('Campeonato de fútbol'), findsOneWidget);
      expect(map().camera.target, partido.location);
    });

    testWidgets('desde la tarjeta se abre el detalle del evento', (tester) async {
      await pumpMap(tester, nearby: () async => [feria]);

      map().onMarkerTap!('e1');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('map.eventPreview')));
      await tester.pumpAndSettle();

      expect(find.text('Detalle'), findsOneWidget);
      expect(find.text('Sobre el plan'), findsOneWidget);
    });

    testWidgets('si no cargan los eventos lo avisa y deja reintentar', (tester) async {
      var attempts = 0;
      await pumpMap(
        tester,
        nearby: () async {
          if (attempts++ == 0) throw const ApiException(code: ApiException.networkError, message: 'Sin conexión');
          return [feria];
        },
      );
      expect(find.text('No pudimos cargar los eventos.'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('No pudimos cargar los eventos.'), findsNothing);
      expect(map().markers, hasLength(1));
    });
  });
}
