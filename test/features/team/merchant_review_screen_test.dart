import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/merchant/domain/merchant_profile.dart';
import 'package:festa/features/team/application/team_providers.dart';
import 'package:festa/features/team/data/team_merchants_api.dart';
import 'package:festa/features/team/domain/pending_merchant.dart';
import 'package:festa/features/team/presentation/merchant_review_screen.dart';
import 'package:festa/features/team/presentation/team_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTeamMerchantsApi extends Mock implements TeamMerchantsApi {}

PendingMerchant _merchant(String id, String name) => PendingMerchant.fromJson({
  'accountId': id,
  'businessName': name,
  'category': 'GASTRONOMICO',
  'address': 'AK 45 #205-59',
  'latitude': 4.7827,
  'longitude': -74.0425,
  'description': 'Café y postres junto al bloque G.',
  'verificationStatus': 'PENDING',
  'suspended': false,
  'createdAt': '2026-11-20T15:30:00Z',
});

void main() {
  late _MockTeamMerchantsApi api;

  setUp(() => api = _MockTeamMerchantsApi());

  Future<void> pump(WidgetTester tester, {Widget home = const MerchantReviewScreen()}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [teamMerchantsApiProvider.overrideWithValue(api)],
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lista los comercios pendientes con su categoría, dirección y descripción', (tester) async {
    when(() => api.pending())
        .thenAnswer((_) async => [_merchant('m1', 'Café La Escuela'), _merchant('m2', 'Gym Norte')]);

    await pump(tester);

    expect(find.text('Café La Escuela'), findsOneWidget);
    expect(find.text('Gym Norte'), findsOneWidget);
    expect(find.text('Gastronómico'), findsNWidgets(2));
    expect(find.text('Café y postres junto al bloque G.'), findsNWidgets(2));
  });

  testWidgets('verificar pide confirmación, aprueba y saca al comercio de la lista', (tester) async {
    var calls = 0;
    when(() => api.pending()).thenAnswer((_) async => calls++ == 0 ? [_merchant('m1', 'Café La Escuela')] : []);
    when(() => api.approve('m1')).thenAnswer((_) async {});

    await pump(tester);
    await tester.tap(find.byKey(const Key('team.approve.m1')));
    await tester.pumpAndSettle();
    expect(find.text('¿Verificar a Café La Escuela?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('team.approve.confirm')));
    await tester.pumpAndSettle();

    verify(() => api.approve('m1')).called(1);
    expect(find.text('Café La Escuela quedó verificado.'), findsOneWidget);
    expect(find.byKey(const Key('team.merchants.empty')), findsOneWidget);
  });

  testWidgets('cancelar la confirmación no aprueba', (tester) async {
    when(() => api.pending()).thenAnswer((_) async => [_merchant('m1', 'Café La Escuela')]);

    await pump(tester);
    await tester.tap(find.byKey(const Key('team.approve.m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    verifyNever(() => api.approve(any()));
  });

  testWidgets('rechazar exige un motivo y lo envía', (tester) async {
    var calls = 0;
    when(() => api.pending()).thenAnswer((_) async => calls++ == 0 ? [_merchant('m1', 'Café La Escuela')] : []);
    when(() => api.reject('m1', any())).thenAnswer((_) async {});

    await pump(tester);
    await tester.tap(find.byKey(const Key('team.reject.m1')));
    await tester.pumpAndSettle();

    final confirm = find.byKey(const Key('team.reject.confirm'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('team.reject.reason')), '  La dirección no coincide.  ');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    verify(() => api.reject('m1', 'La dirección no coincide.')).called(1);
    expect(find.text('Café La Escuela fue rechazado. Verá el motivo para corregir.'), findsOneWidget);
  });

  testWidgets('si otra persona del equipo ya lo revisó, avisa y vuelve a pedir la lista', (tester) async {
    var calls = 0;
    when(() => api.pending()).thenAnswer((_) async => calls++ == 0 ? [_merchant('m1', 'Café La Escuela')] : []);
    when(() => api.approve('m1')).thenThrow(
      const ApiException(code: 'VALIDATION_ERROR', message: 'El comercio ya no está pendiente.', statusCode: 400),
    );

    await pump(tester);
    await tester.tap(find.byKey(const Key('team.approve.m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('team.approve.confirm')));
    await tester.pumpAndSettle();

    expect(find.text('El comercio ya no está pendiente.'), findsOneWidget);
    expect(find.byKey(const Key('team.merchants.empty')), findsOneWidget);
  });

  testWidgets('sin red avisa y deja el comercio para reintentar', (tester) async {
    when(() => api.pending()).thenAnswer((_) async => [_merchant('m1', 'Café La Escuela')]);
    when(() => api.approve('m1'))
        .thenThrow(const ApiException(code: ApiException.networkError, message: 'Sin conexión.'));

    await pump(tester);
    await tester.tap(find.byKey(const Key('team.approve.m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('team.approve.confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión.'), findsOneWidget);
    expect(find.text('Café La Escuela'), findsOneWidget);
    verify(() => api.pending()).called(1);
  });

  testWidgets('si falla la carga permite reintentar', (tester) async {
    var calls = 0;
    when(() => api.pending()).thenAnswer((_) async {
      if (calls++ == 0) throw const ApiException(code: 'FORBIDDEN', message: 'No tienes permiso.', statusCode: 403);
      return [_merchant('m1', 'Café La Escuela')];
    });

    await pump(tester);
    expect(find.text('No tienes permiso.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('team.merchants.retry')));
    await tester.pumpAndSettle();

    expect(find.text('Café La Escuela'), findsOneWidget);
  });

  testWidgets('«Equipo Festa» cuenta los comercios pendientes y abre la revisión', (tester) async {
    when(() => api.pending())
        .thenAnswer((_) async => [_merchant('m1', 'Café La Escuela'), _merchant('m2', 'Gym Norte')]);

    await pump(tester, home: const TeamScreen());
    expect(find.text('2 por revisar'), findsOneWidget);

    await tester.tap(find.byKey(const Key('team.merchants')));
    await tester.pumpAndSettle();

    expect(find.text('Comercios por verificar'), findsOneWidget);
    expect(find.text('Gym Norte'), findsOneWidget);
  });

  test('el perfil del comercio pendiente se lee igual que el de la cuenta', () {
    final merchant = _merchant('m1', 'Café La Escuela');
    expect(merchant.profile.status, MerchantStatus.pending);
    expect(merchant.profile.canPublish, isFalse);
  });
}
