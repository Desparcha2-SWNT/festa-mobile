import 'package:festa/app/routes.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/auth/application/session_controller.dart';
import 'package:festa/features/auth/domain/account.dart';
import 'package:festa/features/events/application/events_providers.dart';
import 'package:festa/features/events/data/description_api.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/events/domain/event_draft.dart';
import 'package:festa/features/events/presentation/create_event_screen.dart';
import 'package:festa/features/events/presentation/widgets/ai_description_assistant.dart';
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

class _MockDescriptionApi extends Mock implements DescriptionApi {}

class _SignedInMerchant extends SessionController {
  @override
  Future<Account?> build() async => testMerchantAccount;
}

class _VerifiedMerchant extends MerchantController {
  @override
  Future<MerchantProfile?> build() async => testMerchantProfile(MerchantStatus.verified);
}

void main() {
  late MockEventsApi eventsApi;
  late _MockDescriptionApi descriptions;

  setUpAll(() {
    registerFallbackValue(EventDraft.fromEvent(testEvent()));
    registerFallbackValue(EventCategory.cultural);
  });

  setUp(() {
    eventsApi = MockEventsApi();
    descriptions = _MockDescriptionApi();
    when(() => eventsApi.mine()).thenAnswer((_) async => []);
  });

  Future<void> pumpCreate(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: Routes.createEvent,
      routes: [GoRoute(path: Routes.createEvent, builder: (_, _) => const CreateEventScreen())],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(_SignedInMerchant.new),
          merchantControllerProvider.overrideWith(_VerifiedMerchant.new),
          eventsApiProvider.overrideWithValue(eventsApi),
          descriptionApiProvider.overrideWithValue(descriptions),
          userLocationProvider.overrideWith((ref) async => const UserLocation.device(testDevicePoint)),
          mapViewBuilderProvider.overrideWithValue((_) => const SizedBox.expand()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillNameAndVenue(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('eventForm.title')), 'Feria del Autómata');
    await tester.enterText(find.byKey(const Key('eventForm.venueName')), 'Bloque I');
  }

  Future<void> generate(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('eventForm.aiGenerate')));
    await tester.tap(find.byKey(const Key('eventForm.aiGenerate')));
    await tester.pumpAndSettle();
  }

  String description(WidgetTester tester) =>
      tester.widget<TextFormField>(find.byKey(const Key('eventForm.description'))).controller!.text;

  void stubGenerate(String text) => when(
    () => descriptions.generate(
      name: any(named: 'name'),
      location: any(named: 'location'),
      category: any(named: 'category'),
      startsAt: any(named: 'startsAt'),
      notes: any(named: 'notes'),
      merchantId: any(named: 'merchantId'),
    ),
  ).thenAnswer((_) async => text);

  testWidgets('«Generar con IA» pone el texto en la descripción, editable, con el aviso de IA', (tester) async {
    stubGenerate('Una tarde de autómatas para curiosos.');
    await pumpCreate(tester);
    await fillNameAndVenue(tester);
    expect(find.byKey(const Key('eventForm.aiNotice')), findsNothing);

    await generate(tester);

    expect(description(tester), 'Una tarde de autómatas para curiosos.');
    expect(find.byKey(const Key('eventForm.aiNotice')), findsOneWidget);
    expect(find.text('Generar otra versión con IA'), findsOneWidget);
    // La persona puede editarlo antes de publicar.
    await tester.enterText(find.byKey(const Key('eventForm.description')), 'Una tarde de autómatas, ajustada.');
    expect(description(tester), 'Una tarde de autómatas, ajustada.');
  });

  testWidgets('manda a la IA el nombre, el lugar, la categoría y el comercio de la cuenta', (tester) async {
    stubGenerate('Texto.');
    await pumpCreate(tester);
    await fillNameAndVenue(tester);

    await generate(tester);

    verify(
      () => descriptions.generate(
        name: 'Feria del Autómata',
        location: 'Bloque I',
        category: any(named: 'category'),
        startsAt: any(named: 'startsAt'),
        notes: '', // la descripción está vacía: nada que tener en cuenta
        merchantId: testMerchantAccount.id,
      ),
    ).called(1);
  });

  testWidgets('lo que la persona ya escribió se manda como notas; el texto de la IA no', (tester) async {
    stubGenerate('Versión de la IA.');
    await pumpCreate(tester);
    await fillNameAndVenue(tester);
    await tester.enterText(find.byKey(const Key('eventForm.description')), 'Habrá música en vivo');

    await generate(tester);
    await generate(tester);

    verify(
      () => descriptions.generate(
        name: any(named: 'name'),
        location: any(named: 'location'),
        category: any(named: 'category'),
        startsAt: any(named: 'startsAt'),
        notes: 'Habrá música en vivo',
        merchantId: any(named: 'merchantId'),
      ),
    ).called(1);
    verify(
      () => descriptions.generate(
        name: any(named: 'name'),
        location: any(named: 'location'),
        category: any(named: 'category'),
        startsAt: any(named: 'startsAt'),
        notes: null,
        merchantId: any(named: 'merchantId'),
      ),
    ).called(1);
  });

  testWidgets('sin nombre y lugar no llama a la IA y pide completarlos', (tester) async {
    await pumpCreate(tester);

    await generate(tester);

    expect(find.byKey(const Key('eventForm.aiError')), findsOneWidget);
    expect(find.text(r'Escribe el nombre y el lugar del evento para que la IA pueda redactarlo.'), findsOneWidget);
    verifyNever(
      () => descriptions.generate(
        name: any(named: 'name'),
        location: any(named: 'location'),
        category: any(named: 'category'),
        startsAt: any(named: 'startsAt'),
        notes: any(named: 'notes'),
        merchantId: any(named: 'merchantId'),
      ),
    );
  });

  testWidgets('un 429 muestra «vas muy rápido» y conserva lo escrito', (tester) async {
    when(
      () => descriptions.generate(
        name: any(named: 'name'),
        location: any(named: 'location'),
        category: any(named: 'category'),
        startsAt: any(named: 'startsAt'),
        notes: any(named: 'notes'),
        merchantId: any(named: 'merchantId'),
      ),
    ).thenThrow(const ApiException(code: ApiException.tooManyRequests, message: 'x', statusCode: 429));
    await pumpCreate(tester);
    await fillNameAndVenue(tester);
    await tester.enterText(find.byKey(const Key('eventForm.description')), 'Mi texto');

    await generate(tester);

    expect(find.text('Vas muy rápido. Espera un momento e intenta de nuevo.'), findsOneWidget);
    expect(description(tester), 'Mi texto');
    expect(find.byKey(const Key('eventForm.aiNotice')), findsNothing);
  });

  testWidgets('al publicar, el evento se manda marcado como generado con IA', (tester) async {
    stubGenerate('Texto de la IA.');
    when(
      () => eventsApi.create(
        any(),
        merchantId: any(named: 'merchantId'),
        organizerName: any(named: 'organizerName'),
      ),
    ).thenAnswer((_) async => testEvent());
    await pumpCreate(tester);
    await fillNameAndVenue(tester);
    await generate(tester);
    await tester.tap(find.byKey(const Key('eventForm.submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('createEvent.publish')));
    await tester.pumpAndSettle();

    final draft =
        verify(
              () => eventsApi.create(
                captureAny(),
                merchantId: any(named: 'merchantId'),
                organizerName: any(named: 'organizerName'),
              ),
            ).captured.single
            as EventDraft;
    expect(draft.descriptionAiGenerated, isTrue);
    expect(draft.description, 'Texto de la IA.');
    expect(draft.toCreateJson(merchantId: 'm', organizerName: 'n')['descriptionAiGenerated'], isTrue);
  });

  testWidgets('una descripción escrita a mano no se marca como generada con IA', (tester) async {
    when(
      () => eventsApi.create(
        any(),
        merchantId: any(named: 'merchantId'),
        organizerName: any(named: 'organizerName'),
      ),
    ).thenAnswer((_) async => testEvent());
    await pumpCreate(tester);
    await fillNameAndVenue(tester);
    await tester.enterText(find.byKey(const Key('eventForm.description')), 'Escrito por mí.');
    await tester.tap(find.byKey(const Key('eventForm.submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('createEvent.publish')));
    await tester.pumpAndSettle();

    final draft =
        verify(
              () => eventsApi.create(
                captureAny(),
                merchantId: any(named: 'merchantId'),
                organizerName: any(named: 'organizerName'),
              ),
            ).captured.single
            as EventDraft;
    expect(draft.descriptionAiGenerated, isFalse);
  });
}
