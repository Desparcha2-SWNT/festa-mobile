/// Configuración de la app que cambia por entorno.
///
/// Se define al compilar con `--dart-define`, por ejemplo:
/// `flutter run --dart-define=API_BASE_URL=http://localhost:8000`.
abstract final class AppConfig {
  /// URL del gateway. Por defecto apunta al gateway local visto desde el emulador de Android.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');

  /// Token público de Mapbox (`pk.…`). Nunca se sube al repo: en local va en `config/dev.json`
  /// (ver README) y en el CD sale del secreto `MAPBOX_ACCESS_TOKEN`. Vacío = mapa no configurado.
  static const String mapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
