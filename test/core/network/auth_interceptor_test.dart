import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:festa/core/network/auth_interceptor.dart';
import 'package:festa/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fakes.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// Responde 401 cuando el test lo libera: simula una respuesta que tarda mientras cambia la sesión.
class _DeferredUnauthorizedAdapter implements HttpClientAdapter {
  final released = Completer<void>();
  final started = Completer<void>(); // la petición ya salió hacia el servidor

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    started.complete();
    await released.future;
    return ResponseBody.fromString('', 401);
  }

  @override
  void close({bool force = false}) {}
}

/// Cuenta cuántas veces se repitió una petición.
class _CountingAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Responde siempre 401, como el gateway ante un JWT caducado.
class _UnauthorizedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('', 401);

  @override
  void close({bool force = false}) {}
}

void main() {
  late _MockAuthRepository repository;
  late Dio dio;

  setUp(() {
    repository = _MockAuthRepository();
    when(() => repository.accessToken).thenReturn('token-a');
    when(() => repository.refresh()).thenAnswer((_) async => null);
    dio = Dio(BaseOptions(baseUrl: 'http://festa.test'))
      ..httpClientAdapter = _UnauthorizedAdapter()
      ..interceptors.add(AuthInterceptor(repository: repository, retryClient: Dio()));
  });

  test('un 401 normal renueva la sesión una vez', () async {
    await expectLater(dio.get<void>('/api/recurso'), throwsA(isA<DioException>()));

    verify(() => repository.refresh()).called(1);
  });

  Future<(Dio, _DeferredUnauthorizedAdapter, _CountingAdapter)> clientWithDeferred401() async {
    final deferred = _DeferredUnauthorizedAdapter();
    final retries = _CountingAdapter();
    final client = Dio(BaseOptions(baseUrl: 'http://festa.test'))
      ..httpClientAdapter = deferred
      ..interceptors.add(
        AuthInterceptor(
          repository: repository,
          retryClient: Dio(BaseOptions(baseUrl: 'http://festa.test'))..httpClientAdapter = retries,
        ),
      );
    return (client, deferred, retries);
  }

  test('un 401 que llega después de cambiar de cuenta no repite la mutación con la sesión nueva', () async {
    var account = 'a1';
    when(() => repository.accountId).thenAnswer((_) => account);
    when(() => repository.refresh())
        .thenAnswer((_) async => testSession('2', testMerchantAccount)); // la sesión vigente ya es de otra cuenta
    final (client, deferred, retries) = await clientWithDeferred401();

    final request = client.post<void>('/api/bookings/events/e1/attendance');
    final failure = expectLater(request, throwsA(isA<DioException>()));
    await deferred.started.future;
    account = testMerchantAccount.id; // la persona cambia de cuenta mientras la respuesta está en camino
    deferred.released.complete();
    await failure;

    expect(retries.calls, 0); // no se envió ni confirmó nada con el token de la cuenta nueva
  });

  test('lo mismo para cancelar la asistencia (DELETE)', () async {
    var account = 'a1';
    when(() => repository.accountId).thenAnswer((_) => account);
    when(() => repository.refresh()).thenAnswer((_) async => testSession('2', testMerchantAccount));
    final (client, deferred, retries) = await clientWithDeferred401();

    final failure = expectLater(
      client.delete<void>('/api/bookings/events/e1/attendance'),
      throwsA(isA<DioException>()),
    );
    await deferred.started.future;
    account = testMerchantAccount.id;
    deferred.released.complete();
    await failure;

    expect(retries.calls, 0);
  });

  test('con la misma cuenta, un 401 sí renueva y repite la petición una vez', () async {
    when(() => repository.accountId).thenReturn(testAccount.id);
    when(() => repository.refresh()).thenAnswer((_) async => testSession('2'));
    final (client, deferred, retries) = await clientWithDeferred401();

    final response = client.post<void>('/api/bookings/events/e1/attendance');
    await deferred.started.future;
    deferred.released.complete();
    await response;

    expect(retries.calls, 1);
  });

  test('un 401 con la marca de no repetir no renueva ni repite con otra sesión', () async {
    await expectLater(
      dio.post<void>('/api/users/me/consents', options: Options(extra: {AuthInterceptor.noRetryKey: true})),
      throwsA(isA<DioException>()),
    );

    verifyNever(() => repository.refresh());
  });
}
