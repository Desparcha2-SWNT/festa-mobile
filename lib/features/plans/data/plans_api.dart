import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/my_plan.dart';

/// «Mis planes» de booking-service, expuesto por el gateway bajo `/api/bookings`. Exige JWT:
/// siempre son los planes del usuario de la sesión.
class PlansApi {
  PlansApi(this._dio);

  static const pageSize = 20;

  final Dio _dio;

  Future<MyPlansPage> list(PlansTab tab, {int offset = 0, int limit = pageSize}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/bookings/attendances/mine',
        queryParameters: {'when': tab.name, 'limit': limit, 'offset': offset},
      );
      return MyPlansPage.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
