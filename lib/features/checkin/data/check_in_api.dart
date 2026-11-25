import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/check_in_result.dart';

/// Ingreso con QR de booking-service (`POST /api/bookings/passes/check-in`). Solo el organizador del
/// evento (o un admin) puede validar.
class CheckInApi {
  CheckInApi(this._dio);

  final Dio _dio;

  /// Valida [qr] para [eventId]. Un QR rechazado (ya usado, de otro evento, cancelado, fuera de horario o
  /// falso) vuelve como [CheckInResult] con su motivo; los demás errores llegan como `ApiException`.
  Future<CheckInResult> checkIn({required String eventId, required String qr}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/bookings/passes/check-in',
        data: {'qr': qr, 'eventId': eventId},
      );
      return CheckInResult.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      final data = e.response?.data;
      // booking responde 409 (o 403 si no es el organizador) con `valid: false` y el motivo.
      if (data is Map<String, dynamic> && data['valid'] == false) return CheckInResult.fromJson(data);
      throw ApiException.fromDio(e);
    }
  }
}
