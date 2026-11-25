import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_config.dart';
import '../domain/event.dart';
import 'event_formatters.dart';

/// SCRUM-107 (RF13): el texto que se comparte de un evento. Lleva lo necesario para decidir si ir
/// (qué, cuándo, dónde y cuánto cuesta) y el enlace para descargar Festa.
String eventShareText(Event event) => [
  event.title,
  '📅 ${EventFormatters.schedule(event)}',
  '📍 ${[event.venueName, event.venueAddress].where((part) => part.trim().isNotEmpty).join(', ')}',
  '🎟️ ${EventFormatters.price(event)}',
  '',
  'Lo encontré en Festa, el mapa de planes de la Escuela: ${AppConfig.downloadUrl}',
].join('\n');

/// Abre el menú nativo de compartir del sistema (WhatsApp, Instagram, correo…).
abstract interface class EventSharer {
  /// [origin] es dónde está el botón en pantalla: el iPad lo necesita para ubicar el menú.
  Future<void> share(Event event, {Rect? origin});
}

final eventSharerProvider = Provider<EventSharer>((ref) => const SystemEventSharer());

class SystemEventSharer implements EventSharer {
  const SystemEventSharer();

  @override
  Future<void> share(Event event, {Rect? origin}) => SharePlus.instance.share(
    ShareParams(text: eventShareText(event), subject: event.title, sharePositionOrigin: origin),
  );
}
