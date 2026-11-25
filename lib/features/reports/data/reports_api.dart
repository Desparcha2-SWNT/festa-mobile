import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/report.dart';

/// Reportes de user-service (RF14), por el gateway bajo `/api/reports`. Exige JWT: el reporte queda a
/// nombre del usuario de la sesión.
class ReportsApi {
  ReportsApi(this._dio);

  final Dio _dio;

  /// Envía un reporte para revisión manual del equipo Festa.
  ///
  /// Lanza [ApiException] con código `REPORT_ALREADY_OPEN` (409) si el usuario ya tiene un reporte abierto
  /// sobre lo mismo.
  Future<void> create({
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String? comment,
  }) async {
    final cleanComment = comment?.trim();
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/reports',
        data: {
          'targetType': target.api,
          'targetId': targetId,
          'reason': reason.api,
          if (cleanComment != null && cleanComment.isNotEmpty) 'comment': cleanComment,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
