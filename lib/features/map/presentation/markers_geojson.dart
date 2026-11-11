import 'dart:convert';
import 'dart:ui';

import 'map_view.dart';

/// Convierte los marcadores en la FeatureCollection GeoJSON de la fuente de eventos del mapa.
///
/// Cada punto lleva su `id` (lo que se devuelve al tocarlo) y su `color` en hexadecimal, que es lo
/// que entienden las expresiones de estilo de Mapbox.
String markersGeoJson(List<MapMarker> markers) => jsonEncode({
  'type': 'FeatureCollection',
  'features': [
    for (final marker in markers)
      {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [marker.point.longitude, marker.point.latitude],
        },
        'properties': {'id': marker.id, 'color': _hex(marker.color)},
      },
  ],
});

String _hex(Color color) => '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
