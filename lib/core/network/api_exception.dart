import 'package:dio/dio.dart';

/// Error de la API traducido a algo que la UI puede mostrar.
///
/// Los servicios responden `{"error": {"code", "message", "details"}}` con mensajes en español.
/// Kong (gateway) responde `{"message": "..."}` en sus 401 y 429, así que para esos casos
/// nos guiamos por el código de estado.
class ApiException implements Exception {
  const ApiException({required this.code, required this.message, this.statusCode, this.fieldErrors = const {}});

  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    if (response == null) {
      return const ApiException(
        code: networkError,
        message: 'No pudimos conectarnos. Revisa tu conexión e intenta de nuevo.',
      );
    }

    final status = response.statusCode;
    final error = _errorBody(response.data);
    if (error != null) {
      return ApiException(
        code: error['code'] as String? ?? unknownError,
        message: error['message'] as String? ?? _genericMessage,
        statusCode: status,
        fieldErrors: _fieldErrors(error['details']),
      );
    }

    return switch (status) {
      429 => ApiException(
        code: tooManyRequests,
        message: 'Hiciste demasiados intentos. Espera un momento e intenta de nuevo.',
        statusCode: status,
      ),
      401 => ApiException(code: unauthorized, message: 'Tu sesión expiró. Inicia sesión de nuevo.', statusCode: status),
      _ => ApiException(code: unknownError, message: _genericMessage, statusCode: status),
    };
  }

  // Códigos generados en el cliente (los demás vienen del servidor).
  static const networkError = 'NETWORK_ERROR';
  static const tooManyRequests = 'TOO_MANY_REQUESTS';
  static const unauthorized = 'UNAUTHORIZED';
  static const unknownError = 'UNKNOWN_ERROR';

  static const _genericMessage = 'Ocurrió un error inesperado. Intenta de nuevo.';

  final String code;
  final String message;
  final int? statusCode;

  /// Errores por campo de un `VALIDATION_ERROR`, indexados por el nombre del campo en la API.
  final Map<String, String> fieldErrors;

  static Map<String, dynamic>? _errorBody(Object? data) {
    if (data is Map<String, dynamic> && data['error'] is Map<String, dynamic>) {
      return data['error'] as Map<String, dynamic>;
    }
    return null;
  }

  static Map<String, String> _fieldErrors(Object? details) {
    if (details is! List) return const {};
    return {
      for (final d in details.whereType<Map<String, dynamic>>())
        if (d['field'] is String && d['message'] is String) d['field'] as String: d['message'] as String,
    };
  }

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
