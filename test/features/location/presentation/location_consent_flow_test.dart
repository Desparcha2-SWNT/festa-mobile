import 'package:festa/app/festa_app.dart';
import 'package:festa/features/auth/application/auth_providers.dart';
import 'package:festa/features/location/application/location_providers.dart';
import 'package:festa/features/location/domain/location_consent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fakes.dart';

void main() {
  late MockConsentsApi consentsApi;
  late InMemoryLocationConsentStore store;
  late FakeDeviceLocation device;

  setUp(() {
    consentsApi = MockConsentsApi();
    store = InMemoryLocationConsentStore();
    device = FakeDeviceLocation();
    when(() => consentsApi.recordLocationConsent(granted: any(named: 'granted'))).thenAnswer((_) async {});
  });

  /// Abre la app con una sesión guardada de [testAccount].
  Future<void> pumpSignedInApp(WidgetTester tester) async {
    final authApi = MockAuthApi();
    when(() => authApi.refresh('refresh-0')).thenAnswer((_) async => testSession());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWithValue(authApi),
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage('refresh-0')),
          locationConsentStoreProvider.overrideWithValue(store),
          consentsApiProvider.overrideWithValue(consentsApi),
          deviceLocationProvider.overrideWithValue(device),
        ],
        child: const FestaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pide el consentimiento antes de leer la ubicación', (tester) async {
    await pumpSignedInApp(tester);

    expect(find.text('Encuentra planes cerca de ti'), findsOneWidget);
    expect(device.calls, 0);
  });

  testWidgets('al permitir entra al inicio con la ubicación del dispositivo', (tester) async {
    await pumpSignedInApp(tester);

    await tester.tap(find.byKey(const Key('locationConsent.allow')));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(device.calls, 1);
    expect(find.textContaining('mostrando cerca de la Escuela'), findsNothing);
  });

  testWidgets('con «Ahora no» entra al inicio y avisa que usa la ubicación de la Escuela', (tester) async {
    await pumpSignedInApp(tester);

    await tester.tap(find.byKey(const Key('locationConsent.decline')));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Ubicación desactivada · mostrando cerca de la Escuela'), findsOneWidget);
    expect(device.calls, 0);
  });

  testWidgets('no vuelve a preguntar si la cuenta ya decidió', (tester) async {
    store.consents[testAccount.id] = const StoredLocationConsent(decision: LocationConsent.declined, synced: true);

    await pumpSignedInApp(tester);

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Encuentra planes cerca de ti'), findsNothing);
  });
}
