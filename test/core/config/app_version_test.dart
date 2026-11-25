import 'package:festa/core/config/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppVersion.label', () {
    test('en un build local solo muestra la versión del APK', () {
      const version = AppVersion(version: '0.1.0', buildNumber: '1');
      expect(version.label, 'Versión 0.1.0+1');
    });

    test('en un release suma la compilación del CD y el commit corto, que identifican su release', () {
      const version = AppVersion(
        version: '0.1.0',
        buildNumber: '1',
        buildRun: '9',
        commit: '0123456789abcdef0123456789abcdef01234567',
      );
      expect(version.label, 'Versión 0.1.0+1 · compilación 9 · 0123456');
    });

    test('dos releases con la misma versión se distinguen por la compilación', () {
      const a = AppVersion(version: '0.1.0', buildNumber: '1', buildRun: '6', commit: 'aaaaaaaa');
      const b = AppVersion(version: '0.1.0', buildNumber: '1', buildRun: '9', commit: 'bbbbbbbb');
      expect(a.label, isNot(b.label));
    });

    test('un commit ya corto se muestra completo', () {
      const version = AppVersion(version: '1.2.3', buildNumber: '4', commit: 'abc12');
      expect(version.label, 'Versión 1.2.3+4 · abc12');
    });
  });
}
