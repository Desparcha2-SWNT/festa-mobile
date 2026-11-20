import 'dart:convert';

import 'package:festa/features/location/domain/geo_point.dart';
import 'package:festa/features/map/presentation/map_view.dart';
import 'package:festa/features/map/presentation/markers_geojson.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada marcador es un punto GeoJSON (lng, lat) con su id y su color en hexadecimal', () {
    final geoJson = markersGeoJson(const [
      MapMarker(id: 'e1', point: GeoPoint(latitude: 4.78, longitude: -74.04), color: Color(0xFFF0127E)),
    ]);

    final collection = jsonDecode(geoJson) as Map<String, dynamic>;
    final feature = (collection['features'] as List<dynamic>).single as Map<String, dynamic>;
    expect(collection['type'], 'FeatureCollection');
    expect(feature['geometry'], {
      'type': 'Point',
      'coordinates': [-74.04, 4.78],
    });
    expect(feature['properties'], {'id': 'e1', 'color': '#f0127e'});
  });

  test('sin eventos la colección queda vacía', () {
    expect(jsonDecode(markersGeoJson(const [])), {'type': 'FeatureCollection', 'features': <Object>[]});
  });
}
