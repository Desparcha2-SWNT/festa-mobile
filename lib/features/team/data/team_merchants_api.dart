import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/pending_merchant.dart';

/// Verificación de comercios del equipo Festa en user-service, por el gateway bajo `/api/users/admin/merchants`.
/// Solo la puede usar una cuenta con rol `admin` (user-service responde 403 a las demás).
class TeamMerchantsApi {
  TeamMerchantsApi(this._dio);

  final Dio _dio;

  static const _path = '/api/users/admin/merchants';

  /// Comercios pendientes de verificación.
  Future<List<PendingMerchant>> pending() async {
    try {
      final response = await _dio.get<List<dynamic>>(_path);
      return [
        for (final item in (response.data ?? const []).whereType<Map<String, dynamic>>())
          PendingMerchant.fromJson(item),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Verifica el comercio: user-service le cambia el rol a `merchant` en auth-service y ya puede publicar.
  Future<void> approve(String accountId) => _post('$_path/$accountId/approve');

  /// Rechaza el comercio con un motivo (máximo 500 caracteres) que el comercio ve para corregir su perfil.
  Future<void> reject(String accountId, String reason) => _post('$_path/$accountId/reject', data: {'reason': reason});

  Future<void> _post(String path, {Object? data}) async {
    try {
      await _dio.post<Map<String, dynamic>>(path, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
