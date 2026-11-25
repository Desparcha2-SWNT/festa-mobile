import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/order.dart';

/// Boletas de payment-service, expuestas por el gateway bajo `/api/payments`. Exigen JWT.
class OrdersApi {
  OrdersApi(this._dio);

  final Dio _dio;

  /// Crea la orden y retiene los cupos (vencen a los 15 min si no se paga). La clave de idempotencia
  /// evita dos órdenes si el usuario toca dos veces el botón.
  Future<CheckoutOrder> createOrder({
    required String eventId,
    required int quantity,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/payments/orders',
        data: {'eventId': eventId, 'quantity': quantity},
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return CheckoutOrder.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<Order>> listMine() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/payments/orders/mine');
      final items = response.data!['items'] as List<dynamic>;
      return items.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
