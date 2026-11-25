import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/http_providers.dart';
import '../data/team_merchants_api.dart';
import '../domain/pending_merchant.dart';

final teamMerchantsApiProvider = Provider<TeamMerchantsApi>(
  (ref) => TeamMerchantsApi(ref.watch(authenticatedDioProvider)),
);

/// Comercios por verificar. Se vuelve a pedir después de aprobar o rechazar uno. Sin reintentos automáticos:
/// si falla, la pantalla muestra el error con un botón para reintentar.
final pendingMerchantsProvider = FutureProvider.autoDispose<List<PendingMerchant>>(
  (ref) => ref.watch(teamMerchantsApiProvider).pending(),
  retry: (_, _) => null,
);
