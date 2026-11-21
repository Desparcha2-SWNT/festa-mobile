/// Lo que responde booking al escanear un QR en la entrada.
class CheckInResult {
  const CheckInResult({required this.valid, this.reason, this.ticket = false, this.firstUsedAt});

  factory CheckInResult.fromJson(Map<String, dynamic> json) => CheckInResult(
    valid: json['valid'] == true,
    reason: json['code'] as String?,
    ticket: json['source'] == 'ticket',
    firstUsedAt: json['firstUsedAt'] is String ? DateTime.parse(json['firstUsedAt'] as String) : null,
  );

  final bool valid;

  /// Motivo del rechazo: `already_used`, `invalid_signature`, `wrong_event`, `revoked`, `outside_window`
  /// o `not_organizer`. `null` si la entrada es válida.
  final String? reason;

  /// `true` si la entrada es una boleta comprada; `false` si es una asistencia gratis.
  final bool ticket;

  /// Cuándo se usó la entrada por primera vez, si ya se había usado.
  final DateTime? firstUsedAt;

  /// Texto para quien está en la puerta.
  String get message => switch (reason) {
    null => ticket ? 'Boleta válida' : 'Asistencia válida',
    'already_used' => 'Este QR ya se usó',
    'wrong_event' => 'Este QR es de otro evento',
    'revoked' => 'Esta entrada fue cancelada',
    'outside_window' => 'El ingreso no está habilitado en este momento',
    'not_organizer' => 'Solo el organizador puede validar ingresos',
    _ => 'QR inválido',
  };
}
