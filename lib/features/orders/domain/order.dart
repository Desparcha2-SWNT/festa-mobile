/// Estado de una orden de boletas (payment-service, RF11). Los valores del servidor se traducen aquí
/// para que la pantalla no dependa de cadenas sueltas.
enum OrderStatus { pending, approved, failed, expired, refunded, unknown }

OrderStatus orderStatusFromApi(String? raw) => switch (raw) {
  'PENDING' => OrderStatus.pending,
  'APPROVED' => OrderStatus.approved,
  'EXPIRED' => OrderStatus.expired,
  'REFUNDED' || 'REFUND_REQUESTED' => OrderStatus.refunded,
  'DECLINED' || 'VOIDED' || 'ERROR' => OrderStatus.failed,
  _ => OrderStatus.unknown,
};

class Order {
  const Order({
    required this.id,
    required this.eventId,
    required this.quantity,
    required this.totalCents,
    required this.currency,
    required this.status,
    this.eventTitle,
    this.expiresAt,
  });

  final String id;
  final String eventId;
  final String? eventTitle;
  final int quantity;
  final int totalCents;
  final String currency;
  final OrderStatus status;
  final DateTime? expiresAt;

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['orderId'] as String,
    eventId: json['eventId'] as String,
    eventTitle: json['eventTitle'] as String?,
    quantity: json['quantity'] as int,
    totalCents: json['totalCents'] as int,
    currency: json['currency'] as String? ?? 'COP',
    status: orderStatusFromApi(json['status'] as String?),
    expiresAt: json['expiresAt'] == null ? null : DateTime.parse(json['expiresAt'] as String),
  );
}

/// Respuesta de `POST /api/payments/orders`: la orden y, si está pendiente, la URL del checkout de Wompi.
class CheckoutOrder {
  const CheckoutOrder({required this.order, this.checkoutUrl});

  final Order order;
  final Uri? checkoutUrl;

  factory CheckoutOrder.fromJson(Map<String, dynamic> json) {
    final checkout = json['checkout'] as Map<String, dynamic>?;
    final url = checkout?['checkoutUrl'] as String?;
    return CheckoutOrder(order: Order.fromJson(json), checkoutUrl: url == null ? null : Uri.parse(url));
  }
}
