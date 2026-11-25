import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/http_providers.dart';
import '../data/dashboard_api.dart';
import '../domain/merchant_dashboard.dart';

final dashboardApiProvider = Provider<DashboardApi>((ref) => DashboardApi(ref.watch(authenticatedDioProvider)));

/// Números del comercio. `autoDispose`: al salir de la pantalla se descartan, así otra cuenta que entre en el
/// mismo teléfono no ve los de la anterior, y al volver se recargan. Sin reintento automático de Riverpod:
/// ante un error la pantalla muestra «Reintentar» de una vez.
final merchantDashboardProvider = FutureProvider.autoDispose<MerchantDashboard>(
  (ref) => ref.watch(dashboardApiProvider).mine(),
  retry: (_, _) => null,
);
