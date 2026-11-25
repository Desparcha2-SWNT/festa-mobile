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
  /// Las entradas guardadas de [accountId], o `null` si no hay o son de otra cuenta.
  Future<CachedPasses?> read(String accountId);
  Future<void> save(String accountId, List<Pass> passes, DateTime savedAt);
  Future<void> clear();
}

final passesCacheProvider = Provider<PassesCache>((ref) => const SecurePassesCache());

/// El QR es lo que deja entrar al evento: se guarda en el almacenamiento seguro del sistema
/// (Keychain / Keystore), no en SharedPreferences. Solo se guardan las entradas que se pueden mostrar.
class SecurePassesCache implements PassesCache {
  const SecurePassesCache([this._storage = const FlutterSecureStorage()]);

  static const _key = 'festa.passes_cache.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<CachedPasses?> read(String accountId) async {
    final raw = await _storage.read(key: _key);
    final cached = raw == null ? null : decode(raw);
    return cached?.accountId == accountId ? cached : null;
  }

  @override
  Future<void> save(String accountId, List<Pass> passes, DateTime savedAt) =>
      _storage.write(key: _key, value: encode(accountId, passes, savedAt));

  @override
  Future<void> clear() => _storage.delete(key: _key);

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
