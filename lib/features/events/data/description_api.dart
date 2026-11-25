import 'dart:math';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/event.dart';

/// Descripción de evento con IA de ai-service (RF9), expuesta por el gateway bajo `/api/ai`. Exige JWT.
///
/// El servicio genera UNA descripción por borrador (`draftId`) y la guarda: pedir otra versión es abrir
/// otro borrador, es decir, mandar otro `draftId`. Por eso cada llamada a [generate] crea uno nuevo.
class DescriptionApi {
  DescriptionApi(this._dio, {Random? random}) : _random = random ?? Random.secure();

  final Dio _dio;
  final Random _random;

  /// Largo máximo de las notas que acepta el servicio.
  static const maxNotesLength = 300;

  Future<String> generate({
    required String name,
    required String location,
    required EventCategory category,
    DateTime? startsAt,
    String? notes,
    String? merchantId,
  }) async {
    final trimmedNotes = notes?.trim() ?? '';
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/ai/descriptions',
        data: {
          'draftId': newDraftId(),
          'name': name,
          'location': location,
          'activityType': category.label,
          'category': category.name,
          if (startsAt != null) 'startsAt': startsAt.toUtc().toIso8601String(),
          if (trimmedNotes.isNotEmpty)
            'notes': trimmedNotes.length > maxNotesLength ? trimmedNotes.substring(0, maxNotesLength) : trimmedNotes,
          'merchantId': ?merchantId,
        },
      );
      return (response.data!['description'] as String).trim();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// UUID v4 en minúsculas, el formato que exige ai-service para el borrador.
  String newDraftId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
