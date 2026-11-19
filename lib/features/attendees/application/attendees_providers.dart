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
  bool _loadingMore = false;

  @override
  Future<AttendeesState> build() async {
    final page = await ref.watch(attendeesApiProvider).list(eventId);
    return AttendeesState(
      items: page.items,
      total: page.total,
      attendeeCount: page.attendeeCount,
      capacity: page.capacity,
    );
  }

  /// Trae la siguiente página. Si falla, se conserva lo ya cargado y el error sube a la pantalla.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final page = await ref.read(attendeesApiProvider).list(eventId, offset: current.items.length);
      state = AsyncData(
        AttendeesState(
          items: [...current.items, ...page.items],
          total: page.total,
          attendeeCount: page.attendeeCount,
          capacity: page.capacity,
        ),
      );
    } finally {
      _loadingMore = false;
    }
  }
}
