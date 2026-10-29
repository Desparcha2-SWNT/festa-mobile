import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
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
  }) async {
    final account = await ref
        .read(authRepositoryProvider)
        .register(email: email, password: password, displayName: displayName, accountType: accountType);
    state = AsyncData(account);
  }

  /// Lanza [ApiException] si las credenciales no son válidas; la pantalla muestra el mensaje.
  Future<void> login({required String email, required String password}) async {
    final account = await ref.read(authRepositoryProvider).login(email: email, password: password);
    state = AsyncData(account);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}
