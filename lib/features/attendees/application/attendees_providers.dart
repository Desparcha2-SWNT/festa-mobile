import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/http_providers.dart';
import '../data/attendees_api.dart';
import '../domain/attendee.dart';

final attendeesApiProvider = Provider<AttendeesApi>((ref) => AttendeesApi(ref.watch(authenticatedDioProvider)));

/// Lo que se lleva cargado de la lista de un evento.
class AttendeesState {
  const AttendeesState({required this.items, required this.total, required this.attendeeCount, this.capacity});

  final List<Attendee> items;
  final int total;
  final int attendeeCount;
  final int? capacity;

  bool get hasMore => items.length < total;
}

/// Lista de asistentes de un evento, por páginas. `autoDispose`: al salir de la pantalla se descarta,
/// así otra cuenta que entre en el mismo dispositivo no ve la lista cacheada de la anterior.
final attendeesControllerProvider = AsyncNotifierProvider.autoDispose
    .family<AttendeesController, AttendeesState, String>(AttendeesController.new, retry: retryAttendees);

/// Riverpod reintenta solo los errores. Un 403 o un 404 no cambian reintentando: se muestran de una;
/// un error de red se reintenta dos veces antes de mostrar el botón de reintentar.
Duration? retryAttendees(int retryCount, Object error) {
  if (error is ApiException && (error.statusCode == 403 || error.statusCode == 404)) return null;
  if (retryCount >= 2) return null;
  return Duration(milliseconds: 300 * (retryCount + 1));
}

class AttendeesController extends AsyncNotifier<AttendeesState> {
  AttendeesController(this.eventId);

  final String eventId;

  /// Sube con cada carga desde cero (la primera y cada refresh). Una página que se pidió antes de un
  /// refresh trae datos viejos y se descarta al llegar.
  int _generation = 0;

  /// Generación en la que hay una página en vuelo. Está ligada a la generación y no a un bool: una
  /// página vieja que termina después de un refresh no puede liberar ni bloquear la carga nueva.
  int? _loadingGeneration;

  @override
  Future<AttendeesState> build() async {
    _generation++;
    final page = await ref.watch(attendeesApiProvider).list(eventId);
    return AttendeesState(
      items: page.items,
      total: page.total,
      attendeeCount: page.attendeeCount,
      capacity: page.capacity,
    );
  }

  /// Trae la siguiente página. Si falla, se conserva lo ya cargado y el error sube a la pantalla.
  /// Si mientras tanto el usuario recargó la lista, la página que llega se descarta (y su error también):
  /// pegarla sobre la lista nueva mezclaría datos viejos con los recién cargados.
  Future<void> loadMore() async {
    final current = state.value;
    // Con un refresh en curso no se pagina: la página se calcularía sobre la lista que está por cambiar.
    final generation = _generation;
    if (current == null || !current.hasMore || _loadingGeneration == generation || state.isLoading) return;
    bool stale() => !ref.mounted || generation != _generation || !identical(state.value, current);
    _loadingGeneration = generation;
    try {
      final AttendeePage page;
      try {
        page = await ref.read(attendeesApiProvider).list(eventId, offset: current.items.length);
      } catch (_) {
        if (stale()) return;
        rethrow;
      }
      if (stale()) return;
      state = AsyncData(
        AttendeesState(
          items: [...current.items, ...page.items],
          total: page.total,
          attendeeCount: page.attendeeCount,
          capacity: page.capacity,
        ),
      );
    } finally {
      if (_loadingGeneration == generation) _loadingGeneration = null;
    }
  }
}
