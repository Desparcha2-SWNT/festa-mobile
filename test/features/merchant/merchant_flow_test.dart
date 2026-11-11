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
  Future<void> pumpApp(WidgetTester tester, {Account account = testMerchantAccount}) async {
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
          merchantApiProvider.overrideWithValue(merchantApi),
          mapViewBuilderProvider.overrideWithValue((config) {
            maps.add(config);
            return const SizedBox.expand();
          }),
        ],
        child: const FestaApp(),
      ),
    );
    await tester.pumpAndSettle();
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

  testWidgets('un comercio verificado entra a «Mi comercio» con su barra de navegación', (tester) async {
    when(() => merchantApi.mine()).thenAnswer((_) async => testMerchantProfile(MerchantStatus.verified));
    await pumpApp(tester);

    expect(find.text('Verificado'), findsOneWidget);
    expect(find.text(testMerchantDraft.address), findsOneWidget);
    expect(find.text('Mi comercio'), findsWidgets);
    expect(find.text('Explorar'), findsNothing);
  });

  testWidgets('una persona no pasa por la verificación de comercio', (tester) async {
    await pumpApp(tester, account: testAccount);

    expect(find.text('Hola, Ana'), findsOneWidget);
    verifyNever(() => merchantApi.mine());
  });
}
