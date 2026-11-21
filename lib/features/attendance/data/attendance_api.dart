import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/attendance_status.dart';

/// Asistencia gratis (RSVP) de booking-service, por el gateway bajo `/api/bookings`. Exige JWT:
/// siempre es la asistencia del usuario de la sesión.
class AttendanceApi {
  AttendanceApi(this._dio);

  final Dio _dio;

  String _path(String eventId) => '/api/bookings/events/$eventId/attendance';

  /// Cupos del evento y si el usuario ya confirmó.
  Future<AttendanceStatus> status(String eventId) async {
    final data = await _call(() => _dio.get<Map<String, dynamic>>(_path(eventId)));
    return AttendanceStatus.fromJson(data);
  }

  /// Confirma la asistencia y devuelve el conteo nuevo. Si ya estaba confirmada, también responde bien.
  Future<int> confirm(String eventId) async {
    final data = await _call(() => _dio.post<Map<String, dynamic>>(_path(eventId)));
    return data['attendeeCount'] as int? ?? 0;
  }

  /// Cancela la asistencia y devuelve el conteo nuevo.
  Future<int> cancel(String eventId) async {
    final data = await _call(() => _dio.delete<Map<String, dynamic>>(_path(eventId)));
    return data['attendeeCount'] as int? ?? 0;
  }

  Future<Map<String, dynamic>> _call(Future<Response<Map<String, dynamic>>> Function() request) async {
    try {
      return (await request()).data ?? const {};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
