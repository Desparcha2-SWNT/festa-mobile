import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../location/domain/geo_point.dart';
import '../domain/event.dart';

/// Endpoints de event-service, expuestos por el gateway bajo `/api/events`.
class EventsApi {
  EventsApi(this._dio);

  final Dio _dio;

  /// Eventos publicados y próximos alrededor de [center] (SCRUM-74).
  ///
  /// PENDIENTE: el endpoint aún no existe en event-service. Este es el contrato propuesto a
  /// SCRUM-74; si cambia, solo cambia este método:
  /// `GET /api/events/nearby?lat=&lng=&radiusKm=` → `{"items": [Evento, ...]}`.
  Future<List<Event>> nearby(GeoPoint center, {required double radiusKm}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/events/nearby',
        queryParameters: {'lat': center.latitude, 'lng': center.longitude, 'radiusKm': radiusKm},
      );
      final items = response.data!['items'] as List<dynamic>;
      return [for (final item in items) Event.fromJson(item as Map<String, dynamic>)];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Event> byId(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/events/$id');
      return Event.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
