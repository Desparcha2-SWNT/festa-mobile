/// Totales de todos los eventos del comercio (RF15). Son conteos simples, no un tablero con gráficas.
class DashboardTotals {
  const DashboardTotals({
    required this.events,
    required this.attendees,
    required this.checkIns,
    required this.views,
    required this.shares,
    required this.recommendedByAi,
    required this.ticketsSold,
    required this.grossCents,
  });

  factory DashboardTotals.fromJson(Map<String, dynamic> json) => DashboardTotals(
    events: _int(json['events']),
    attendees: _int(json['attendees']),
    checkIns: _int(json['checkIns']),
    views: _int(json['views']),
    shares: _int(json['shares']),
    recommendedByAi: _int(json['recommendedByAi']),
    ticketsSold: _int(json['ticketsSold']),
    grossCents: _int(json['grossCents']),
  );

  final int events;
  final int attendees;
  final int checkIns;
  final int views;
  final int shares;
  final int recommendedByAi;
  final int ticketsSold;
  final int grossCents;
}

/// Lo que se cuenta de un evento del comercio.
class DashboardEvent {
  const DashboardEvent({
    required this.eventId,
    required this.title,
    required this.startsAt,
    required this.status,
    required this.attendees,
    required this.checkIns,
    required this.views,
    required this.ticketsSold,
    required this.grossCents,
    required this.showUpRate,
  });

  factory DashboardEvent.fromJson(Map<String, dynamic> json) => DashboardEvent(
    eventId: json['eventId'] as String,
    title: json['title'] as String? ?? 'Evento sin nombre',
    startsAt: json['startsAt'] == null ? null : DateTime.tryParse(json['startsAt'] as String),
    status: json['status'] as String?,
    attendees: _int(json['attendees']),
    checkIns: _int(json['checkIns']),
    views: _int(json['views']),
    ticketsSold: _int(json['ticketsSold']),
    grossCents: _int(json['grossCents']),
    showUpRate: (json['showUpRate'] as num?)?.toDouble(),
  );

  final String eventId;
  final String title;
  final DateTime? startsAt;
  final String? status;
  final int attendees;
  final int checkIns;
  final int views;
  final int ticketsSold;
  final int grossCents;

  /// Ingresos sobre confirmados, de 0 a 1. `null` si nadie confirmó.
  final double? showUpRate;

  bool get isCancelled => status == 'cancelled';
}

/// Respuesta de `GET /api/analytics/merchants/me`.
class MerchantDashboard {
  const MerchantDashboard({required this.totals, required this.events});

  factory MerchantDashboard.fromJson(Map<String, dynamic> json) => MerchantDashboard(
    totals: DashboardTotals.fromJson(json['totals'] as Map<String, dynamic>? ?? const {}),
    events: [
      for (final e in (json['events'] as List<dynamic>? ?? const []))
        DashboardEvent.fromJson(e as Map<String, dynamic>),
    ],
  );

  final DashboardTotals totals;
  final List<DashboardEvent> events;

  bool get isEmpty => totals.events == 0 && events.isEmpty;
}

int _int(Object? value) => (value as num?)?.toInt() ?? 0;
