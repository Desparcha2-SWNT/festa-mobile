/// Qué se reporta (RF14). Los valores son los que acepta user-service (`Report.TARGET_TYPES`).
enum ReportTarget {
  event('event'),
  user('user');

  const ReportTarget(this.api);

  final String api;
}

/// Motivo de un reporte. Los valores de la API son los del CHECK `chk_reports_reason` de user-service.
enum ReportReason {
  spam('spam', 'Spam o publicidad engañosa'),
  fraud('fraude', 'Fraude o estafa'),
  inappropriate('contenido_inapropiado', 'Contenido inapropiado'),
  falseInfo('informacion_falsa', 'Información falsa'),
  harassment('acoso', 'Acoso o intimidación'),
  other('otro', 'Otro motivo');

  const ReportReason(this.api, this.label);

  final String api;
  final String label;
}
