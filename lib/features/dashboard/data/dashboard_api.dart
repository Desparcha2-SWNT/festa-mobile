import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/merchant_dashboard.dart';

/// Panel del comercio de analytics-service (RF15), expuesto por el gateway bajo `/api/analytics`.
/// Exige JWT: siempre son los números del usuario de la sesión.
class DashboardApi {
  DashboardApi(this._dio);

  final Dio _dio;

  Future<MerchantDashboard> mine() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/analytics/merchants/me');
      return MerchantDashboard.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
