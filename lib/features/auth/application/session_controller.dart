import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../merchant/application/merchant_providers.dart';
import '../../merchant/domain/merchant_profile.dart';
import '../../passes/data/passes_cache.dart';
import '../domain/account.dart';
import 'auth_providers.dart';

/// Estado de la sesión para toda la app: `null` si no hay usuario autenticado.
///
/// Al construirse intenta recuperar la sesión guardada, así el usuario no tiene que
/// iniciar sesión cada vez que abre la app.
final sessionControllerProvider = AsyncNotifierProvider<SessionController, Account?>(SessionController.new);

class SessionController extends AsyncNotifier<Account?> {
  @override
  Future<Account?> build() async {
    final repository = ref.watch(authRepositoryProvider);
    final subscription = repository.sessionExpired.listen((_) => state = const AsyncData(null));
    ref.onDispose(subscription.cancel);

    try {
      return await repository.restore();
    } on ApiException {
      // Sin red al abrir la app: se muestra el login y el token sigue guardado para el próximo intento.
      return null;
    }
  }

  /// Lanza [ApiException] si el servidor rechaza el registro; la pantalla muestra el mensaje.
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required AccountType accountType,
    required bool acceptedPrivacyPolicy,
  }) async {
    final account = await ref
        .read(authRepositoryProvider)
        .register(
          email: email,
          password: password,
          displayName: displayName,
          accountType: accountType,
          acceptedPrivacyPolicy: acceptedPrivacyPolicy,
        );
    _signedIn(account);
  }

  Account? _unpublishedMerchant;

  /// Registro de comercio en dos llamadas: crea la cuenta en auth-service y envía la solicitud a
  /// user-service. La sesión se publica solo cuando la solicitud queda enviada, para que el router
  /// no saque al usuario del registro a mitad de camino. Si la solicitud falla, la cuenta ya existe:
  /// al reintentar se omite el registro y solo se reenvía la solicitud.
  Future<void> registerMerchant({
    required String email,
    required String password,
    required MerchantDraft draft,
    required bool acceptedPrivacyPolicy,
  }) async {
    _unpublishedMerchant ??= await ref
        .read(authRepositoryProvider)
        .register(
          email: email,
          password: password,
          displayName: draft.businessName,
          accountType: AccountType.merchant,
          acceptedPrivacyPolicy: acceptedPrivacyPolicy,
        );
    await ref.read(merchantApiProvider).submit(draft);
    final account = _unpublishedMerchant!;
    _unpublishedMerchant = null;
    _signedIn(account);
  }

  /// Lanza [ApiException] si las credenciales no son válidas; la pantalla muestra el mensaje.
  Future<void> login({required String email, required String password}) async {
    final account = await ref.read(authRepositoryProvider).login(email: email, password: password);
    _signedIn(account);
  }

  Future<void> logout() async {
    final accountId = state.value?.id;
    await ref.read(authRepositoryProvider).logout();
    // Las entradas guardadas para usar sin conexión (SCRUM-91) se borran ANTES de publicar la sesión nula: si no,
    // el login podría ofrecer «Ver mis entradas guardadas» con los QR de quien acaba de salir. Con un tope de
    // tiempo para que un almacenamiento del sistema que no responde no deje la app sin cerrar sesión.
    if (accountId == null) {
      state = const AsyncData(null);
      return;
    }
    final passesCache = ref.read(passesCacheProvider);
    await _clearPasses(passesCache, accountId);
    state = const AsyncData(null);
    // Una descarga de «Mis entradas» que pasó el chequeo de la sesión mientras se borraba pudo volver a guardar
    // la copia. Con la sesión ya nula ninguna descarga nueva guarda, y el almacenamiento aplica las operaciones en
    // orden: este segundo borrado llega después de cualquier guardado tardío.
    await _clearPasses(passesCache, accountId);
  }

  static const _clearTimeout = Duration(seconds: 3);

  static Future<void> _clearPasses(PassesCache cache, String accountId) async {
    try {
      await cache.clear(accountId).timeout(_clearTimeout);
    } on Object {
      // Si no se pudo borrar, la copia sigue atada a la cuenta y se borra cuando entre otra.
    }
  }

  /// Publica la cuenta que acaba de entrar y borra las copias de «Mis entradas» de otras cuentas (SCRUM-91).
  void _signedIn(Account account) {
    state = AsyncData(account);
    unawaited(Future.sync(() => ref.read(passesCacheProvider).clearOthers(account.id)).catchError((Object _) {}));
  }
}
