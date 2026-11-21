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

  /// Cambia con cada inicio o cierre de sesión (no con una renovación). Una renovación solo se aplica si la sesión
  /// con la que empezó sigue siendo la vigente: si no, restauraría los tokens de una cuenta que ya salió.
  int _epoch = 0;

  String? get accessToken => _session?.accessToken;

  /// Cuenta de la sesión vigente. Una petición se anota con ella al salir para saber, si llega un 401, si la
  /// sesión sigue siendo la misma (ver `AuthInterceptor`).
  String? get accountId => _session?.account.id;

  /// Emite cuando la sesión deja de ser válida sin que el usuario cerrara sesión
  /// (refresh vencido, revocado o reusado).
  Stream<void> get sessionExpired => _sessionExpired.stream;

  Future<Account> register({
    required String email,
    required String password,
    required String displayName,
    required AccountType accountType,
    // acceptedPrivacyPolicy: se valida en la UI (Ley 1581) pero no se envía al backend.
    required bool acceptedPrivacyPolicy,
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
  Future<AuthSession?> refresh() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    late final Future<AuthSession?> renewal;
    renewal = _doRefresh().whenComplete(() {
      if (identical(_refreshInFlight, renewal)) _refreshInFlight = null;
    });
    return _refreshInFlight = renewal;
  }

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
    final epoch = _epoch;
    final refreshToken = _session?.refreshToken ?? await _storage.readRefreshToken();
    if (refreshToken == null) return null;
    try {
      final session = await _api.refresh(refreshToken);
      // Otra cuenta (o ninguna) tomó la sesión mientras se renovaba: este resultado ya no es de nadie y aplicarlo
      // sustituiría los tokens vigentes por los de la cuenta anterior.
      if (_epoch != epoch) return null;
      await _start(session, renewal: true);
      return session;
    } on ApiException catch (e) {
      if (_epoch != epoch) return null; // el fallo es de la sesión anterior: no cierra la nueva
      // Un error de red no invalida la sesión: el token sigue guardado para el próximo intento.
      if (e.code == ApiException.networkError) rethrow;
      await _clear();
      _sessionExpired.add(null);
      return null;
    }
  }

  Future<Account> _start(AuthSession session, {bool renewal = false}) async {
    if (!renewal) {
      _epoch++; // inicio de sesión: invalida lo que una renovación anterior en vuelo pudiera aplicar
      _refreshInFlight = null;
    }
    _session = session;
    await _storage.saveRefreshToken(session.refreshToken);
    return session.account;
  }

  Future<void> _clear() async {
    _epoch++;
    _refreshInFlight = null;
    _session = null;
    await _storage.clear();
  }
}
