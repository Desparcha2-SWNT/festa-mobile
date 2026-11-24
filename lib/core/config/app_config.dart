import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuración de la app que cambia por entorno.
///
/// Se define al compilar con `--dart-define`, por ejemplo:
/// `flutter run --dart-define=API_BASE_URL=http://localhost:8000`.
abstract final class AppConfig {
  /// URL del gateway. Chrome usa localhost; el emulador de Android usa el alias del host 10.0.2.2.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000',
  );

  /// Token público de Mapbox (`pk.…`). Nunca se sube al repo: en local va en `config/dev.json`
  /// (ver README) y en el CD sale del secreto `MAPBOX_ACCESS_TOKEN`. Vacío = mapa no configurado.
  static const String mapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  /// Datos del build que el CD graba en el APK de release para poder rastrearlo hasta su release.
  /// Vacíos en builds locales.
  static const String commit = String.fromEnvironment('APP_COMMIT');
  static const String buildRun = String.fromEnvironment('APP_BUILD');

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
