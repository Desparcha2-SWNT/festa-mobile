import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/pass.dart';

/// Las entradas guardadas en el teléfono para mostrarlas sin conexión (SCRUM-91), con la cuenta dueña
/// y la hora en que se guardaron.
class CachedPasses {
  const CachedPasses({required this.accountId, required this.passes, required this.savedAt});

  final String accountId;
  final List<Pass> passes;
  final DateTime savedAt;
}

/// Copia local de «Mis entradas» para la puerta del evento, donde muchas veces no hay señal.
abstract interface class PassesCache {
  /// Las entradas guardadas de [accountId], o `null` si no hay.
  Future<CachedPasses?> read(String accountId);

  /// Las entradas de la última cuenta que guardó en este teléfono. Sirve en el login cuando la app se abre
  /// sin señal y no puede recuperar la sesión: al cerrar sesión la copia se borra, así que si sigue aquí es
  /// de quien usaba el teléfono.
  Future<CachedPasses?> readLast();

  Future<void> save(String accountId, List<Pass> passes, DateTime savedAt);

  /// Borra la copia de [accountId]. Cada cuenta tiene su propia clave: un borrado tardío al cerrar sesión no
  /// toca la copia de la cuenta que entra después.
  Future<void> clear(String accountId);
}

final passesCacheProvider = Provider<PassesCache>((ref) => const SecurePassesCache());

/// El QR es lo que deja entrar al evento: se guarda en el almacenamiento seguro del sistema
/// (Keychain / Keystore), no en SharedPreferences. Solo se guardan las entradas que se pueden mostrar.
class SecurePassesCache implements PassesCache {
  const SecurePassesCache([this._storage = const FlutterSecureStorage()]);

  static const _prefix = 'festa.passes_cache.v1';
  static const _lastKey = '$_prefix.last';

  static String keyFor(String accountId) => '$_prefix.account.$accountId';

  final FlutterSecureStorage _storage;

  @override
  Future<CachedPasses?> read(String accountId) async {
    final raw = await _storage.read(key: keyFor(accountId));
    final cached = raw == null ? null : decode(raw);
    return cached?.accountId == accountId ? cached : null;
  }

  @override
  Future<CachedPasses?> readLast() async {
    final accountId = await _storage.read(key: _lastKey);
    return accountId == null ? null : read(accountId);
  }

  @override
  Future<void> save(String accountId, List<Pass> passes, DateTime savedAt) async {
    await _storage.write(key: keyFor(accountId), value: encode(accountId, passes, savedAt));
    await _storage.write(key: _lastKey, value: accountId);
  }

  @override
  Future<void> clear(String accountId) => _storage.delete(key: keyFor(accountId));

  static String encode(String accountId, List<Pass> passes, DateTime savedAt) => jsonEncode({
    'accountId': accountId,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'items': [
      for (final pass in passes)
        if (pass.usable) pass.toJson(),
    ],
  });

  /// `null` si lo guardado no se puede leer (por ejemplo, de una versión anterior de la app).
  static CachedPasses? decode(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return CachedPasses(
        accountId: json['accountId'] as String,
        savedAt: DateTime.parse(json['savedAt'] as String),
        passes: [for (final item in json['items'] as List<dynamic>) Pass.fromJson(item as Map<String, dynamic>)],
      );
    } on Object {
      return null;
    }
  }
}
