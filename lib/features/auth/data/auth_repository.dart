import 'dart:async';

import '../../../core/network/api_exception.dart';
import '../domain/account.dart';
import '../domain/auth_session.dart';
import 'auth_api.dart';
import 'token_storage.dart';

/// Dueño de la sesión: guarda los tokens, los renueva y avisa cuando la sesión se pierde.
///
/// Es la única pieza que conoce los tokens; el resto de la app solo ve la [Account].
class AuthRepository {
  AuthRepository({required this._api, required this._storage});

  final AuthApi _api;
  final TokenStorage _storage;
  final _sessionExpired = StreamController<void>.broadcast();

  AuthSession? _session;
  Future<AuthSession?>? _refreshInFlight;

  String? get accessToken => _session?.accessToken;

  /// Emite cuando la sesión deja de ser válida sin que el usuario cerrara sesión
  /// (refresh vencido, revocado o reusado).
  Stream<void> get sessionExpired => _sessionExpired.stream;

  Future<Account> register({
    required String email,
    required String password,
    required String displayName,
    required AccountType accountType,
  }) async {
    final session = await _api.register(
      email: email,
      password: password,
      displayName: displayName,
      accountType: accountType,
    );
    return _start(session);
  }

  Future<Account> login({required String email, required String password}) async {
    final session = await _api.login(email: email, password: password);
    return _start(session);
  }

  /// Recupera la sesión guardada al abrir la app. Devuelve `null` si no hay sesión válida.
  Future<Account?> restore() async {
    if (await _storage.readRefreshToken() == null) return null;
    final session = await refresh();
    return session?.account;
  }

  /// Renueva los tokens. Las llamadas concurrentes comparten la misma petición: el refresh
  /// rota en cada uso y si se usara dos veces el servidor revocaría toda la sesión.
  Future<AuthSession?> refresh() => _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);

  /// Cierra la sesión en el servidor (mejor esfuerzo) y siempre la borra del dispositivo.
  Future<void> logout() async {
    final refreshToken = _session?.refreshToken ?? await _storage.readRefreshToken();
    await _clear();
    if (refreshToken == null) return;
    try {
      await _api.logout(refreshToken);
    } on ApiException {
      // Sin red o sesión ya revocada: localmente ya no hay sesión, que es lo que importa.
    }
  }

  Future<void> dispose() => _sessionExpired.close();

  Future<AuthSession?> _doRefresh() async {
    final refreshToken = _session?.refreshToken ?? await _storage.readRefreshToken();
    if (refreshToken == null) return null;
    try {
      final session = await _api.refresh(refreshToken);
      await _start(session);
      return session;
    } on ApiException catch (e) {
      // Un error de red no invalida la sesión: el token sigue guardado para el próximo intento.
      if (e.code == ApiException.networkError) rethrow;
      await _clear();
      _sessionExpired.add(null);
      return null;
    }
  }

  Future<Account> _start(AuthSession session) async {
    _session = session;
    await _storage.saveRefreshToken(session.refreshToken);
    return session.account;
  }

  Future<void> _clear() async {
    _session = null;
    await _storage.clear();
  }
}
