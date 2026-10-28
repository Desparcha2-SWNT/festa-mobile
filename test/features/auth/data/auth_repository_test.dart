import 'dart:async';

import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fakes.dart';

void main() {
  late MockAuthApi api;
  late InMemoryTokenStorage storage;
  late AuthRepository repository;

  setUp(() {
    api = MockAuthApi();
    storage = InMemoryTokenStorage();
    repository = AuthRepository(api: api, storage: storage);
  });

  tearDown(() => repository.dispose());

  test('el login guarda el refresh token y deja el access token solo en memoria', () async {
    when(
      () => api.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => testSession());

    final account = await repository.login(email: 'ana@escuelaing.edu.co', password: 'secreta123');

    expect(account.displayName, 'Ana');
    expect(repository.accessToken, 'access-1');
    expect(storage.refreshToken, 'refresh-1');
  });

  test('restore no llama al servidor si no hay sesión guardada', () async {
    expect(await repository.restore(), isNull);
    verifyNever(() => api.refresh(any()));
  });

  test('restore recupera la sesión y guarda el refresh token rotado', () async {
    storage.refreshToken = 'refresh-0';
    when(() => api.refresh('refresh-0')).thenAnswer((_) async => testSession('1'));

    expect(await repository.restore(), testAccount);
    expect(storage.refreshToken, 'refresh-1');
  });

  test('los refresh concurrentes comparten una sola petición', () async {
    storage.refreshToken = 'refresh-0';
    final response = Completer<void>();
    when(() => api.refresh(any())).thenAnswer((_) async {
      await response.future;
      return testSession('1');
    });

    final calls = [repository.refresh(), repository.refresh(), repository.refresh()];
    response.complete();
    await Future.wait(calls);

    verify(() => api.refresh('refresh-0')).called(1);
  });

  test('si el refresh es rechazado borra la sesión y avisa', () async {
    storage.refreshToken = 'refresh-0';
    when(() => api.refresh(any())).thenThrow(invalidRefresh);
    final expired = expectLater(repository.sessionExpired, emits(null));

    expect(await repository.refresh(), isNull);
    await expired;
    expect(storage.refreshToken, isNull);
  });

  test('un error de red al renovar conserva la sesión guardada', () async {
    storage.refreshToken = 'refresh-0';
    when(() => api.refresh(any())).thenThrow(networkFailure);

    await expectLater(repository.refresh(), throwsA(isA<ApiException>()));
    expect(storage.refreshToken, 'refresh-0');
  });

  test('el logout borra la sesión local aunque el servidor falle', () async {
    when(
      () => api.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => testSession());
    when(() => api.logout(any())).thenThrow(networkFailure);
    await repository.login(email: 'ana@escuelaing.edu.co', password: 'secreta123');

    await repository.logout();

    verify(() => api.logout('refresh-1')).called(1);
    expect(repository.accessToken, isNull);
    expect(storage.refreshToken, isNull);
  });
}
