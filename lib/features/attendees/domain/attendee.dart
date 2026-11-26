/// Cómo llegó la persona al evento: RSVP gratis o compra de boletas.
enum AttendanceSource {
  rsvp,
  ticket;

  static AttendanceSource fromApi(String? value) => value == 'ticket' ? ticket : rsvp;
}

/// Una asistencia confirmada, tal como la devuelve `GET /api/bookings/events/:id/attendees`.
class Attendee {
  const Attendee({
    required this.attendanceId,
    required this.source,
    required this.tickets,
    required this.checkedIn,
    required this.confirmedAt,
    this.displayName,
  });

  factory Attendee.fromJson(Map<String, dynamic> json) => Attendee(
    attendanceId: json['attendanceId'] as String,
    displayName: json['displayName'] as String?,
    source: AttendanceSource.fromApi(json['source'] as String?),
    tickets: json['tickets'] as int? ?? 0,
    checkedIn: json['checkedIn'] as int? ?? 0,
    confirmedAt: DateTime.parse(json['confirmedAt'] as String),
  );

  final String attendanceId;

  /// `null` si booking-service aún no conoce el nombre de la persona (se registró antes del despliegue).
  final String? displayName;
  final AttendanceSource source;

  /// Pases vigentes: 1 en un RSVP; uno por boleta en una compra.
  final int tickets;

  /// Cuántos de esos pases ya se usaron en la entrada.
  final int checkedIn;
  final DateTime confirmedAt;

  bool get fullyCheckedIn => tickets > 0 && checkedIn >= tickets;
}

/// Una página de la lista, con los totales del evento.
class AttendeePage {
  const AttendeePage({
    required this.items,
    required this.total,
    required this.attendeeCount,
    required this.offset,
    this.capacity,
  });

  factory AttendeePage.fromJson(Map<String, dynamic> json) => AttendeePage(
    items: [
      for (final item in (json['items'] as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>())
        Attendee.fromJson(item),
    ],
    total: json['total'] as int? ?? 0,
    attendeeCount: json['attendeeCount'] as int? ?? 0,
    offset: json['offset'] as int? ?? 0,
    capacity: json['capacity'] as int?,
  );

  final List<Attendee> items;

  /// Asistencias confirmadas (filas). Sirve para saber si quedan páginas.
  final int total;

  /// Cupos ocupados: una compra de 3 boletas cuenta 3.
  final int attendeeCount;
  final int offset;

  /// `null` si el evento no tiene cupo máximo.
  final int? capacity;
}
