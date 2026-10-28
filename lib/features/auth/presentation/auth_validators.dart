/// Validaciones del formulario. Repiten las reglas de auth-service (AuthDtos) para dar
/// respuesta inmediata; el servidor sigue siendo quien decide.
abstract final class AuthValidators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _password = RegExp(r'^(?=.*[A-Za-zÁÉÍÓÚáéíóúÑñ])(?=.*\d).{8,72}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'El correo es obligatorio.';
    if (v.length > 254 || !_email.hasMatch(v)) return 'El correo no es válido.';
    return null;
  }

  /// Para el login solo se exige que no esté vacía: las reglas de formato aplican al registro.
  static String? requiredPassword(String? value) => (value ?? '').isEmpty ? 'La contraseña es obligatoria.' : null;

  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'La contraseña es obligatoria.';
    if (!_password.hasMatch(v)) {
      return 'La contraseña debe tener entre 8 y 72 caracteres, con al menos una letra y un número.';
    }
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() password) =>
      (value) => value != password() ? 'Las contraseñas no coinciden.' : null;

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'El nombre es obligatorio.';
    if (v.length < 2 || v.length > 80) return 'El nombre debe tener entre 2 y 80 caracteres.';
    return null;
  }
}
