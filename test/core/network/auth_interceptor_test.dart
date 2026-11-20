import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:festa/core/network/auth_interceptor.dart';
import 'package:festa/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

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

  test('un 401 con la marca de no repetir no renueva ni repite con otra sesión', () async {
    await expectLater(
      dio.post<void>('/api/users/me/consents', options: Options(extra: {AuthInterceptor.noRetryKey: true})),
      throwsA(isA<DioException>()),
    );

    verifyNever(() => repository.refresh());
  });
}
