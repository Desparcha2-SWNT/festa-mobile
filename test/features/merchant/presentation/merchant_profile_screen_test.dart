import 'package:festa/features/merchant/application/merchant_profile_controller.dart';
import 'package:festa/features/merchant/data/merchant_api.dart';
import 'package:festa/features/merchant/domain/merchant_profile.dart';
import 'package:festa/features/merchant/presentation/merchant_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMerchantApi extends Mock implements MerchantApi {}

class FakeMerchantProfileInput extends Fake implements MerchantProfileInput {}

void main() {
  late MockMerchantApi api;

  setUpAll(() => registerFallbackValue(FakeMerchantProfileInput()));

  setUp(() {
    api = MockMerchantApi();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [merchantApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: Scaffold(body: MerchantProfileScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('crea el perfil del comercio y muestra estado pendiente', (tester) async {
    when(() => api.getMyProfile()).thenAnswer((_) async => null);
    when(() => api.submitProfile(any())).thenAnswer((invocation) async {
      final submitted = invocation.positionalArguments.single as MerchantProfileInput;
      return _profile(
        status: 'PENDING',
        businessName: submitted.businessName,
        category: submitted.category,
        address: submitted.address,
        latitude: submitted.latitude,
        longitude: submitted.longitude,
        description: submitted.description,
      );
    });

    await pumpScreen(tester);
    await tester.enterText(find.byKey(const Key('merchant.businessName')), 'Café Central');
    await tester.tap(find.byKey(const Key('merchant.category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gastronómico').last);
    await tester.enterText(find.byKey(const Key('merchant.address')), 'Calle 1 # 2-3');
    await tester.enterText(find.byKey(const Key('merchant.latitude')), '4.6');
    await tester.enterText(find.byKey(const Key('merchant.longitude')), '-74.0');
    await tester.ensureVisible(find.byKey(const Key('merchant.submit')));
    await tester.tap(find.byKey(const Key('merchant.submit')));
    await tester.pumpAndSettle();

    final request = verify(() => api.submitProfile(captureAny())).captured.single as MerchantProfileInput;
    expect(request.businessName, 'Café Central');
    expect(request.category, 'GASTRONOMICO');
    expect(request.address, 'Calle 1 # 2-3');
    expect(request.latitude, 4.6);
    expect(request.longitude, -74);
    expect(find.text('Perfil pendiente de verificación'), findsOneWidget);
    expect(find.text('Café Central'), findsOneWidget);
  });

  testWidgets('no envía el perfil si las coordenadas están fuera de rango', (tester) async {
    when(() => api.getMyProfile()).thenAnswer((_) async => null);
    await pumpScreen(tester);

    await tester.enterText(find.byKey(const Key('merchant.businessName')), 'Café Central');
    await tester.tap(find.byKey(const Key('merchant.category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gastronómico').last);
    await tester.enterText(find.byKey(const Key('merchant.address')), 'Calle 1 # 2-3');
    await tester.enterText(find.byKey(const Key('merchant.latitude')), '91');
    await tester.enterText(find.byKey(const Key('merchant.longitude')), '-74');
    await tester.ensureVisible(find.byKey(const Key('merchant.submit')));
    await tester.tap(find.byKey(const Key('merchant.submit')));
    await tester.pumpAndSettle();

    expect(find.text('La latitud debe estar entre -90.0 y 90.0.'), findsOneWidget);
    verifyNever(() => api.submitProfile(any()));
  });

  testWidgets('un perfil rechazado muestra el motivo y permite reenviar correcciones', (tester) async {
    when(() => api.getMyProfile())
        .thenAnswer((_) async => _profile(status: 'REJECTED', rejectionReason: 'No se pudo validar la dirección'));
    when(() => api.updateProfile(any())).thenAnswer((_) async => _profile(status: 'PENDING', rejectionReason: null));

    await pumpScreen(tester);
    expect(find.text('No se pudo validar la dirección'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('merchant.submit')));
    await tester.tap(find.byKey(const Key('merchant.submit')));
    await tester.pumpAndSettle();

    verify(() => api.updateProfile(any())).called(1);
    expect(find.text('Perfil pendiente de verificación'), findsOneWidget);
  });

  testWidgets('muestra la ficha de un comercio aprobado', (tester) async {
    when(() => api.getMyProfile()).thenAnswer((_) async => _profile(status: 'VERIFIED'));

    await pumpScreen(tester);

    expect(find.text('¡Tu comercio está aprobado!'), findsOneWidget);
    expect(find.text('Tu perfil ya está verificado y puedes publicar eventos como comercio.'), findsOneWidget);
  });
}

MerchantProfile _profile({
  String status = 'PENDING',
  String businessName = 'Café Central',
  String category = 'GASTRONOMICO',
  String address = 'Calle 1 # 2-3',
  double latitude = 4.6,
  double longitude = -74,
  String description = 'Café de especialidad',
  String? rejectionReason,
}) => MerchantProfile(
  accountId: 'account-1',
  businessName: businessName,
  category: category,
  address: address,
  latitude: latitude,
  longitude: longitude,
  description: description,
  verificationStatus: status,
  rejectionReason: rejectionReason,
);
