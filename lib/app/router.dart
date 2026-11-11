import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/session_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/events/presentation/event_detail_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/location/application/location_consent_controller.dart';
import '../features/location/presentation/location_consent_screen.dart';
import '../features/map/presentation/map_screen.dart';
import 'app_shell.dart';
import 'routes.dart';

const _publicRoutes = {Routes.login, Routes.register};

/// Router de la app. Redirige según la sesión y el consentimiento de ubicación:
/// - sin sesión solo se puede ver el login y el registro;
/// - con sesión pero sin decidir sobre la ubicación, se pide el consentimiento (RNF5);
/// - con ambas cosas resueltas, el login, el registro y el consentimiento llevan al inicio.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  void notify(Object? _, Object? _) => refresh.value++;
  ref
    ..listen(sessionControllerProvider, notify)
    ..listen(locationConsentControllerProvider, notify)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(
      location: state.matchedLocation,
      session: ref.read(sessionControllerProvider),
      locationConsent: ref.read(locationConsentControllerProvider),
    ),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const _SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: Routes.locationConsent, builder: (_, _) => const LocationConsentScreen()),
      // Fuera de la barra inferior: el detalle ocupa toda la pantalla, como en el Figma.
      GoRoute(
        path: Routes.eventDetailPattern,
        builder: (_, state) => EventDetailScreen(eventId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.map, builder: (_, _) => const MapScreen())],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

String? _redirect({
  required String location,
  required AsyncValue<Object?> session,
  required AsyncValue<Object?> locationConsent,
}) {
  if (session.isLoading && !session.hasValue) return Routes.splash;

  final loggedIn = session.value != null;
  if (!loggedIn) return _publicRoutes.contains(location) ? null : Routes.login;

  if (!locationConsent.hasValue) return Routes.splash;
  if (locationConsent.value == null) return Routes.locationConsent;

  const entryRoutes = {..._publicRoutes, Routes.splash, Routes.locationConsent};
  return entryRoutes.contains(location) ? Routes.home : null;
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
