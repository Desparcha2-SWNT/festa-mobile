import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/session_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/home/presentation/home_screen.dart';
import 'routes.dart';

const _publicRoutes = {Routes.login, Routes.register};

/// Router de la app. Redirige según la sesión: sin sesión solo se puede ver el login y el
/// registro; con sesión, esas pantallas llevan al inicio.
final routerProvider = Provider<GoRouter>((ref) {
  final sessionChanged = ValueNotifier<AsyncValue<Object?>>(const AsyncLoading());
  ref
    ..listen(sessionControllerProvider, (_, next) => sessionChanged.value = next, fireImmediately: true)
    ..onDispose(sessionChanged.dispose);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: sessionChanged,
    redirect: (context, state) {
      final session = sessionChanged.value;
      final location = state.matchedLocation;
      if (session.isLoading && !session.hasValue) return Routes.splash;

      final loggedIn = session.value != null;
      if (!loggedIn) return _publicRoutes.contains(location) ? null : Routes.login;
      if (_publicRoutes.contains(location) || location == Routes.splash) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const _SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
