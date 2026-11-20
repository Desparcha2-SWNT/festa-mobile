import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/attendee.dart';

/// Lista de asistentes de booking-service, expuesta por el gateway bajo `/api/bookings`.
/// Solo responde al organizador del evento (o a un admin); a los demás les da 403.
class AttendeesApi {
  AttendeesApi(this._dio);

  /// Tamaño de página por defecto del servicio.
  static const pageSize = 50;

  final Dio _dio;

  Future<AttendeePage> list(String eventId, {int offset = 0, int limit = pageSize}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/bookings/events/$eventId/attendees',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return AttendeePage.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
