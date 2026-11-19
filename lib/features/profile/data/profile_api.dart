import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/user_profile.dart';

/// Perfil, intereses y preferencias de festa-user-service, por el gateway bajo `/api/users/me`.
/// Exigen JWT: se construye con el cliente autenticado.
class ProfileApi {
  ProfileApi(this._dio);

  final Dio _dio;

  Future<UserProfile> getProfile() async {
    final data = await _call(() => _dio.get<Map<String, dynamic>>('/api/users/me'));
    return UserProfile.fromJson(data);
  }

  /// Reemplaza el conjunto completo de intereses (`PUT`, no parcial).
  Future<void> replaceInterests(Set<Interest> interests) => _call(
    () => _dio.put<Map<String, dynamic>>(
      '/api/users/me/interests',
      data: {
        'interests': [for (final interest in interests) interest.apiValue],
      },
    ),
  );

  Future<void> updatePreferences(UserPreferences preferences) => _call(
    () => _dio.put<Map<String, dynamic>>(
      '/api/users/me/preferences',
      data: {'budgetRange': preferences.budgetRange.apiValue, 'maxDistanceKm': preferences.maxDistanceKm},
    ),
  );

  Future<Map<String, dynamic>> _call(Future<Response<Map<String, dynamic>>> Function() request) async {
    try {
      return (await request()).data ?? const {};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
