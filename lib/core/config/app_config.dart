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

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
