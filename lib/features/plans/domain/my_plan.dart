/// Pestañas de «Mis planes». El nombre es el valor de `when` en la API.
enum PlansTab { upcoming, past }

/// Estado de un plan: confirmado, o anulado porque el organizador canceló el evento.
enum PlanStatus {
  confirmed,
  eventCancelled;

  static PlanStatus fromApi(String? value) => value == 'event_cancelled' ? eventCancelled : confirmed;
}

/// Una asistencia gratis del usuario, como la devuelve `GET /api/bookings/attendances/mine`.
class MyPlan {
  const MyPlan({
    required this.attendanceId,
    required this.eventId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.venueName,
    this.coverImageUrl,
  });

  factory MyPlan.fromJson(Map<String, dynamic> json) => MyPlan(
    attendanceId: json['attendanceId'] as String,
    eventId: json['eventId'] as String,
    title: json['title'] as String? ?? '',
    startsAt: DateTime.parse(json['startsAt'] as String),
    endsAt: DateTime.parse(json['endsAt'] as String),
    status: PlanStatus.fromApi(json['status'] as String?),
    venueName: json['venueName'] as String?,
    coverImageUrl: json['coverImageUrl'] as String?,
  );

  final String attendanceId;
  final String eventId;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final PlanStatus status;

  /// `null` en eventos que booking proyectó antes de guardar el lugar y la portada.
  final String? venueName;
  final String? coverImageUrl;
}

/// Una página de una pestaña.
class MyPlansPage {
  const MyPlansPage({required this.items, required this.total, required this.offset});

  factory MyPlansPage.fromJson(Map<String, dynamic> json) => MyPlansPage(
    items: [
      for (final item in (json['items'] as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>())
        MyPlan.fromJson(item),
    ],
    total: json['total'] as int? ?? 0,
    offset: json['offset'] as int? ?? 0,
  );

  final List<MyPlan> items;
  final int total;
  final int offset;
}
