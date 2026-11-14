import 'package:flutter/material.dart';

import '../domain/event.dart';

/// Color de cada categoría en el mapa y en los chips, tomado de la paleta del Figma.
extension EventCategoryColor on EventCategory {
  Color get color => switch (this) {
    EventCategory.cultural => const Color(0xFFA66CFF),
    EventCategory.musical => const Color(0xFFF0127E),
    EventCategory.deportivo => const Color(0xFF1E9E5A),
    EventCategory.gastronomico => const Color(0xFFB7791F),
  };
}
