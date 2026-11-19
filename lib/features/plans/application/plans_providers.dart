import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/http_providers.dart';
import '../data/plans_api.dart';
import '../domain/my_plan.dart';

final plansApiProvider = Provider<PlansApi>((ref) => PlansApi(ref.watch(authenticatedDioProvider)));

/// Lo que se lleva cargado de una pestaña.
class PlansState {
  const PlansState({required this.items, required this.total});

  final List<MyPlan> items;
  final int total;

  bool get hasMore => items.length < total;
}

/// Una pestaña de «Mis planes», por páginas. `autoDispose`: al salir de la pantalla se descarta, así
/// otra cuenta que entre en el mismo teléfono no ve los planes de la anterior, y al volver se recargan.
final plansControllerProvider = AsyncNotifierProvider.autoDispose.family<PlansController, PlansState, PlansTab>(
  PlansController.new,
  retry: retryPlans,
);

/// Riverpod reintenta solo los errores. Un 4xx no cambia reintentando y se muestra de una; un error
/// de red o del servidor se reintenta dos veces antes de mostrar el botón de reintentar.
Duration? retryPlans(int retryCount, Object error) {
  final status = error is ApiException ? error.statusCode : null;
  if (status != null && status >= 400 && status < 500) return null;
  if (retryCount >= 2) return null;
  return Duration(milliseconds: 300 * (retryCount + 1));
}

class PlansController extends AsyncNotifier<PlansState> {
  PlansController(this.tab);

  final PlansTab tab;
  bool _loadingMore = false;

  /// Sube con cada carga desde cero (la primera y cada refresh). Una página que se pidió antes de un
  /// refresh trae datos viejos y se descarta al llegar.
  int _generation = 0;

  @override
  Future<PlansState> build() async {
    _generation++;
    final page = await ref.watch(plansApiProvider).list(tab);
    return PlansState(items: page.items, total: page.total);
  }

  /// Trae la siguiente página. Si falla, se conserva lo ya cargado y el error sube a la pantalla.
  /// Si mientras tanto el usuario recargó la lista, la página que llega se descarta (y su error también):
  /// pegarla sobre la lista nueva mezclaría datos viejos con los recién cargados.
  Future<void> loadMore() async {
    final current = state.value;
    // Con un refresh en curso no se pagina: la página se calcularía sobre la lista que está por cambiar.
    if (current == null || !current.hasMore || _loadingMore || state.isLoading) return;
    final generation = _generation;
    bool stale() => !ref.mounted || generation != _generation || !identical(state.value, current);
    _loadingMore = true;
    try {
      final MyPlansPage page;
      try {
        page = await ref.read(plansApiProvider).list(tab, offset: current.items.length);
      } catch (_) {
        if (stale()) return;
        rethrow;
      }
      if (stale()) return;
      state = AsyncData(PlansState(items: [...current.items, ...page.items], total: page.total));
    } finally {
      _loadingMore = false;
    }
  }
}
