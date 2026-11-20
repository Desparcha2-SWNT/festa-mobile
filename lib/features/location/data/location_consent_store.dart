import 'package:shared_preferences/shared_preferences.dart';

import '../domain/location_consent.dart';

/// Guarda en el dispositivo la decisión de cada cuenta sobre su ubicación, para no volver a
/// preguntarla cada vez que se abre la app.
abstract interface class LocationConsentStore {
  Future<StoredLocationConsent?> read(String accountId);
  Future<void> save(String accountId, StoredLocationConsent consent);
}

/// La decisión no es un secreto, así que basta con SharedPreferences.
class SharedPreferencesLocationConsentStore implements LocationConsentStore {
  SharedPreferencesLocationConsentStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  // Decisión y sincronización van en una sola clave: una escritura no puede dejar la decisión nueva
  // con la marca de sincronizada de la anterior (si la app se cierra entre dos escrituras).
  static String _key(String accountId) => 'festa.location_consent.$accountId';

  // Claves de la versión anterior (dos escrituras), que se leen una vez para no perder la decisión.
  static String _legacyDecisionKey(String accountId) => 'festa.location_consent.$accountId.decision';
  static String _legacySyncedKey(String accountId) => 'festa.location_consent.$accountId.synced';

  @override
  Future<StoredLocationConsent?> read(String accountId) async {
    final raw = await _preferences.getString(_key(accountId));
    if (raw != null) {
      final parts = raw.split(':');
      final consent = LocationConsent.values.where((c) => c.name == parts.first).firstOrNull;
      if (consent == null) return null;
      return StoredLocationConsent(decision: consent, synced: parts.length > 1 && parts[1] == 'synced');
    }
    final legacy = await _preferences.getString(_legacyDecisionKey(accountId));
    final consent = LocationConsent.values.where((c) => c.name == legacy).firstOrNull;
    if (consent == null) return null;
    final synced = await _preferences.getBool(_legacySyncedKey(accountId)) ?? false;
    return StoredLocationConsent(decision: consent, synced: synced);
  }

  @override
  Future<void> save(String accountId, StoredLocationConsent consent) =>
      _preferences.setString(_key(accountId), '${consent.decision.name}:${consent.synced ? 'synced' : 'pending'}');
}
