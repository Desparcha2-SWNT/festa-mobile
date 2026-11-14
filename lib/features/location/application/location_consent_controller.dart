import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../data/consents_api.dart';
import '../data/location_consent_store.dart';
import '../domain/location_consent.dart';
import 'location_providers.dart';

/// Decisión de la cuenta autenticada sobre su ubicación: `null` si aún no ha decidido (o no
/// hay sesión), en cuyo caso el router muestra la pantalla de consentimiento.
final locationConsentControllerProvider = AsyncNotifierProvider<LocationConsentController, LocationConsent?>(
  LocationConsentController.new,
);

class LocationConsentController extends AsyncNotifier<LocationConsent?> {
  @override
  Future<LocationConsent?> build() async {
    final accountId = ref.watch(sessionControllerProvider.select((session) => session.value?.id));
    if (accountId == null) return null;

    final store = ref.watch(locationConsentStoreProvider);
    final stored = await store.read(accountId);
    if (stored != null && !stored.synced) {
      unawaited(_sync(accountId, stored, store: store, api: ref.read(consentsApiProvider)));
    }
    return stored?.decision;
  }

  Future<void> grant() => _decide(LocationConsent.granted);

  Future<void> decline() => _decide(LocationConsent.declined);

  /// La decisión se guarda y aplica de inmediato; el registro en el servidor no la bloquea.
  Future<void> _decide(LocationConsent decision) async {
    final accountId = ref.read(sessionControllerProvider).value?.id;
    if (accountId == null) return;

    final store = ref.read(locationConsentStoreProvider);
    final api = ref.read(consentsApiProvider);
    final pending = StoredLocationConsent(decision: decision, synced: false);
    await store.save(accountId, pending);
    state = AsyncData(decision);
    await _sync(accountId, pending, store: store, api: api);
  }

  /// Recibe [store] y [api] ya resueltos porque puede terminar después de que el provider se
  /// reconstruya (por ejemplo, al cerrar sesión), cuando `ref` ya no se puede usar.
  static Future<void> _sync(
    String accountId,
    StoredLocationConsent consent, {
    required LocationConsentStore store,
    required ConsentsApi api,
  }) async {
    try {
      await api.recordLocationConsent(granted: consent.decision == LocationConsent.granted);
      await store.save(accountId, consent.markSynced());
    } on ApiException {
      // Queda pendiente y se reintenta la próxima vez que se abra la app.
    }
  }
}
