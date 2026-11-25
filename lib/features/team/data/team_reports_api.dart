import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/team_report.dart';

/// Revisión de reportes del equipo Festa (RF14). Los reportes viven en user-service, bajo
/// `/api/users/admin/reports`; los datos de la cuenta reportada, en auth-service. Solo responden a una cuenta
/// con rol `admin` (403 a las demás).
class TeamReportsApi {
  TeamReportsApi(this._dio);

  final Dio _dio;

  static const _path = '/api/users/admin/reports';

  /// Reportes abiertos, para revisar a mano.
  Future<List<TeamReport>> open() async {
    try {
      final response = await _dio.get<List<dynamic>>(_path);
      return [
        for (final item in (response.data ?? const []).whereType<Map<String, dynamic>>()) TeamReport.fromJson(item),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Cierra el reporte sin tomar ninguna acción. Lanza [ApiException] con `REPORT_ALREADY_RESOLVED` (409) si
  /// otra persona del equipo ya lo cerró.
  Future<void> dismiss(String reportId) => resolve(reportId, {'outcome': 'dismissed'});

  /// `POST /api/users/admin/reports/{id}/resolve` con la decisión del equipo.
  Future<void> resolve(String reportId, Map<String, Object?> decision) async {
    try {
      await _dio.post<Map<String, dynamic>>('$_path/$reportId/resolve', data: decision);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Nombre, correo y estado de la cuenta reportada.
  Future<ReportedAccount> account(String accountId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/auth/admin/accounts/$accountId');
      return ReportedAccount.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
