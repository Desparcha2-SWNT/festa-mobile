/// Estado de un pase en booking-service.
enum PassStatus {
  valid,
  used,
  revoked;

  static PassStatus fromApi(String? value) => switch (value) {
    'used' => used,
    'revoked' => revoked,
    _ => valid,
  };
}

/// Una entrada del usuario (`GET /api/bookings/passes/mine`): una por asistencia gratis y una por boleta.
class Pass {
  const Pass({
    required this.passId,
    required this.eventId,
    required this.eventTitle,
    required this.status,
    required this.ticket,
    this.eventStartsAt,
    this.eventEndsAt,
    this.usedAt,
    this.qr,
  });

  factory Pass.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) => json[key] is String ? DateTime.parse(json[key] as String) : null;
    return Pass(
      passId: json['passId'] as String,
      eventId: json['eventId'] as String,
      eventTitle: json['eventTitle'] as String? ?? '',
      status: PassStatus.fromApi(json['status'] as String?),
      ticket: json['source'] == 'ticket',
      eventStartsAt: date('eventStartsAt'),
      eventEndsAt: date('eventEndsAt'),
      usedAt: date('usedAt'),
      qr: json['qr'] as String?,
    );
  }

  final String passId;
  final String eventId;
  final String eventTitle;
  final PassStatus status;

  /// `true` si viene de una boleta comprada; `false` si es una asistencia gratis.
  final bool ticket;
  final DateTime? eventStartsAt;
  final DateTime? eventEndsAt;
  final DateTime? usedAt;

  /// El texto firmado que se escanea en la entrada. Booking solo lo manda en un pase vigente.
  final String? qr;

  /// El mismo formato que manda booking, para guardarlo en el teléfono (SCRUM-91).
  Map<String, dynamic> toJson() => {
    'passId': passId,
    'eventId': eventId,
    'eventTitle': eventTitle,
    'status': status.name,
    'source': ticket ? 'ticket' : 'rsvp',
    'eventStartsAt': eventStartsAt?.toUtc().toIso8601String(),
    'eventEndsAt': eventEndsAt?.toUtc().toIso8601String(),
    'usedAt': usedAt?.toUtc().toIso8601String(),
    'qr': qr,
  };

  bool get eventEnded => eventEndsAt != null && eventEndsAt!.isBefore(DateTime.now());

  /// Se puede mostrar en la entrada: vigente, con QR y de un evento que no ha terminado.
  bool get usable => status == PassStatus.valid && qr != null && !eventEnded;
}
