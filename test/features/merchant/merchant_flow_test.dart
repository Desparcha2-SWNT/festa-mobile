import 'dart:async';

import 'package:festa/app/festa_app.dart';
import 'package:festa/features/auth/application/auth_providers.dart';
import 'package:festa/features/auth/application/session_controller.dart';
import 'package:festa/features/auth/domain/account.dart';
import 'package:festa/features/events/application/events_providers.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/location/application/location_providers.dart';
import 'package:festa/features/location/domain/geo_point.dart';
import 'package:festa/features/location/domain/location_consent.dart';
import 'package:festa/features/map/presentation/map_view.dart';
import 'package:festa/features/merchant/application/merchant_controller.dart';
import 'package:festa/features/merchant/application/merchant_providers.dart';
import 'package:festa/features/merchant/domain/merchant_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fakes.dart';

void main() {
  late MockAuthApi authApi;
  late MockMerchantApi merchantApi;
  late List<MapViewConfig> maps;

  setUpAll(() => registerFallbackValue(testMerchantDraft));

  setUp(() {
    authApi = MockAuthApi();
    merchantApi = MockMerchantApi();
    maps = [];
  });

  /// Abre la app con la sesión guardada de [account] (ya decidió sobre su ubicación).
  Future<void> pumpApp(WidgetTester tester, {Account account = testMerchantAccount, bool settle = true}) async {
    when(() => authApi.refresh('refresh-0')).thenAnswer((_) async => testSession('1', account));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWithValue(authApi),
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage('refresh-0')),
          locationConsentStoreProvider.overrideWithValue(
            InMemoryLocationConsentStore()
              ..consents[account.id] = const StoredLocationConsent(decision: LocationConsent.granted, synced: true),
          ),
          deviceLocationProvider.overrideWithValue(FakeDeviceLocation()),
          nearbyEventsProvider.overrideWith((ref) async => <Event>[]),
          myEventsProvider.overrideWith((ref) async => <Event>[]),
          merchantApiProvider.overrideWithValue(merchantApi),
          mapViewBuilderProvider.overrideWithValue((config) {
            maps.add(config);
            return const SizedBox.expand();
          }),
        ],
        child: const FestaApp(),
      ),
    );
    // Sin `settle` solo avanza unos cuadros: la pantalla de carga tiene una animación sin fin.
    settle ? await tester.pumpAndSettle() : await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('merchantForm.next')));
    await tester.pumpAndSettle();
  }

  group('controlador', () {
    ProviderContainer containerFor(Account account) {
      when(() => authApi.refresh('refresh-0')).thenAnswer((_) async => testSession('1', account));
      final container = ProviderContainer(
        overrides: [
          authApiProvider.overrideWithValue(authApi),
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage('refresh-0')),
          merchantApiProvider.overrideWithValue(merchantApi),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('una cuenta de persona no consulta el perfil de comercio', () async {
      final container = containerFor(testAccount);
      await container.read(sessionControllerProvider.future);

      expect(await container.read(merchantControllerProvider.future), isNull);
      verifyNever(() => merchantApi.mine());
    });

    test('el primer envío usa POST y una corrección usa PATCH', () async {
      when(() => merchantApi.mine()).thenAnswer((_) async => null);
      when(() => merchantApi.submit(any())).thenAnswer((_) async => testMerchantProfile(MerchantStatus.pending));
      when(() => merchantApi.update(any())).thenAnswer((_) async => testMerchantProfile(MerchantStatus.pending));
      final container = containerFor(testMerchantAccount);
      await container.read(sessionControllerProvider.future);
      await container.read(merchantControllerProvider.future);
      final controller = container.read(merchantControllerProvider.notifier);

      await controller.save(testMerchantDraft);
      await controller.save(testMerchantDraft);

      verify(() => merchantApi.submit(any())).called(1);
      verify(() => merchantApi.update(any())).called(1);
    });

    test('al cambiar de comercio pide el perfil de la cuenta nueva y no deja el del anterior', () async {
      const otherMerchant = Account(
        id: 'm2',
        email: 'cafe@escuelaing.edu.co',
        displayName: 'Café',
        role: Role.merchant,
      );
      final otherProfile = testMerchantProfile(MerchantStatus.pending);
      when(() => merchantApi.mine()).thenAnswer((_) async => testMerchantProfile(MerchantStatus.verified));
      when(() => authApi.login(email: 'cafe@escuelaing.edu.co', password: 'secreta123'))
          .thenAnswer((_) async => testSession('2', otherMerchant));
      final container = containerFor(testMerchantAccount);
      await container.read(sessionControllerProvider.future);
      expect((await container.read(merchantControllerProvider.future))!.status, MerchantStatus.verified);

      when(() => merchantApi.mine()).thenAnswer((_) async => otherProfile);
      await container
          .read(sessionControllerProvider.notifier)
          .login(email: 'cafe@escuelaing.edu.co', password: 'secreta123');

      expect(await container.read(merchantControllerProvider.future), same(otherProfile));
      verify(() => merchantApi.mine()).called(2);
    });
  });

  group('perfil', () {
    Map<String, dynamic> json({bool? suspended}) => {
      'businessName': 'Café Central',
      'category': 'GASTRONOMICO',
      'address': 'Calle 1 # 2-3',
      'latitude': 4.6,
      'longitude': -74,
      'description': '',
      'verificationStatus': 'VERIFIED',
      'suspended': ?suspended,
    };

    test('lee la suspensión que user-service manda aparte del estado', () {
      final profile = MerchantProfile.fromJson(json(suspended: true));

      expect(profile.status, MerchantStatus.verified);
      expect(profile.suspended, isTrue);
      expect(profile.canPublish, isFalse, reason: 'visibilidad pública = VERIFIED && !suspended');
    });

    test('sin el campo suspended se asume que no está suspendido', () {
      final profile = MerchantProfile.fromJson(json());

      expect(profile.suspended, isFalse);
      expect(profile.canPublish, isTrue);
    });

    test('solo un comercio verificado puede publicar', () {
      expect(testMerchantProfile(MerchantStatus.pending).canPublish, isFalse);
      expect(testMerchantProfile(MerchantStatus.rejected).canPublish, isFalse);
      expect(testMerchantProfile(MerchantStatus.verified).canPublish, isTrue);
    });
  });

  testWidgets('un comercio sin perfil llena el formulario y queda pendiente de verificación', (tester) async {
    when(() => merchantApi.mine()).thenAnswer((_) async => null);
    when(() => merchantApi.submit(any())).thenAnswer((_) async => testMerchantProfile(MerchantStatus.pending));
    await pumpApp(tester);

    expect(find.text('Paso 2 de 3 · Datos del negocio'), findsOneWidget);
    expect(find.text(testMerchantAccount.displayName), findsOneWidget, reason: 'el nombre arranca con el de la cuenta');

    await tester.enterText(find.byKey(const Key('merchantForm.address')), 'Escuela Colombiana de Ingeniería');
    await tapNext(tester);
    expect(find.text('Toca el mapa para fijar la ubicación.'), findsOneWidget);

    const picked = GeoPoint(latitude: 4.783, longitude: -74.042);
    maps.last.onMapTap!(picked);
    await tester.pump();
    expect(maps.last.markers.single.point, picked);
    await tapNext(tester);

    expect(find.text('Paso 3 de 3 · Descripción'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('merchantForm.description')), 'Encuentro semestral.');
    await tapNext(tester);

    final draft = verify(() => merchantApi.submit(captureAny())).captured.single as MerchantDraft;
    expect(draft.address, 'Escuela Colombiana de Ingeniería');
    expect(draft.location, picked);
    expect(draft.category, MerchantCategory.cultural);
    expect(find.text('Estamos revisando tu perfil'), findsOneWidget);
  });

  testWidgets('un comercio rechazado ve el motivo, corrige y reenvía', (tester) async {
    when(() => merchantApi.mine()).thenAnswer(
      (_) async => testMerchantProfile(MerchantStatus.rejected, rejectionReason: 'Falta la dirección del lugar.'),
    );
    when(() => merchantApi.update(any())).thenAnswer((_) async => testMerchantProfile(MerchantStatus.pending));
    await pumpApp(tester);

    expect(find.text('No pudimos verificar tu perfil'), findsOneWidget);
    expect(find.text('Falta la dirección del lugar.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('merchantStatus.fix')));
    await tester.pumpAndSettle();
    expect(find.text('Editar mi comercio'), findsOneWidget);
    expect(find.text(testMerchantDraft.address), findsOneWidget);

    await tapNext(tester);
    await tapNext(tester);

    verify(() => merchantApi.update(any())).called(1);
    verifyNever(() => merchantApi.submit(any()));
    expect(find.text('Estamos revisando tu perfil'), findsOneWidget);
  });

  testWidgets('un comercio verificado entra a sus eventos y ve su perfil en «Mi comercio»', (tester) async {
    when(() => merchantApi.mine()).thenAnswer((_) async => testMerchantProfile(MerchantStatus.verified));
    await pumpApp(tester);
    expect(find.text('Aún no has publicado eventos.'), findsOneWidget);

    await tester.tap(find.text('Mi comercio'));
    await tester.pumpAndSettle();

    expect(find.text('Verificado'), findsOneWidget);
    expect(find.text(testMerchantDraft.address), findsOneWidget);
    expect(find.text('Mi comercio'), findsWidgets);
    expect(find.text('Explorar'), findsNothing);
  });

  testWidgets('un comercio verificado pero suspendido no entra a publicar y ve por qué', (tester) async {
    when(() => merchantApi.mine())
        .thenAnswer((_) async => testMerchantProfile(MerchantStatus.verified, suspended: true));
    await pumpApp(tester);

    expect(find.text('Tu comercio está suspendido'), findsOneWidget);
    expect(find.text('Aún no has publicado eventos.'), findsNothing);
    expect(find.textContaining('ya puedes publicar'), findsNothing);

    // Cuando se levanta la suspensión, al consultar de nuevo entra a sus eventos.
    when(() => merchantApi.mine()).thenAnswer((_) async => testMerchantProfile(MerchantStatus.verified));
    await tester.tap(find.byKey(const Key('merchantStatus.retry')));
    await tester.pumpAndSettle();

    expect(find.text('Aún no has publicado eventos.'), findsOneWidget);
  });

  testWidgets('mientras carga el perfil no confunde un comercio verificado con uno sin perfil', (tester) async {
    // Con red real el perfil llega después de la sesión: no debe mostrarse el formulario mientras tanto.
    final profile = Completer<MerchantProfile?>();
    when(() => merchantApi.mine()).thenAnswer((_) => profile.future);
    await pumpApp(tester, settle: false);

    expect(find.text('Paso 2 de 3 · Datos del negocio'), findsNothing);

    profile.complete(testMerchantProfile(MerchantStatus.verified));
    await tester.pumpAndSettle();

    expect(find.text('Aún no has publicado eventos.'), findsOneWidget);
  });

  testWidgets('una persona no pasa por la verificación de comercio', (tester) async {
    await pumpApp(tester, account: testAccount);

    expect(find.text('Hola, Ana'), findsOneWidget);
    verifyNever(() => merchantApi.mine());
  });
}
