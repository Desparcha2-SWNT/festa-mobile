import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/http_providers.dart';
import '../data/team_merchants_api.dart';
import '../data/team_reports_api.dart';
import '../domain/pending_merchant.dart';
import '../domain/team_report.dart';

final teamMerchantsApiProvider = Provider<TeamMerchantsApi>(
  (ref) => TeamMerchantsApi(ref.watch(authenticatedDioProvider)),
);

/// Comercios por verificar. Se vuelve a pedir después de aprobar o rechazar uno. Sin reintentos automáticos:
/// si falla, la pantalla muestra el error con un botón para reintentar.
final pendingMerchantsProvider = FutureProvider.autoDispose<List<PendingMerchant>>(
  (ref) => ref.watch(teamMerchantsApiProvider).pending(),
  retry: (_, _) => null,
);

final teamReportsApiProvider = Provider<TeamReportsApi>((ref) => TeamReportsApi(ref.watch(authenticatedDioProvider)));

/// Reportes abiertos (SCRUM-110). Se vuelve a pedir después de resolver uno. Sin reintentos automáticos, como
/// los comercios: si falla, la pantalla muestra el error con un botón para reintentar.
final openReportsProvider = FutureProvider.autoDispose<List<TeamReport>>(
  (ref) => ref.watch(teamReportsApiProvider).open(),
  retry: (_, _) => null,
);

/// La cuenta reportada, para mostrar quién es en el detalle del reporte.
final reportedAccountProvider = FutureProvider.autoDispose.family<ReportedAccount, String>(
  (ref, accountId) => ref.watch(teamReportsApiProvider).account(accountId),
  retry: (_, _) => null,
);
