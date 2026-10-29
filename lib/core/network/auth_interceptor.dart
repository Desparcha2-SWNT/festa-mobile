import 'package:dio/dio.dart';

import '../../features/auth/data/auth_repository.dart';

/// Pone el JWT en cada petición y, si el gateway responde 401, renueva la sesión una vez
/// y repite la petición. Lo usan los clientes de los servicios que exigen JWT.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required this._repository, required this._retryClient});

  static const _retriedKey = 'festa.auth_retried';

  final AuthRepository _repository;

  /// Cliente sin este interceptor, para repetir la petición sin volver a pasar por aquí.
  final Dio _retryClient;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _repository.accessToken;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 || request.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    try {
      final session = await _repository.refresh();
      if (session == null) return handler.next(err);

      request
        ..extra[_retriedKey] = true
        ..headers['Authorization'] = 'Bearer ${session.accessToken}';
      handler.resolve(await _retryClient.fetch<dynamic>(request));
    } on DioException catch (e) {
      handler.next(e);
    } catch (_) {
      handler.next(err);
    }
  }
}
