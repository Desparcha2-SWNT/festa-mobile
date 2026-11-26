import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/pass.dart';

/// «Mis entradas» de booking-service, por el gateway bajo `/api/bookings`. Exige JWT.
class PassesApi {
  PassesApi(this._dio);

  final Dio _dio;

  /// Los pases del usuario de la sesión, los de eventos vigentes primero.
  Future<List<Pass>> mine() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/bookings/passes/mine');
      final items = response.data?['items'] as List<dynamic>? ?? const [];
      return [for (final item in items.whereType<Map<String, dynamic>>()) Pass.fromJson(item)];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
