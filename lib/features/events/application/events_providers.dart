import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/http_providers.dart';
import '../../auth/application/session_controller.dart';
import '../../location/application/user_location_provider.dart';
import '../data/events_api.dart';
import '../data/explore_cache.dart';
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

final exploreCacheProvider = Provider<ExploreCache>((ref) => SharedPreferencesExploreCache());

/// Lo que muestra el mapa: los eventos cercanos y, si llegaron del teléfono por falta de red, desde cuándo.
class ExploreEvents {
  const ExploreEvents({required this.events, this.offlineSince});

  final List<Event> events;

  /// Hora en que se guardó el listado que se muestra sin conexión; `null` si viene del gateway.
  final DateTime? offlineSince;
}

/// SCRUM-140: con red, los eventos cercanos y se guardan en el teléfono; sin red, el último listado
/// guardado. Otros errores (o sin red y sin nada guardado) llegan a la pantalla como antes.
///
/// Límite: funciona con la app ya abierta y con sesión. En un arranque en frío sin red, la sesión no se puede
/// restaurar (renovar el token exige red) y el router lleva al login antes de construir el mapa, así que la
/// caché no se lee. Ofrecerla ahí exigiría un acceso de solo lectura sin sesión, una decisión de producto aparte.
final exploreEventsProvider = FutureProvider<ExploreEvents>((ref) async {
  final cache = ref.watch(exploreCacheProvider);
  try {
    final events = await ref.watch(nearbyEventsProvider.future);
    try {
      await cache.save(events, DateTime.now());
    } on Object {
      // Si no se puede guardar, el mapa igual muestra lo que llegó.
    }
    return ExploreEvents(events: events);
  } on ApiException catch (e) {
    if (e.code != ApiException.networkError) rethrow;
    CachedEvents? cached;
    try {
      cached = await cache.read();
    } on Object {
      cached = null;
    }
    if (cached == null) rethrow;
    return ExploreEvents(events: cached.events, offlineSince: cached.savedAt);
  }
}, retry: _noRetry);

/// Eventos que creó el usuario («Mis eventos»). Se invalida al crear, editar o cancelar uno.
/// Depende de la cuenta activa: si otra cuenta entra en el mismo `ProviderScope`, no se sirve la
/// lista cacheada de la anterior (podría tener eventos privados de otro comercio).
final myEventsProvider = FutureProvider<List<Event>>((ref) {
  ref.watch(sessionControllerProvider.select((session) => session.value?.id));
  return ref.watch(eventsApiProvider).mine();
}, retry: _noRetry);

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
