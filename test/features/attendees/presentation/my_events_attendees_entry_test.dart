// SCRUM-141: el organizador llega a la lista de asistentes desde «Mis eventos».
import 'package:festa/app/routes.dart';
import 'package:festa/features/auth/application/session_controller.dart';
import 'package:festa/features/auth/domain/account.dart';
import 'package:festa/features/events/application/events_providers.dart';
import 'package:festa/features/events/presentation/my_events_screen.dart';
import 'package:festa/features/location/application/user_location_provider.dart';
import 'package:festa/features/location/domain/user_location.dart';
import 'package:festa/features/map/presentation/map_view.dart';
import 'package:festa/features/merchant/application/merchant_controller.dart';
import 'package:festa/features/merchant/domain/merchant_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fakes.dart';

class _SignedInMerchant extends SessionController {
  @override
  Future<Account?> build() async => testMerchantAccount;
}

class _VerifiedMerchant extends MerchantController {
  @override
  Future<MerchantProfile?> build() async => testMerchantProfile(MerchantStatus.verified);
}

void main() {
  late MockEventsApi api;

  setUp(() => api = MockEventsApi());

  Future<void> pumpMyEvents(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: Routes.myEvents,
      routes: [
        GoRoute(path: Routes.myEvents, builder: (_, _) => const MyEventsScreen()),
        GoRoute(
          path: Routes.eventAttendees,
          builder: (_, state) => Scaffold(body: Text('Asistentes del evento ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(_SignedInMerchant.new),
          merchantControllerProvider.overrideWith(_VerifiedMerchant.new),
          eventsApiProvider.overrideWithValue(api),
          userLocationProvider.overrideWith((ref) async => const UserLocation.device(testDevicePoint)),
          mapViewBuilderProvider.overrideWithValue((_) => const SizedBox.expand()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('un evento publicado tiene «Asistentes» y lleva a la lista de ese evento', (tester) async {
    when(() => api.mine()).thenAnswer((_) async => [testEvent(id: 'e1'), testEvent(id: 'e2', title: 'Otro evento')]);

    await pumpMyEvents(tester);
    expect(find.byKey(const Key('myEvents.attendees.e1')), findsOneWidget);
    expect(find.byKey(const Key('myEvents.attendees.e2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('myEvents.attendees.e2')));
    await tester.pumpAndSettle();

    expect(find.text('Asistentes del evento e2'), findsOneWidget);
  });

  testWidgets('sin eventos no hay accesos a asistentes', (tester) async {
    when(() => api.mine()).thenAnswer((_) async => []);

    await pumpMyEvents(tester);

    expect(find.text('Asistentes'), findsNothing);
  });
}
