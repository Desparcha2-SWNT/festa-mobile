import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/http_providers.dart';
import '../../auth/application/session_controller.dart';
import '../data/passes_api.dart';
import '../data/passes_cache.dart';
import '../domain/pass.dart';

final passesApiProvider = Provider<PassesApi>((ref) => PassesApi(ref.watch(authenticatedDioProvider)));

/// «Mis entradas» y, si vienen de la copia del teléfono, cuándo se guardaron.
class MyPasses {
  const MyPasses(this.passes, {this.offlineSince});

  final List<Pass> passes;

  /// `null` si la lista viene de booking-service; si no, la hora de la copia guardada (SCRUM-91).
  final DateTime? offlineSince;

  bool get offline => offlineSince != null;
}

/// Las entradas de la cuenta de la sesión. `autoDispose` y atado a la cuenta: otra persona que entre
/// en el mismo teléfono no ve los QR de la anterior.
///
/// SCRUM-91: cada carga buena se guarda en el teléfono. Si no hay red (o el servidor falla), se muestran
/// las entradas guardadas de esta cuenta; el QR está firmado por booking y se valida igual en la puerta.
final myPassesProvider = FutureProvider.autoDispose<MyPasses>((ref) async {
  final accountId = ref.watch(sessionControllerProvider.select((session) => session.value?.id));
  final cache = ref.watch(passesCacheProvider);
  try {
    final passes = await ref.watch(passesApiProvider).mine();
    if (accountId != null) {
      try {
        await cache.save(accountId, passes, DateTime.now());
      } on Object {
        // Si el teléfono no deja guardar, la lista igual se muestra.
      }
    }
    return MyPasses(passes);
  } on ApiException catch (e) {
    if (accountId == null || !_unreachable(e)) rethrow;
    final cached = await _readOrNull(cache, accountId);
    if (cached == null) rethrow;
    return MyPasses(cached.passes, offlineSince: cached.savedAt);
  }
}, retry: retryPasses);

/// Sin respuesta del servidor (red caída o tiempo agotado) o con un error del servidor.
bool _unreachable(ApiException e) => e.statusCode == null || e.statusCode! >= 500;

Future<CachedPasses?> _readOrNull(PassesCache cache, String accountId) async {
  try {
    return await cache.read(accountId);
  } on Object {
    return null;
  }
}

/// Un 4xx no cambia reintentando; un error de red o del servidor se reintenta dos veces.
Duration? retryPasses(int retryCount, Object error) {
  final status = error is ApiException ? error.statusCode : null;
  if (status != null && status >= 400 && status < 500) return null;
  if (retryCount >= 2) return null;
  return Duration(milliseconds: 300 * (retryCount + 1));
}
