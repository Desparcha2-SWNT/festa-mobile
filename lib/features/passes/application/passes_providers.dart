import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/http_providers.dart';
import '../../auth/application/session_controller.dart';
import '../data/passes_api.dart';
import '../domain/pass.dart';

final passesApiProvider = Provider<PassesApi>((ref) => PassesApi(ref.watch(authenticatedDioProvider)));

/// Las entradas de la cuenta de la sesión. `autoDispose` y atado a la cuenta: otra persona que entre
/// en el mismo teléfono no ve los QR de la anterior.
final myPassesProvider = FutureProvider.autoDispose<List<Pass>>((ref) {
  ref.watch(sessionControllerProvider.select((session) => session.value?.id));
  return ref.watch(passesApiProvider).mine();
}, retry: retryPasses);

/// Un 4xx no cambia reintentando; un error de red o del servidor se reintenta dos veces.
Duration? retryPasses(int retryCount, Object error) {
  final status = error is ApiException ? error.statusCode : null;
  if (status != null && status >= 400 && status < 500) return null;
  if (retryCount >= 2) return null;
  return Duration(milliseconds: 300 * (retryCount + 1));
}
