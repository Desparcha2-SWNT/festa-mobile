import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../location/domain/geo_point.dart';
import '../domain/event.dart';
import '../domain/event_draft.dart';

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

  /// Eventos creados por el usuario autenticado, en todos los estados (`GET /api/events/mine`).
  Future<List<Event>> mine() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/events/mine');
      final items = response.data!['items'] as List<dynamic>;
      return [for (final item in items) Event.fromJson(item as Map<String, dynamic>)];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Publica un evento de un comercio verificado (SCRUM-63). [merchantId] es el id de la cuenta:
  /// hay un comercio por cuenta.
  Future<Event> create(EventDraft draft, {required String merchantId, required String organizerName}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/events',
        data: draft.toCreateJson(merchantId: merchantId, organizerName: organizerName),
      );
      return Event.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Guarda los cambios de un evento (SCRUM-67). [changes] lleva solo los campos que cambiaron
  /// (ver `EventDraft.changesFrom`). Solo el creador puede editar.
  Future<Event> update(String id, Map<String, dynamic> changes) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>('/api/events/$id', data: changes);
      return Event.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Cancela un evento (SCRUM-68). [reason] les llega a quienes habían confirmado.
  Future<Event> cancel(String id, {required String reason}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/api/events/$id/cancel', data: {'reason': reason});
      return Event.fromJson(response.data!);
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
