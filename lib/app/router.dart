import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/session_controller.dart';
import '../features/auth/domain/account.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/events/presentation/create_event_screen.dart';
import '../features/events/presentation/edit_event_screen.dart';
import '../features/events/presentation/event_detail_screen.dart';
import '../features/events/presentation/my_events_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/location/application/location_consent_controller.dart';
import '../features/location/presentation/location_consent_screen.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/merchant/application/merchant_controller.dart';
import '../features/merchant/domain/merchant_profile.dart';
import '../features/merchant/presentation/merchant_form_screen.dart';
import '../features/merchant/presentation/merchant_status_screen.dart';
import '../features/merchant/presentation/my_merchant_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'app_shell.dart';
import 'routes.dart';

const _publicRoutes = {Routes.login, Routes.register};

/// Router de la app. Redirige según la sesión, el comercio y el consentimiento de ubicación:
/// - sin sesión solo se puede ver el login y el registro;
/// - una cuenta de comercio no entra a la app hasta que el equipo Festa verifica su perfil (RF3);
/// - con sesión pero sin decidir sobre la ubicación, se pide el consentimiento (RNF5);
/// - con todo resuelto, las pantallas de entrada llevan al inicio de cada rol.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  void notify(Object? _, Object? _) => refresh.value++;
  ref
    ..listen(sessionControllerProvider, notify)
    ..listen(locationConsentControllerProvider, notify)
    ..listen(merchantControllerProvider, notify)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(
      location: state.matchedLocation,
      session: ref.read(sessionControllerProvider),
      locationConsent: ref.read(locationConsentControllerProvider),
      merchant: ref.read(merchantControllerProvider),
    ),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: Routes.locationConsent, builder: (_, _) => const LocationConsentScreen()),
      GoRoute(path: Routes.merchantForm, builder: (_, _) => const MerchantFormScreen()),
      GoRoute(path: Routes.merchantStatus, builder: (_, _) => const MerchantStatusScreen()),
      GoRoute(path: Routes.createEvent, builder: (_, _) => const CreateEventScreen()),
      GoRoute(
        path: Routes.editEventPattern,
        builder: (_, state) => EditEventScreen(eventId: state.pathParameters['id']!),
      ),
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
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.myMerchant, builder: (_, _) => const MyMerchantScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.myEvents, builder: (_, _) => const MyEventsScreen())],
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
  required AsyncValue<Account?> session,
  required AsyncValue<Object?> locationConsent,
  required AsyncValue<MerchantProfile?> merchant,
}) {
  if (session.isLoading && !session.hasValue) return Routes.splash;

  final account = session.value;
  if (account == null) return _publicRoutes.contains(location) ? null : Routes.login;

  if (account.role == Role.merchant) {
    final gate = _merchantGate(location, merchant);
    if (gate != null) return gate == location ? null : gate;
  }

  if (!locationConsent.hasValue) return Routes.splash;
  if (locationConsent.value == null) return Routes.locationConsent;

  const entryRoutes = {..._publicRoutes, Routes.splash, Routes.locationConsent, Routes.merchantStatus};
  if (!entryRoutes.contains(location)) return null;
  return account.role == Role.merchant ? Routes.myEvents : Routes.home;
}

/// A dónde debe ir una cuenta de comercio mientras su perfil no está verificado, o `null` si ya
/// puede usar la app. El formulario siempre está permitido (para corregir o editar el perfil).
String? _merchantGate(String location, AsyncValue<MerchantProfile?> merchant) {
  // Mientras se consulta, el valor puede ser uno viejo (por ejemplo, el `null` de antes de recuperar
  // la sesión): se espera en vez de decidir con él. Las pantallas del comercio muestran su propia carga.
  const merchantScreens = {Routes.merchantStatus, Routes.merchantForm};
  if (merchant.isLoading && !merchantScreens.contains(location)) return Routes.splash;
  // La pantalla de estado muestra el error con un botón para reintentar.
  if (merchant.hasError && !merchant.hasValue) return Routes.merchantStatus;

  final profile = merchant.value;
  if (profile == null) return Routes.merchantForm;
  if (location == Routes.merchantForm) return location;
  if (profile.status == MerchantStatus.verified) return null;
  return Routes.merchantStatus;
}
