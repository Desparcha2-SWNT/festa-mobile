import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';

/// Consentimientos en user-service, expuestos por el gateway bajo `/api/users/me/consents`.
///
/// user-service guarda la evidencia (fecha, versión de la política) y publica
/// `location_consent.granted` o `location_consent.revoked` para los demás servicios.
class ConsentsApi {
  ConsentsApi(this._dio);

  final Dio _dio;

  /// Versión de la política de privacidad que el usuario aceptó (`docs/privacidad` en `.github`).
  static const privacyPolicyVersion = '1.0';

  Future<void> recordLocationConsent({required bool granted}) async {
    try {
      await _dio.post<void>(
        '/api/users/me/consents',
        data: {'type': 'LOCATION', 'granted': granted, 'version': privacyPolicyVersion},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
