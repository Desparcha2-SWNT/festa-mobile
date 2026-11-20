import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/auth_interceptor.dart';

/// Consentimientos en user-service, expuestos por el gateway bajo `/api/users/me/consents`.
///
/// user-service guarda la evidencia (fecha, versión de la política) y publica
/// `location_consent.granted` o `location_consent.revoked` para los demás servicios.
class ConsentsApi {
  ConsentsApi(this._dio);

  final Dio _dio;

  /// Versión de la política de privacidad que el usuario aceptó (`docs/privacidad` en `.github`).
  static const privacyPolicyVersion = '1.0';

  /// No se repite con otra sesión si el token caduca: la decisión queda pendiente y se reenvía
  /// al abrir la app con la cuenta que la tomó (ver `LocationConsentController`).
  Future<void> recordLocationConsent({required bool granted}) async {
    try {
      await _dio.post<void>(
        '/api/users/me/consents',
        data: {'type': 'LOCATION', 'granted': granted, 'version': privacyPolicyVersion},
        options: Options(extra: {AuthInterceptor.noRetryKey: true}),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
