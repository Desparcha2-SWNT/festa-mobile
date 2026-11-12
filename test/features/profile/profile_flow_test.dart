import 'package:festa/app/festa_app.dart';
import 'package:festa/features/auth/application/auth_providers.dart';
import 'package:festa/features/profile/application/profile_providers.dart';
import 'package:festa/features/profile/domain/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fakes.dart';

void main() {
  late MockAuthApi authApi;
  late MockProfileApi profileApi;
  late InMemoryTokenStorage storage;

  setUpAll(() {
    registerFallbackValue(<Interest>{});
    registerFallbackValue(const UserPreferences());
  });

  setUp(() {
    authApi = MockAuthApi();
    profileApi = MockProfileApi();
    storage = InMemoryTokenStorage('refresh-0');
    when(() => authApi.refresh('refresh-0')).thenAnswer((_) async => testSession());
  });

  /// Abre la app con sesión iniciada y entra a «Mi perfil» desde el inicio.
  Future<void> openProfile(WidgetTester tester) async {
    // Pantalla alta: la lista construye sus elementos de forma perezosa y los de abajo no existirían.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWithValue(authApi),
          profileApiProvider.overrideWithValue(profileApi),
          tokenStorageProvider.overrideWithValue(storage),
        ],
        child: const FestaApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home.profile')));
    await tester.pumpAndSettle();
  }

  void stubProfile([UserProfile? profile]) => when(() => profileApi.getProfile()).thenAnswer(
    (_) async =>
        profile ??
        const UserProfile(
          interests: {Interest.cultural, Interest.musical},
          preferences: UserPreferences(budgetRange: BudgetRange.medium, maxDistanceKm: 5),
        ),
  );

  bool isSelected(WidgetTester tester, String key) {
    final chip = tester.widget(find.byKey(Key(key)));
    return chip is FilterChip ? chip.selected : (chip as ChoiceChip).selected;
  }

  testWidgets('muestra la cuenta y lo guardado, y «Guardar» empieza deshabilitado', (tester) async {
    stubProfile();
    await openProfile(tester);

    expect(find.text('Ana'), findsOneWidget);
    expect(find.byKey(const Key('profile.email')), findsOneWidget);
    expect(find.text('Hasta 5 km de donde estés'), findsOneWidget);
    expect(isSelected(tester, 'profile.interest.cultural'), isTrue);
    expect(isSelected(tester, 'profile.interest.deportivo'), isFalse);
    expect(isSelected(tester, 'profile.budget.medium'), isTrue);
    expect(tester.widget<FilledButton>(find.byKey(const Key('profile.save'))).onPressed, isNull);
  });

  testWidgets('guarda intereses y preferencias editados', (tester) async {
    stubProfile();
    when(() => profileApi.replaceInterests(any())).thenAnswer((_) async {});
    when(() => profileApi.updatePreferences(any())).thenAnswer((_) async {});
    await openProfile(tester);

    await tester.tap(find.byKey(const Key('profile.interest.deportivo')));
    await tester.tap(find.byKey(const Key('profile.interest.musical')));
    await tester.tap(find.byKey(const Key('profile.budget.low')));
    await tester.pump();
    final save = find.byKey(const Key('profile.save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    verify(() => profileApi.replaceInterests({Interest.cultural, Interest.deportivo})).called(1);
    verify(() => profileApi.updatePreferences(const UserPreferences(budgetRange: BudgetRange.low, maxDistanceKm: 5)))
        .called(1);
    expect(find.text('Cambios guardados.'), findsOneWidget);
  });

  testWidgets('si no se puede guardar, muestra el mensaje y conserva lo editado', (tester) async {
    stubProfile();
    when(() => profileApi.replaceInterests(any())).thenThrow(networkFailure);
    await openProfile(tester);

    await tester.tap(find.byKey(const Key('profile.interest.gastronomico')));
    await tester.pump();
    final save = find.byKey(const Key('profile.save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile.error')), findsOneWidget);
    expect(find.text(networkFailure.message), findsOneWidget);
    expect(isSelected(tester, 'profile.interest.gastronomico'), isTrue);
    verifyNever(() => profileApi.updatePreferences(any()));
  });

  testWidgets('si el perfil no carga, permite reintentar', (tester) async {
    var attempts = 0;
    when(() => profileApi.getProfile()).thenAnswer((_) async {
      if (++attempts == 1) throw networkFailure;
      return const UserProfile(interests: {Interest.deportivo});
    });
    await openProfile(tester);
    expect(find.byKey(const Key('profile.loadError')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile.retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile.loadError')), findsNothing);
    expect(isSelected(tester, 'profile.interest.deportivo'), isTrue);
  });

  testWidgets('cerrar sesión pide confirmación y vuelve al login', (tester) async {
    stubProfile();
    when(() => authApi.logout(any())).thenAnswer((_) async {});
    await openProfile(tester);

    final logout = find.byKey(const Key('profile.logout'));
    await tester.ensureVisible(logout);
    await tester.tap(logout);
    await tester.pumpAndSettle();
    expect(find.text('¿Cerrar sesión?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile.logout.confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
