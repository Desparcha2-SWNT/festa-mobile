import 'package:festa/app/festa_app.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/auth/application/auth_providers.dart';
import 'package:festa/features/auth/domain/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fakes.dart';

void main() {
  late MockAuthApi api;
  late InMemoryTokenStorage storage;

  setUpAll(() => registerFallbackValue(AccountType.user));

  setUp(() {
    api = MockAuthApi();
    storage = InMemoryTokenStorage();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authApiProvider.overrideWithValue(api), tokenStorageProvider.overrideWithValue(storage)],
        child: const FestaApp(),
      ),
    );
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

    expect(find.text('Inicia sesión'), findsOneWidget);
  });

  testWidgets('con sesión guardada entra directo al inicio', (tester) async {
    storage.refreshToken = 'refresh-0';
    when(() => api.refresh('refresh-0')).thenAnswer((_) async => testSession());

    await pumpApp(tester);

    expect(find.text('Hola, Ana'), findsOneWidget);
  });

  testWidgets('el login valida el formulario antes de llamar al servidor', (tester) async {
    await pumpApp(tester);

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
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();

    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
    expect(find.text('Inicia sesión'), findsOneWidget);
  });

  testWidgets('login y logout completos', (tester) async {
    when(() => api.login(email: 'ana@escuelaing.edu.co', password: 'festa123')).thenAnswer((_) async => testSession());
    when(() => api.logout(any())).thenAnswer((_) async {});
    await pumpApp(tester);

    await tester.enterText(find.byKey(const Key('login.email')), 'ana@escuelaing.edu.co');
    await tester.enterText(find.byKey(const Key('login.password')), 'festa123');
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();
    expect(find.text('Hola, Ana'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home.logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();

    verify(() => api.logout('refresh-1')).called(1);
    expect(storage.refreshToken, isNull);
    expect(find.text('Inicia sesión'), findsOneWidget);
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
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    await _fillRegister(tester);
    await tester.ensureVisible(find.byKey(const Key('register.submit')));
    await tester.tap(find.byKey(const Key('register.submit')));
    await tester.pumpAndSettle();

    expect(find.text('Ya existe una cuenta con ese correo.'), findsOneWidget);
  });

  testWidgets('el registro exitoso entra al inicio con el tipo de cuenta elegido', (tester) async {
    when(
      () => api.register(
        email: any(named: 'email'),
        password: any(named: 'password'),
        displayName: any(named: 'displayName'),
        accountType: any(named: 'accountType'),
      ),
    ).thenAnswer((_) async => testSession());
    await pumpApp(tester);
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comercio'));
    await _fillRegister(tester);
    await tester.ensureVisible(find.byKey(const Key('register.submit')));
    await tester.tap(find.byKey(const Key('register.submit')));
    await tester.pumpAndSettle();

    verify(
      () => api.register(
        email: 'ana@escuelaing.edu.co',
        password: 'festa123',
        displayName: 'Ana',
        accountType: AccountType.merchant,
      ),
    ).called(1);
    expect(find.text('Hola, Ana'), findsOneWidget);
  });
}

Future<void> _fillRegister(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('register.name')), 'Ana');
  await tester.enterText(find.byKey(const Key('register.email')), 'ana@escuelaing.edu.co');
  await tester.enterText(find.byKey(const Key('register.password')), 'festa123');
  await tester.enterText(find.byKey(const Key('register.confirmPassword')), 'festa123');
}
