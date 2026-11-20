/// Decisión del usuario sobre el uso de su ubicación (RNF5, Ley 1581).
enum LocationConsent { granted, declined }

/// Consentimiento guardado en el dispositivo.
///
/// [synced] indica si ya quedó registrado en user-service. Si el registro falló (por ejemplo,
/// sin conexión), la decisión se respeta igual y se vuelve a enviar al abrir la app.
class StoredLocationConsent {
  const StoredLocationConsent({required this.decision, required this.synced});

  final LocationConsent decision;
  final bool synced;

  StoredLocationConsent markSynced() => StoredLocationConsent(decision: decision, synced: true);
}
