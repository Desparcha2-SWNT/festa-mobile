import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_config.dart';

/// Versión de la app instalada, para que quien reporte un problema pueda decir qué APK tiene.
///
/// La versión y el número de compilación salen del APK instalado (`version` de `pubspec.yaml`).
/// La compilación del CD y el commit se graban al compilar el release (`APP_BUILD` y `APP_COMMIT`),
/// y coinciden con el tag del release en GitHub (`mobile-v<versión>-<compilación>`). En un build local
/// esos dos datos van vacíos y no se muestran.
class AppVersion {
  const AppVersion({required this.version, required this.buildNumber, this.buildRun = '', this.commit = ''});

  final String version;
  final String buildNumber;

  /// Número de ejecución del flujo de CD que compiló el APK. Vacío en builds locales.
  final String buildRun;

  /// Commit completo del que salió el APK. Vacío en builds locales.
  final String commit;

  /// Texto para mostrar, por ejemplo «Versión 0.1.0+1 · compilación 9 · a1b2c3d».
  String get label {
    final parts = ['Versión $version+$buildNumber'];
    if (buildRun.isNotEmpty) parts.add('compilación $buildRun');
    if (commit.isNotEmpty) parts.add(commit.length > 7 ? commit.substring(0, 7) : commit);
    return parts.join(' · ');
  }
}

final appVersionProvider = FutureProvider<AppVersion>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppVersion(
    version: info.version,
    buildNumber: info.buildNumber,
    buildRun: AppConfig.buildRun,
    commit: AppConfig.commit,
  );
});
