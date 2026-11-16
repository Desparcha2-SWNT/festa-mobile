import 'package:festa/app/festa_app.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/auth/application/auth_providers.dart';
import 'package:festa/features/auth/domain/account.dart';
import 'package:festa/features/merchant/application/merchant_providers.dart';
import 'package:festa/features/merchant/data/merchant_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fakes.dart';

void main() {
  late MockAuthApi api;
  late MockMerchantApi merchantApi;
  late InMemoryTokenStorage storage;

  setUpAll(() {
    registerFallbackValue(AccountType.user);
    registerFallbackValue(
      const MerchantRequest(businessName: '', category: '', address: '', latitude: 0, longitude: 0),
    );
  });

  setUp(() {
    api = MockAuthApi();
    merchantApi = MockMerchantApi();
    storage = InMemoryTokenStorage();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWithValue(api),
          merchantApiProvider.overrideWithValue(merchantApi),
          tokenStorageProvider.overrideWithValue(storage),
        ],
        child: const FestaApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  void stubLogin(Future<Never> Function() failure) => when(
    () => api.login(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) => failure());

  testWidgets('sin sesión guardada abre el login', (tester) async {
    await pumpApp(tester);

    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('con sesión guardada entra directo al inicio', (tester) async {
    storage.refreshToken = 'refresh-0';
    when(() => api.refresh('refresh-0')).thenAnswer((_) async => testSession());

    await pumpApp(tester);

    expect(find.text('Hola, Ana'), findsOneWidget);
  });

  testWidgets('el login valida el formulario antes de llamar al servidor', (tester) async {
    await pumpApp(tester);

    await tester.ensureVisible(find.byKey(const Key('login.submit')));
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pump();

    expect(find.text('El correo es obligatorio.'), findsOneWidget);
    verifyNever(
      () => api.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('tras un envío fallido los errores se actualizan al escribir', (tester) async {
    await pumpApp(tester);

    await tester.ensureVisible(find.byKey(const Key('login.submit')));
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pump();
    expect(find.text('El correo es obligatorio.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('login.email')), 'ana@escuelaing.edu.co');
    await tester.pump();
    expect(find.text('El correo es obligatorio.'), findsNothing);
  });

  testWidgets('el login muestra el mensaje del servidor con credenciales inválidas', (tester) async {
    stubLogin(
      () => throw const ApiException(
        code: 'INVALID_CREDENTIALS',
        message: 'Correo o contraseña incorrectos.',
        statusCode: 401,
      ),
    );
    await pumpApp(tester);

    await tester.enterText(find.byKey(const Key('login.email')), 'ana@escuelaing.edu.co');
    await tester.enterText(find.byKey(const Key('login.password')), 'otra1234');
    await tester.ensureVisible(find.byKey(const Key('login.submit')));
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();

    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('login y logout completos', (tester) async {
    when(() => api.login(email: 'ana@escuelaing.edu.co', password: 'festa123')).thenAnswer((_) async => testSession());
    when(() => api.logout(any())).thenAnswer((_) async {});
    await pumpApp(tester);

    await tester.enterText(find.byKey(const Key('login.email')), 'ana@escuelaing.edu.co');
    await tester.enterText(find.byKey(const Key('login.password')), 'festa123');
    await tester.ensureVisible(find.byKey(const Key('login.submit')));
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();
    expect(find.text('Hola, Ana'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home.logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();

    verify(() => api.logout('refresh-1')).called(1);
    expect(storage.refreshToken, isNull);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('el registro muestra que el correo ya existe', (tester) async {
    when(
      () => api.register(
        email: any(named: 'email'),
        password: any(named: 'password'),
        displayName: any(named: 'displayName'),
        accountType: any(named: 'accountType'),
      ),
    ).thenThrow(
      const ApiException(code: 'EMAIL_TAKEN', message: 'Ya existe una cuenta con ese correo.', statusCode: 409),
    );
    await pumpApp(tester);
    await tester.ensureVisible(find.text('¿No tienes cuenta? Regístrate'));
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    await _fillRegister(tester);
    await tester.ensureVisible(find.byKey(const Key('register.submit')));
    await tester.tap(find.byKey(const Key('register.submit')));
    await tester.pumpAndSettle();

    expect(find.text('Ya existe una cuenta con ese correo.'), findsOneWidget);
  });

  testWidgets('el registro no se envía si no se autoriza el tratamiento de datos', (tester) async {
    await pumpApp(tester);
    await tester.ensureVisible(find.text('¿No tienes cuenta? Regístrate'));
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    await _fillRegister(tester, acceptPrivacy: false);
    await tester.ensureVisible(find.byKey(const Key('register.submit')));
    await tester.tap(find.byKey(const Key('register.submit')));
    await tester.pumpAndSettle();

    expect(find.text('Debes autorizar el tratamiento de tus datos personales para registrarte.'), findsOneWidget);
    verifyNever(
      () => api.register(
        email: any(named: 'email'),
        password: any(named: 'password'),
        displayName: any(named: 'displayName'),
        accountType: any(named: 'accountType'),
      ),
    );
  });

  Future<void> fillMerchantWizard(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.ensureVisible(find.text('¿No tienes cuenta? Regístrate'));
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Comercio'));
    await tester.tap(find.text('Comercio'));
    await _fillRegister(tester);
    await tester.ensureVisible(find.byKey(const Key('register.next1')));
    await tester.tap(find.byKey(const Key('register.next1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('register.address')), 'Calle 205 # 59-00, Bogotá');
    await tester.tap(find.byKey(const Key('register.category.Cultural')));
    await tester.ensureVisible(find.byKey(const Key('register.next2')));
    await tester.tap(find.byKey(const Key('register.next2')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('register.submit')));
    await tester.tap(find.byKey(const Key('register.submit')));
    await tester.pumpAndSettle();
  }

  void stubMerchantRegister() => when(
    () => api.register(
      email: any(named: 'email'),
      password: any(named: 'password'),
      displayName: any(named: 'displayName'),
      accountType: any(named: 'accountType'),
    ),
  ).thenAnswer((_) async => merchantSession);

  testWidgets('el registro de comercio crea la cuenta, envía la solicitud y llega a la verificación', (tester) async {
    stubMerchantRegister();
    when(() => merchantApi.submit(any())).thenAnswer((_) async => const MerchantStatus(verificationStatus: 'PENDING'));
    when(() => merchantApi.myMerchant()).thenAnswer((_) async => const MerchantStatus(verificationStatus: 'PENDING'));

    await fillMerchantWizard(tester);

    verify(
      () => api.register(
        email: 'ana@escuelaing.edu.co',
        password: 'festa123',
        displayName: 'Ana',
        accountType: AccountType.merchant,
      ),
    ).called(1);
    final request = verify(() => merchantApi.submit(captureAny())).captured.single as MerchantRequest;
    expect(request.businessName, 'Ana');
    expect(request.category, 'CULTURAL');
    expect(request.address, 'Calle 205 # 59-00, Bogotá');
    expect(find.byKey(const Key('merchant.status.title')), findsOneWidget);
    expect(find.text('Estamos revisando tu perfil'), findsOneWidget);
  });

  testWidgets('si la solicitud falla, se queda en el registro y al reintentar no repite la cuenta', (tester) async {
    stubMerchantRegister();
    var attempts = 0;
    when(() => merchantApi.submit(any())).thenAnswer((_) async {
      if (++attempts == 1) throw networkFailure;
      return const MerchantStatus(verificationStatus: 'PENDING');
    });
    when(() => merchantApi.myMerchant()).thenAnswer((_) async => const MerchantStatus(verificationStatus: 'PENDING'));

    await fillMerchantWizard(tester);
    expect(find.byKey(const Key('merchant.status.title')), findsNothing);
    expect(find.byKey(const Key('register.submit')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('register.submit')));
    await tester.tap(find.byKey(const Key('register.submit')));
    await tester.pumpAndSettle();

    verify(
      () => api.register(
        email: any(named: 'email'),
        password: any(named: 'password'),
        displayName: any(named: 'displayName'),
        accountType: any(named: 'accountType'),
      ),
    ).called(1);
    expect(find.byKey(const Key('merchant.status.title')), findsOneWidget);
  });
}

Future<void> _fillRegister(WidgetTester tester, {bool acceptPrivacy = true}) async {
  await tester.enterText(find.byKey(const Key('register.name')), 'Ana');
  await tester.enterText(find.byKey(const Key('register.email')), 'ana@escuelaing.edu.co');
  await tester.enterText(find.byKey(const Key('register.password')), 'festa123');
  await tester.enterText(find.byKey(const Key('register.confirmPassword')), 'festa123');
  if (acceptPrivacy) {
    await tester.ensureVisible(find.byKey(const Key('register.privacyCheckbox')));
    await tester.tap(find.byKey(const Key('register.privacyCheckbox')));
    await tester.pump();
  }
}
