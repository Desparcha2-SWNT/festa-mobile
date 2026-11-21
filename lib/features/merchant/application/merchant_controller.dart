import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_controller.dart';
import '../../auth/domain/account.dart';
import '../domain/merchant_profile.dart';
import 'merchant_providers.dart';

/// Perfil de comercio de la cuenta autenticada (RF3).
///
/// `null` si la cuenta no es de comercio o si todavía no envió su perfil; el router distingue
/// los dos casos con el rol de la cuenta.
final merchantControllerProvider = AsyncNotifierProvider<MerchantController, MerchantProfile?>(
  MerchantController.new,
  // Si falla, la pantalla de estado lo muestra con un botón para reintentar; sin reintentos
  // automáticos que dejen la app cargando mientras tanto.
  retry: (_, _) => null,
);

class MerchantController extends AsyncNotifier<MerchantProfile?> {
  @override
  Future<MerchantProfile?> build() async {
    // Depende de la cuenta (id y rol), no solo del rol: si un comercio cierra sesión y entra otro,
    // el perfil se vuelve a pedir y nunca se muestra el del anterior. Riverpod descarta la respuesta
    // de una consulta vieja que llegue después del cambio de cuenta.
    final account = ref.watch(
      sessionControllerProvider.select((session) => (id: session.value?.id, role: session.value?.role)),
    );
    if (account.id == null || account.role != Role.merchant) return null;
    return ref.watch(merchantApiProvider).mine();
  }

  /// Envía el perfil por primera vez o lo corrige. Lanza `ApiException` si el servidor lo rechaza;
  /// la pantalla muestra el mensaje.
  Future<void> save(MerchantDraft draft) async {
    final api = ref.read(merchantApiProvider);
    final accountId = ref.read(sessionControllerProvider).value?.id;
    final profile = state.value == null ? await api.submit(draft) : await api.update(draft);
    // La respuesta es de la cuenta que envió el perfil: si la sesión cambió mientras tanto (o el
    // controlador se descartó), mostrarla pisaría el perfil de la cuenta nueva.
    if (!ref.mounted || ref.read(sessionControllerProvider).value?.id != accountId) return;
    state = AsyncData(profile);
  }

  /// Vuelve a consultar el estado (por ejemplo, para ver si el equipo Festa ya lo revisó).
  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }
}
