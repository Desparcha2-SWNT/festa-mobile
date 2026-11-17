import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/http_providers.dart';
import '../../location/application/user_location_provider.dart';
import '../data/events_api.dart';
import '../domain/event.dart';

final eventsApiProvider = Provider<EventsApi>((ref) => EventsApi(ref.watch(authenticatedDioProvider)));

/// Radio de búsqueda del mapa. Valor inicial a la espera de los filtros de distancia (SCRUM-79).
const nearbyRadiusKm = 3.0;

// Los errores se muestran con un botón para reintentar; sin reintentos automáticos que dejen la
// pantalla cargando mientras tanto.
Duration? _noRetry(int _, Object _) => null;

/// Eventos cercanos a la ubicación del usuario (o a la Escuela si no hay ubicación).
final nearbyEventsProvider = FutureProvider<List<Event>>((ref) async {
  final location = await ref.watch(userLocationProvider.future);
  return ref.watch(eventsApiProvider).nearby(location.point, radiusKm: nearbyRadiusKm);
}, retry: _noRetry);

/// Eventos que creó el usuario («Mis eventos»). Se invalida al crear, editar o cancelar uno.
final myEventsProvider = FutureProvider<List<Event>>((ref) => ref.watch(eventsApiProvider).mine(), retry: _noRetry);

final eventDetailProvider = FutureProvider.family<Event, String>(
  (ref, id) => ref.watch(eventsApiProvider).byId(id),
  retry: _noRetry,
);

/// Evento elegido en el mapa: se muestra su tarjeta y la cámara va hacia él. También lo usa
/// «Ver en el mapa» desde el detalle.
final selectedEventProvider = NotifierProvider<SelectedEvent, Event?>(SelectedEvent.new);

class SelectedEvent extends Notifier<Event?> {
  @override
  Event? build() => null;

  void select(Event? event) => state = event;
}
