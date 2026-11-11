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

  static String _decisionKey(String accountId) => 'festa.location_consent.$accountId.decision';
  static String _syncedKey(String accountId) => 'festa.location_consent.$accountId.synced';

  @override
  Future<StoredLocationConsent?> read(String accountId) async {
    final decision = await _preferences.getString(_decisionKey(accountId));
    final consent = LocationConsent.values.where((c) => c.name == decision).firstOrNull;
    if (consent == null) return null;
    final synced = await _preferences.getBool(_syncedKey(accountId)) ?? false;
    return StoredLocationConsent(decision: consent, synced: synced);
  }

  @override
  Future<void> save(String accountId, StoredLocationConsent consent) async {
    await _preferences.setString(_decisionKey(accountId), consent.decision.name);
    await _preferences.setBool(_syncedKey(accountId), consent.synced);
  }
}
