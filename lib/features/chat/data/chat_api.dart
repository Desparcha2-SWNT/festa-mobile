import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../location/domain/geo_point.dart';
import '../domain/chat_models.dart';

/// Chat de recomendaciones de ai-service (RF8), expuesto por el gateway bajo `/api/ai`. Exige JWT.
class ChatApi {
  ChatApi(this._dio);

  final Dio _dio;

  /// Manda un mensaje. [sessionId] es null en el primer turno y el servicio lo crea; después se reenvía
  /// para que la IA recuerde la conversación. [location] solo se manda si el usuario dio su consentimiento
  /// de ubicación (Ley 1581): quien llama decide, aquí no se lee la ubicación del teléfono.
  Future<ChatReply> send(String message, {String? sessionId, GeoPoint? location}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/ai/chat',
        data: {
          'message': message,
          'sessionId': ?sessionId,
          if (location != null) 'location': {'lat': location.latitude, 'lng': location.longitude},
        },
      );
      return ChatReply.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
