import 'package:festa/app/routes.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/auth/application/session_controller.dart';
import 'package:festa/features/auth/domain/account.dart';
import 'package:festa/features/events/application/events_providers.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/events/domain/event_draft.dart';
import 'package:festa/features/events/presentation/create_event_screen.dart';
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

  setUpAll(() => registerFallbackValue(EventDraft.fromEvent(testEvent())));

  setUp(() {
    api = MockEventsApi();
    when(() => api.mine()).thenAnswer((_) async => []);
  });

  /// Abre «Crear evento» de un comercio verificado en una pantalla alta (el formulario es largo).
  Future<void> pumpCreate(WidgetTester tester, {String initialLocation = Routes.createEvent}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: Routes.myEvents, builder: (_, _) => const MyEventsScreen()),
        GoRoute(path: Routes.createEvent, builder: (_, _) => const CreateEventScreen()),
        GoRoute(
          path: Routes.eventDetailPattern,
          builder: (_, _) => const Scaffold(body: Text('Detalle')),
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

  Future<void> fillRequired(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('eventForm.title')), 'Feria del Autómata');
    await tester.enterText(find.byKey(const Key('eventForm.venueName')), 'Bloque I');
    await tester.enterText(find.byKey(const Key('eventForm.capacity')), '30');
    await tester.enterText(find.byKey(const Key('eventForm.description')), 'Muestra de autómatas.');
  }

  Future<void> tap(WidgetTester tester, Key key) async {
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  testWidgets('el lugar arranca en la dirección del comercio', (tester) async {
    await pumpCreate(tester);

    expect(find.text('Paso 1 de 2 · Datos del evento'), findsOneWidget);
    expect(find.text(testMerchantDraft.address), findsOneWidget);
  });

  testWidgets('no avanza a la vista previa si faltan datos', (tester) async {
    await pumpCreate(tester);

    await tap(tester, const Key('eventForm.submit'));

    expect(find.text('Escribe un nombre de al menos 3 letras.'), findsOneWidget);
    expect(find.text('Escribe el lugar del evento.'), findsOneWidget);
    expect(find.text('Cuéntale a la gente de qué se trata el plan.'), findsOneWidget);
    expect(find.text('Paso 2 de 2 · Revisa y publica'), findsNothing);
  });

  testWidgets('publica como el comercio y el evento aparece en «Mis eventos»', (tester) async {
    final published = testEvent(title: 'Feria del Autómata');
    when(
      () => api.create(
        any(),
        merchantId: any(named: 'merchantId'),
        organizerName: any(named: 'organizerName'),
      ),
    ).thenAnswer((_) async => published);
    await pumpCreate(tester);

    await fillRequired(tester);
    await tap(tester, const Key('eventForm.submit'));
    expect(find.text('Paso 2 de 2 · Revisa y publica'), findsOneWidget);
    expect(find.text('Cupo: 30 personas'), findsOneWidget);

    when(() => api.mine()).thenAnswer((_) async => [published]);
    await tap(tester, const Key('createEvent.publish'));

    final draft =
        verify(
              () => api.create(
                captureAny(),
                merchantId: testMerchantAccount.id,
                organizerName: testMerchantDraft.businessName,
              ),
            ).captured.single
            as EventDraft;
    expect(draft.title, 'Feria del Autómata');
    expect(draft.capacity, 30);
    expect(draft.location, testMerchantDraft.location);
    expect(find.text('¡Evento publicado!'), findsOneWidget);
    expect(find.text('Mis eventos'), findsOneWidget);
    expect(find.text('Feria del Autómata'), findsOneWidget);
  });

  testWidgets('«Volver a editar» conserva lo escrito', (tester) async {
    await pumpCreate(tester);
    await fillRequired(tester);
    await tap(tester, const Key('eventForm.submit'));

    await tester.tap(find.text('Volver a editar'));
    await tester.pumpAndSettle();

    expect(find.text('Paso 1 de 2 · Datos del evento'), findsOneWidget);
    expect(find.text('Feria del Autómata'), findsOneWidget);
  });

  testWidgets('si el servidor lo rechaza, lo explica y no sale de la vista previa', (tester) async {
    when(
      () => api.create(
        any(),
        merchantId: any(named: 'merchantId'),
        organizerName: any(named: 'organizerName'),
      ),
    ).thenThrow(const ApiException(code: 'HTTP_403', message: 'El comercio no está verificado o no es tuyo.'));
    await pumpCreate(tester);
    await fillRequired(tester);
    await tap(tester, const Key('eventForm.submit'));

    await tap(tester, const Key('createEvent.publish'));

    expect(find.text('El comercio no está verificado o no es tuyo.'), findsOneWidget);
    expect(find.text('Paso 2 de 2 · Revisa y publica'), findsOneWidget);
  });

  testWidgets('«Mis eventos» separa los publicados de los cancelados', (tester) async {
    when(() => api.mine()).thenAnswer(
      (_) async => [
        testEvent(title: 'Feria del Autómata'),
        Event.fromJson({...eventJson(id: 'e2', title: 'Concierto suspendido'), 'status': 'cancelled'}),
      ],
    );
    await pumpCreate(tester, initialLocation: Routes.myEvents);

    expect(find.text('Feria del Autómata'), findsOneWidget);
    expect(find.text('Concierto suspendido'), findsNothing);

    await tester.tap(find.text('Cancelados'));
    await tester.pumpAndSettle();

    expect(find.text('Concierto suspendido'), findsOneWidget);
    expect(find.text('Feria del Autómata'), findsNothing);
  });
}
