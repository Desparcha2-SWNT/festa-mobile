import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'app/festa_app.dart';
import 'core/config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.mapboxAccessToken.isNotEmpty) MapboxOptions.setAccessToken(AppConfig.mapboxAccessToken);
  runApp(const ProviderScope(child: FestaApp()));
}
