import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/merchant_profile.dart';

/// Perfil de comercio en user-service, expuesto por el gateway bajo `/api/users/me/merchant`.
class MerchantApi {
  MerchantApi(this._dio);

  final Dio _dio;

  static const _path = '/api/users/me/merchant';

  /// `null` si la cuenta todavía no ha enviado su perfil de comercio.
  Future<MerchantProfile?> mine() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_path);
      return MerchantProfile.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiException.fromDio(e);
    }
  }

  /// Primer envío: el perfil queda pendiente de verificación.
  Future<MerchantProfile> submit(MerchantDraft draft) => _send(() => _dio.post(_path, data: draft.toJson()));

  /// Corrige o actualiza el perfil. Si estaba rechazado (o cambia un dato clave de uno verificado),
  /// user-service lo devuelve a pendiente de verificación.
  Future<MerchantProfile> update(MerchantDraft draft) => _send(() => _dio.patch(_path, data: draft.toJson()));

  Future<MerchantProfile> _send(Future<Response<Map<String, dynamic>>> Function() request) async {
    try {
      final response = await request();
      return MerchantProfile.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
