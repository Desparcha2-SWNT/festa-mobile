import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/merchant/domain/merchant_profile.dart';
import 'package:festa/features/team/application/team_providers.dart';
import 'package:festa/features/team/data/team_merchants_api.dart';
import 'package:festa/features/team/domain/pending_merchant.dart';
import 'package:festa/features/team/presentation/merchant_review_screen.dart';
import 'package:festa/features/team/presentation/submitted_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTeamMerchantsApi extends Mock implements TeamMerchantsApi {}

/// Hora fija de las pruebas: martes 25 de noviembre de 2026, 2:00 p. m.
final _now = DateTime(2026, 11, 25, 14);

PendingMerchant _merchant(String id, String name, {DateTime? submitted, String description = 'Café y postres.'}) =>
    PendingMerchant.fromJson({
      'accountId': id,
      'businessName': name,
      'category': 'GASTRONOMICO',
      'address': 'Escuela Colombiana de Ingeniería, Bogotá',
      'latitude': 4.7827,
      'longitude': -74.0425,
      'description': description,
      'verificationStatus': 'PENDING',
      'suspended': false,
      'createdAt': (submitted ?? _now.subtract(const Duration(hours: 2))).toUtc().toIso8601String(),
    });

void main() {
  late _MockTeamMerchantsApi api;

  setUp(() => api = _MockTeamMerchantsApi());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [teamMerchantsApiProvider.overrideWithValue(api)],
        child: MaterialApp(home: MerchantReviewScreen(now: () => _now)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openRequest(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(Key('team.merchant.$id')));
    await tester.pumpAndSettle();
  }

  testWidgets('Figma 28: lista los pendientes con categoría, cuándo se enviaron y la insignia', (tester) async {
    when(() => api.pending()).thenAnswer(
      (_) async => [
        _merchant('m1', 'Café de la Escuela'),
        _merchant('m2', 'Laboratorio CLAP', submitted: DateTime(2026, 11, 24, 18)),
      ],
    );

    await pump(tester);

    expect(find.text('Revisión de comercios'), findsOneWidget);
    expect(find.text('Pendientes (2)'), findsOneWidget);
    expect(find.text('Gastronómico · Enviado hace 2 h'), findsOneWidget);
    expect(find.text('Gastronómico · Enviado ayer'), findsOneWidget);
    expect(find.text('Pendiente'), findsNWidgets(2));
  });

  testWidgets('Figma 29: la solicitud muestra los datos y el aviso', (tester) async {
    when(() => api.pending()).thenAnswer((_) async => [_merchant('m1', 'Café de la Escuela')]);

    await pump(tester);
    await openRequest(tester, 'm1');

    expect(find.text('Solicitud'), findsOneWidget);
    expect(find.text('Café de la Escuela'), findsOneWidget);
    expect(find.text('Gastronómico'), findsOneWidget);
    expect(find.text('Escuela Colombiana de Ingeniería, Bogotá'), findsOneWidget);
    expect(find.text('Café y postres.'), findsOneWidget);
    expect(find.text('Hace 2 horas · cuenta de comercio'), findsOneWidget);
    expect(find.text('Revisa que el lugar y la descripción sean reales antes de aprobar.'), findsOneWidget);
  });

  testWidgets('sin descripción no muestra ese dato', (tester) async {
    when(() => api.pending()).thenAnswer((_) async => [_merchant('m1', 'Café de la Escuela', description: '  ')]);

    await pump(tester);
    await openRequest(tester, 'm1');

    expect(find.text('Descripción'), findsNothing);
  });

  testWidgets('aprobar pide confirmación, vuelve a la lista y lo saca de ella', (tester) async {
    var calls = 0;
    when(() => api.pending()).thenAnswer((_) async => calls++ == 0 ? [_merchant('m1', 'Café de la Escuela')] : []);
    when(() => api.approve('m1')).thenAnswer((_) async {});

    await pump(tester);
    await openRequest(tester, 'm1');
    await tester.tap(find.byKey(const Key('team.approve')));
    await tester.pumpAndSettle();
    expect(find.text('¿Aprobar a Café de la Escuela?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('team.approve.confirm')));
    await tester.pumpAndSettle();

    verify(() => api.approve('m1')).called(1);
    expect(find.text('Revisión de comercios'), findsOneWidget);
    expect(find.text('Café de la Escuela quedó verificado.'), findsOneWidget);
    expect(find.byKey(const Key('team.merchants.empty')), findsOneWidget);
  });

  testWidgets('cancelar la confirmación no aprueba', (tester) async {
    when(() => api.pending()).thenAnswer((_) async => [_merchant('m1', 'Café de la Escuela')]);

    await pump(tester);
    await openRequest(tester, 'm1');
    await tester.tap(find.byKey(const Key('team.approve')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    verifyNever(() => api.approve(any()));
    expect(find.text('Solicitud'), findsOneWidget);
  });

  testWidgets('rechazar exige un motivo y lo envía', (tester) async {
    var calls = 0;
    when(() => api.pending()).thenAnswer((_) async => calls++ == 0 ? [_merchant('m1', 'Café de la Escuela')] : []);
    when(() => api.reject('m1', any())).thenAnswer((_) async {});

    await pump(tester);
    await openRequest(tester, 'm1');
    await tester.tap(find.byKey(const Key('team.reject')));
    await tester.pumpAndSettle();

    final confirm = find.byKey(const Key('team.reject.confirm'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('team.reject.reason')), '  La dirección no coincide.  ');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    verify(() => api.reject('m1', 'La dirección no coincide.')).called(1);
    expect(find.text('Café de la Escuela fue rechazado. Verá el motivo para corregir.'), findsOneWidget);
  });

  testWidgets('si otra persona del equipo ya lo revisó, avisa y la lista se actualiza', (tester) async {
    var calls = 0;
    when(() => api.pending()).thenAnswer((_) async => calls++ == 0 ? [_merchant('m1', 'Café de la Escuela')] : []);
    when(() => api.approve('m1')).thenThrow(
      const ApiException(code: 'VALIDATION_ERROR', message: 'El comercio ya no está pendiente.', statusCode: 400),
    );

    await pump(tester);
    await openRequest(tester, 'm1');
    await tester.tap(find.byKey(const Key('team.approve')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('team.approve.confirm')));
    await tester.pumpAndSettle();

    expect(find.text('El comercio ya no está pendiente.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('team.merchants.empty')), findsOneWidget);
  });

  testWidgets('sin red avisa y deja la solicitud abierta para reintentar', (tester) async {
    when(() => api.pending()).thenAnswer((_) async => [_merchant('m1', 'Café de la Escuela')]);
    when(() => api.approve('m1'))
        .thenThrow(const ApiException(code: ApiException.networkError, message: 'Sin conexión.'));

    await pump(tester);
    await openRequest(tester, 'm1');
    await tester.tap(find.byKey(const Key('team.approve')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('team.approve.confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión.'), findsOneWidget);
    expect(find.text('Solicitud'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('team.approve'))).onPressed, isNotNull);
    verify(() => api.pending()).called(1);
  });

  testWidgets('sin pendientes lo dice', (tester) async {
    when(() => api.pending()).thenAnswer((_) async => []);

    await pump(tester);

    expect(find.byKey(const Key('team.merchants.empty')), findsOneWidget);
    expect(find.text('Pendientes (0)'), findsOneWidget);
  });

  testWidgets('si falla la carga permite reintentar', (tester) async {
    var calls = 0;
    when(() => api.pending()).thenAnswer((_) async {
      if (calls++ == 0) throw const ApiException(code: 'FORBIDDEN', message: 'No tienes permiso.', statusCode: 403);
      return [_merchant('m1', 'Café de la Escuela')];
    });

    await pump(tester);
    expect(find.text('No tienes permiso.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('team.merchants.retry')));
    await tester.pumpAndSettle();

    expect(find.text('Café de la Escuela'), findsOneWidget);
  });

  group('cuándo se envió', () {
    test('versión corta de la lista (Figma 28)', () {
      expect(submittedShort(_now.subtract(const Duration(seconds: 20)), _now), 'hace un momento');
      expect(submittedShort(_now.subtract(const Duration(minutes: 5)), _now), 'hace 5 min');
      expect(submittedShort(_now.subtract(const Duration(hours: 2)), _now), 'hace 2 h');
      // Anoche a las 11: es «ayer» aunque solo hayan pasado 15 horas.
      expect(submittedShort(DateTime(2026, 11, 24, 23), _now), 'ayer');
      expect(submittedShort(DateTime(2026, 11, 22, 9), _now), 'hace 3 días');
      expect(submittedShort(DateTime(2026, 11, 14, 9), _now), 'el 14 nov');
    });

    test('versión larga de la solicitud (Figma 29)', () {
      expect(submittedLong(_now.subtract(const Duration(hours: 1)), _now), 'Hace 1 hora');
      expect(submittedLong(_now.subtract(const Duration(hours: 2)), _now), 'Hace 2 horas');
      expect(submittedLong(_now.subtract(const Duration(minutes: 1)), _now), 'Hace 1 minuto');
      expect(submittedLong(DateTime(2026, 11, 24, 9), _now), 'Ayer');
      expect(submittedLong(DateTime(2026, 11, 22, 9), _now), 'Hace 3 días');
      expect(submittedLong(DateTime(2026, 11, 14, 9), _now), 'El 14 nov');
    });
  });

  test('el perfil del comercio pendiente se lee igual que el de la cuenta', () {
    final merchant = _merchant('m1', 'Café de la Escuela');
    expect(merchant.profile.status, MerchantStatus.pending);
    expect(merchant.profile.canPublish, isFalse);
  });
}
