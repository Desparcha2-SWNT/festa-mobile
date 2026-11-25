/// Un evento que la IA recomienda. Siempre es un evento real del catálogo: ai-service valida los ids
/// contra su catálogo local antes de responder (no puede inventar eventos).
class RecommendedEvent {
  const RecommendedEvent({
    required this.eventId,
    required this.title,
    required this.category,
    required this.startsAt,
    required this.venueName,
    required this.priceCents,
    required this.isLive,
  });

  factory RecommendedEvent.fromJson(Map<String, dynamic> json) => RecommendedEvent(
    eventId: json['eventId'] as String,
    title: json['title'] as String,
    category: json['category'] as String? ?? '',
    startsAt: DateTime.parse(json['startsAt'] as String),
    venueName: json['venueName'] as String? ?? '',
    priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
    isLive: json['isLive'] as bool? ?? false,
  );

  final String eventId;
  final String title;
  final String category;
  final DateTime startsAt;
  final String venueName;
  final int priceCents;
  final bool isLive;

  bool get isFree => priceCents <= 0;
}

/// Respuesta de `POST /api/ai/chat` (RF8).
class ChatReply {
  const ChatReply({required this.sessionId, required this.reply, required this.events, required this.disclaimer});

  factory ChatReply.fromJson(Map<String, dynamic> json) => ChatReply(
    sessionId: json['sessionId'] as String,
    reply: json['reply'] as String,
    events: [
      for (final e in (json['events'] as List<dynamic>? ?? const []))
        RecommendedEvent.fromJson(e as Map<String, dynamic>),
    ],
    disclaimer: json['disclaimer'] as String? ?? defaultDisclaimer,
  );

  /// Aviso de sugerencia automatizada (RN6) que usa la pantalla si el servicio no lo manda.
  static const defaultDisclaimer =
      'Sugerencias automatizadas generadas por IA; verifica los detalles del evento antes de ir.';

  final String sessionId;
  final String reply;
  final List<RecommendedEvent> events;
  final String disclaimer;
}

enum ChatRole { user, assistant }

/// Un mensaje de la conversación, en pantalla.
class ChatMessage {
  const ChatMessage({required this.role, required this.text, this.events = const []});

  final ChatRole role;
  final String text;
  final List<RecommendedEvent> events;
}
