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
    final role = ref.watch(sessionControllerProvider.select((session) => session.value?.role));
    if (role != Role.merchant) return null;
    return ref.watch(merchantApiProvider).mine();
  }

  /// Envía el perfil por primera vez o lo corrige. Lanza `ApiException` si el servidor lo rechaza;
  /// la pantalla muestra el mensaje.
  Future<void> save(MerchantDraft draft) async {
    final api = ref.read(merchantApiProvider);
    final profile = state.value == null ? await api.submit(draft) : await api.update(draft);
    state = AsyncData(profile);
  }

  /// Vuelve a consultar el estado (por ejemplo, para ver si el equipo Festa ya lo revisó).
  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }
}
