import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el refresh token en el almacenamiento seguro del sistema (Keychain / Keystore).
///
/// El access token no se persiste: dura poco y se obtiene de nuevo con el refresh.
abstract interface class TokenStorage {
  Future<String?> readRefreshToken();
  Future<void> saveRefreshToken(String token);
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage([this._storage = const FlutterSecureStorage()]);

  static const _refreshTokenKey = 'festa.refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  @override
  Future<void> saveRefreshToken(String token) => _storage.write(key: _refreshTokenKey, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _refreshTokenKey);
}
