import 'package:festa/features/location/application/location_consent_controller.dart';
import 'package:festa/features/location/domain/location_consent.dart';
import 'package:festa/features/location/presentation/widgets/location_consent_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Controlador falso: registra las decisiones que toma el botón sin tocar la base ni el servidor.
class _FakeConsent extends LocationConsentController {
  _FakeConsent(this._initial);

  final LocationConsent? _initial;
  final List<String> calls = [];

  @override
  Future<LocationConsent?> build() async => _initial;

  @override
  Future<void> grant() async {
    calls.add('grant');
    state = const AsyncData(LocationConsent.granted);
  }

  @override
  Future<void> decline() async {
    calls.add('decline');
    state = const AsyncData(LocationConsent.declined);
  }
}

void main() {
  Future<_FakeConsent> pump(WidgetTester tester, LocationConsent initial) async {
    final fake = _FakeConsent(initial);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [locationConsentControllerProvider.overrideWith(() => fake)],
        child: const MaterialApp(
          home: Scaffold(body: Center(child: LocationConsentButton())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('con la ubicación rechazada ofrece activarla y la activa', (tester) async {
    final fake = await pump(tester, LocationConsent.declined);

    expect(find.byKey(const Key('home.location.revoke')), findsNothing);
    await tester.tap(find.byKey(const Key('home.location.grant')));
    await tester.pumpAndSettle();

    expect(fake.calls, ['grant']);
    expect(find.byKey(const Key('home.location.revoke')), findsOneWidget);
  });

  testWidgets('con la ubicación concedida pide confirmación y la desactiva', (tester) async {
    final fake = await pump(tester, LocationConsent.granted);

    await tester.tap(find.byKey(const Key('home.location.revoke')));
    await tester.pumpAndSettle();
    expect(find.text('¿Desactivar la ubicación?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['decline']);
    expect(find.byKey(const Key('home.location.grant')), findsOneWidget);
  });
}
