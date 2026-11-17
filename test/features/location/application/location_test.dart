import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/auth/application/auth_providers.dart';
import 'package:festa/features/auth/application/session_controller.dart';
import 'package:festa/features/location/application/location_consent_controller.dart';
import 'package:festa/features/location/application/location_providers.dart';
import 'package:festa/features/location/application/user_location_provider.dart';
import 'package:festa/features/location/domain/location_consent.dart';
import 'package:festa/features/location/domain/user_location.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fakes.dart';

void main() {
  late MockAuthApi authApi;
  late MockConsentsApi consentsApi;
  late InMemoryLocationConsentStore store;

  setUp(() {
    authApi = MockAuthApi();
    consentsApi = MockConsentsApi();
    store = InMemoryLocationConsentStore();
    when(() => authApi.refresh('refresh-0')).thenAnswer((_) async => testSession());
    when(() => consentsApi.recordLocationConsent(granted: any(named: 'granted'))).thenAnswer((_) async {});
  });

  /// Contenedor con la sesión de [testAccount] ya restaurada.
  Future<ProviderContainer> signedIn({FakeDeviceLocation? device}) async {
    final container = ProviderContainer(
      overrides: [
        authApiProvider.overrideWithValue(authApi),
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage('refresh-0')),
        locationConsentStoreProvider.overrideWithValue(store),
        consentsApiProvider.overrideWithValue(consentsApi),
        deviceLocationProvider.overrideWithValue(device ?? FakeDeviceLocation()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.future);
    return container;
  }

  void decide(LocationConsent decision, {bool synced = true}) =>
      store.consents[testAccount.id] = StoredLocationConsent(decision: decision, synced: synced);

  group('consentimiento', () {
    test('sin decisión guardada queda pendiente', () async {
      final container = await signedIn();

      expect(await container.read(locationConsentControllerProvider.future), isNull);
    });

    test('al permitir se guarda y se registra en user-service', () async {
      final container = await signedIn();
      await container.read(locationConsentControllerProvider.future);

      await container.read(locationConsentControllerProvider.notifier).grant();

      expect(container.read(locationConsentControllerProvider).value, LocationConsent.granted);
      verify(() => consentsApi.recordLocationConsent(granted: true)).called(1);
      expect(store.consents[testAccount.id]?.synced, isTrue);
    });

    test('al rechazar se registra como no otorgado', () async {
      final container = await signedIn();
      await container.read(locationConsentControllerProvider.future);

      await container.read(locationConsentControllerProvider.notifier).decline();

      verify(() => consentsApi.recordLocationConsent(granted: false)).called(1);
      expect(store.consents[testAccount.id]?.decision, LocationConsent.declined);
    });

    test('sin conexión la decisión se aplica igual y se reintenta al abrir la app', () async {
      when(() => consentsApi.recordLocationConsent(granted: any(named: 'granted')))
          .thenThrow(const ApiException(code: ApiException.networkError, message: 'Sin conexión'));
      final container = await signedIn();
      await container.read(locationConsentControllerProvider.future);

      await container.read(locationConsentControllerProvider.notifier).grant();

      expect(container.read(locationConsentControllerProvider).value, LocationConsent.granted);
      expect(store.consents[testAccount.id]?.synced, isFalse);

      when(() => consentsApi.recordLocationConsent(granted: any(named: 'granted'))).thenAnswer((_) async {});
      final reopened = await signedIn();
      await reopened.read(locationConsentControllerProvider.future);
      await pumpEventQueue();

      expect(store.consents[testAccount.id]?.synced, isTrue);
    });
  });

  group('ubicación del usuario', () {
    test('si rechazó el consentimiento usa la del piloto sin tocar el dispositivo', () async {
      decide(LocationConsent.declined);
      final device = FakeDeviceLocation();
      final container = await signedIn(device: device);

      final location = await container.read(userLocationProvider.future);

      expect(location.point, pilotLocation);
      expect(location.fallbackReason, LocationFallbackReason.consentDeclined);
      expect(device.calls, 0);
    });

    test('con consentimiento usa la ubicación real del dispositivo', () async {
      decide(LocationConsent.granted);
      final container = await signedIn();

      final location = await container.read(userLocationProvider.future);

      expect(location.point, testDevicePoint);
      expect(location.isFallback, isFalse);
    });

    test('si el sistema niega el permiso usa la del piloto e informa el motivo', () async {
      decide(LocationConsent.granted);
      final container = await signedIn(device: FakeDeviceLocation(failure: LocationFallbackReason.permissionDenied));

      final location = await container.read(userLocationProvider.future);

      expect(location.point, pilotLocation);
      expect(location.fallbackReason, LocationFallbackReason.permissionDenied);
    });
  });
}
