import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/http_providers.dart';
import '../data/orders_api.dart';
import '../domain/order.dart';

final ordersApiProvider = Provider<OrdersApi>((ref) => OrdersApi(ref.watch(authenticatedDioProvider)));

/// Abre el checkout de Wompi en el navegador (nunca datos de tarjeta dentro de Festa). Se inyecta para
/// poder probarlo sin abrir nada.
final checkoutLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);

/// Mis compras. Se invalida después de abrir un pago para reflejar su estado.
final myOrdersProvider = FutureProvider.autoDispose<List<Order>>(
  (ref) => ref.watch(ordersApiProvider).listMine(),
  retry: (_, _) => null,
);
