import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import '../config/app_config.dart';
import 'auth_interceptor.dart';

Dio _baseDio() => Dio(
  BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
  ),
);

/// Cliente para endpoints públicos (registro, login, refresh, logout).
final publicDioProvider = Provider<Dio>((ref) {
  final dio = _baseDio();
  ref.onDispose(dio.close);
  return dio;
});

/// Cliente para los servicios que exigen JWT: agrega el token y renueva la sesión en un 401.
final authenticatedDioProvider = Provider<Dio>((ref) {
  final retryClient = _baseDio();
  final dio = _baseDio()
    ..interceptors.add(AuthInterceptor(repository: ref.watch(authRepositoryProvider), retryClient: retryClient));
  ref.onDispose(() {
    dio.close();
    retryClient.close();
  });
  return dio;
});
