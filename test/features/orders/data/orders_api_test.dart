import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/orders/data/orders_api.dart';
import 'package:festa/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responde siempre lo mismo y guarda la última petición.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body);

  final int status;
  final Object body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _orderJson({String status = 'PENDING'}) => {
  'orderId': 'o-1',
  'reference': 'ref-1',
  'eventId': 'e1',
  'eventTitle': 'Feria',
  'quantity': 2,
  'unitPriceCents': 5000000,
  'subtotalCents': 10000000,
  'totalCents': 10000000,
  'currency': 'COP',
  'status': status,
  'expiresAt': '2026-11-21T12:00:00.000Z',
  'createdAt': '2026-11-21T11:45:00.000Z',
  'checkout': {'provider': 'wompi', 'checkoutUrl': 'https://checkout.wompi.co/p/?reference=ref-1'},
};

void main() {
  (OrdersApi, _FakeAdapter) build(int status, Object body) {
    final adapter = _FakeAdapter(status, body);
    final dio = Dio(BaseOptions(baseUrl: 'http://festa.test'))..httpClientAdapter = adapter;
    return (OrdersApi(dio), adapter);
  }

  test('crea la orden con la clave de idempotencia y devuelve el checkout de Wompi', () async {
    final (api, adapter) = build(201, _orderJson());

    final created = await api.createOrder(eventId: 'e1', quantity: 2, idempotencyKey: 'e1-123456');

    expect(adapter.last!.path, '/api/payments/orders');
    expect(adapter.last!.method, 'POST');
    expect(adapter.last!.headers['Idempotency-Key'], 'e1-123456');
    expect(adapter.last!.data, {'eventId': 'e1', 'quantity': 2});
    expect(created.order.status, OrderStatus.pending);
    expect(created.checkoutUrl, Uri.parse('https://checkout.wompi.co/p/?reference=ref-1'));
  });

  test('una orden ya pagada no trae checkout', () async {
    final (api, _) = build(200, _orderJson(status: 'APPROVED')..remove('checkout'));

    final created = await api.createOrder(eventId: 'e1', quantity: 1, idempotencyKey: 'e1-000000001');

    expect(created.order.status, OrderStatus.approved);
    expect(created.checkoutUrl, isNull);
  });

  test('un cupo agotado llega como ApiException con el mensaje del servidor', () async {
    final (api, _) = build(409, {'error': 'No hay cupos suficientes.', 'code': 'SOLD_OUT'});

    expect(
      () => api.createOrder(eventId: 'e1', quantity: 4, idempotencyKey: 'e1-000000002'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
    );
  });

  test('mis compras mapea los estados del servidor', () async {
    final (api, _) = build(200, {
      'items': [_orderJson(status: 'APPROVED'), _orderJson(status: 'EXPIRED')],
    });

    final orders = await api.listMine();

    expect(orders.map((o) => o.status), [OrderStatus.approved, OrderStatus.expired]);
  });
}
