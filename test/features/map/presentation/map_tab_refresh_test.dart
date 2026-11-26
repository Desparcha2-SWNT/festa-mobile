// SCRUM-140: el mapa se conserva montado al cambiar de pestaña; al volver debe consultar de nuevo y avisar si no hay red.
import 'package:festa/app/app_shell.dart';
import 'package:festa/app/routes.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/auth/application/session_controller.dart';
import 'package:festa/features/auth/domain/account.dart';
import 'package:festa/features/events/application/events_providers.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/location/application/user_location_provider.dart';
import 'package:festa/features/location/domain/user_location.dart';
import 'package:festa/features/map/presentation/map_screen.dart';
import 'package:festa/features/map/presentation/map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fakes.dart';

class _SignedInUser extends SessionController {
  @override
  Future<Account?> build() async => testAccount;
}

void main() {
  testWidgets('al volver al mapa ya cargado, tras perder la conexión, muestra los últimos eventos y lo avisa', (
    tester,
  ) async {
    var online = true;
    var requests = 0;
    final cache = InMemoryExploreCache();
    final router = GoRouter(
      initialLocation: Routes.map,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => AppShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: Routes.home,
                  builder: (_, _) => const Scaffold(body: Text('Pantalla explorar')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [GoRoute(path: Routes.map, builder: (_, _) => const MapScreen())],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(_SignedInUser.new),
          userLocationProvider.overrideWith((ref) async => const UserLocation.device(testDevicePoint)),
          nearbyEventsProvider.overrideWith((ref) async {
            requests++;
            if (!online) throw const ApiException(code: ApiException.networkError, message: 'Sin red');
            return <Event>[testEvent(id: 'visto')];
          }),
          exploreCacheProvider.overrideWithValue(cache),
          mapViewBuilderProvider.overrideWithValue((_) => const SizedBox.expand()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // Con red, el mapa carga y guarda el listado.
    expect(requests, 1);
    expect(find.byKey(const Key('map.offline')), findsNothing);
    expect(cache.cached!.events.single.id, 'visto');

    // Otra pestaña, modo avión y de vuelta al mapa (que sigue montado).
    await tester.tap(find.text('Explorar'));
    await tester.pumpAndSettle();
    expect(find.text('Pantalla explorar'), findsOneWidget);
    online = false;
    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();

    expect(requests, 2); // volvió a consultar al regresar
    expect(find.byKey(const Key('map.offline')), findsOneWidget);
  });
}
