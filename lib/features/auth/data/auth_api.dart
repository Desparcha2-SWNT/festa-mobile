import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/account.dart';
import '../domain/auth_session.dart';

/// Endpoints públicos de auth-service, expuestos por el gateway bajo `/api/auth`.
///
/// Usa un [Dio] sin el interceptor de autenticación: ninguno de estos endpoints lleva JWT
/// y así el refresh no puede entrar en un ciclo consigo mismo.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    required AccountType accountType,
  }) => _postSession('/api/auth/register', {
    'email': email,
    'password': password,
    'displayName': displayName,
    'accountType': accountType.apiValue,
  });

  Future<AuthSession> login({required String email, required String password}) =>
      _postSession('/api/auth/login', {'email': email, 'password': password});

  Future<AuthSession> refresh(String refreshToken) => _postSession('/api/auth/refresh', {'refreshToken': refreshToken});

  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<void>('/api/auth/logout', data: {'refreshToken': refreshToken});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<AuthSession> _postSession(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      return AuthSession.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
