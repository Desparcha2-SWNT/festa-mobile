import 'package:dio/dio.dart';

import '../../features/auth/data/auth_repository.dart';

/// Pone el JWT en cada petición y, si el gateway responde 401, renueva la sesión una vez
/// y repite la petición. Lo usan los clientes de los servicios que exigen JWT.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required this._repository, required this._retryClient});

  static const _retriedKey = 'festa.auth_retried';
  static const _accountKey = 'festa.auth_account';

  /// Marca de `Options.extra` para peticiones que no deben renovarse ni repetirse en un 401.
  /// Se usa cuando la petición pertenece a la sesión que la originó: si la sesión cambió (por
  /// ejemplo, otra cuenta inició sesión), repetirla con la nueva la enviaría con otra identidad.
  static const noRetryKey = 'festa.auth_no_retry';

  final AuthRepository _repository;

  /// Cliente sin este interceptor, para repetir la petición sin volver a pasar por aquí.
  final Dio _retryClient;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _repository.accessToken;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    // Cuenta que origina la petición: si al llegar un 401 la sesión ya es de otra cuenta, no se repite (ver onError).
    options.extra[_accountKey] ??= _repository.accountId;
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 || request.extra[_retriedKey] == true || request.extra[noRetryKey] == true) {
      return handler.next(err);
    }

    try {
      final session = await _repository.refresh();
      if (session == null) return handler.next(err);

      // Una confirmación o cancelación salió con la cuenta A; si la sesión cambió a B mientras tanto, repetirla con el
      // token de B actuaría sobre la cuenta equivocada. Solo se repite con la misma cuenta que la originó.
      final origin = request.extra[_accountKey];
      if (origin != null && origin != session.account.id) return handler.next(err);

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
