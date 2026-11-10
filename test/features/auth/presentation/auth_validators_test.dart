import 'package:festa/features/auth/presentation/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('email', () {
    test('acepta un correo válido', () => expect(AuthValidators.email(' ana@escuelaing.edu.co '), isNull));
    test('rechaza vacío', () => expect(AuthValidators.email(''), isNotNull));
    test('rechaza sin dominio', () => expect(AuthValidators.email('ana@'), isNotNull));
  });

  group('newPassword (mismas reglas que auth-service)', () {
    test('acepta 8 caracteres con letra y número', () => expect(AuthValidators.newPassword('festa123'), isNull));
    test('acepta letras con tilde', () => expect(AuthValidators.newPassword('canción12'), isNull));
    test('rechaza menos de 8', () => expect(AuthValidators.newPassword('abc123'), isNotNull));
    test('rechaza sin número', () => expect(AuthValidators.newPassword('soloLetras'), isNotNull));
    test('rechaza sin letra', () => expect(AuthValidators.newPassword('12345678'), isNotNull));
    test('rechaza más de 72', () => expect(AuthValidators.newPassword('a1' * 37), isNotNull));
  });

  test('confirmPassword exige que coincidan', () {
    final validator = AuthValidators.confirmPassword(() => 'festa123');
    expect(validator('festa123'), isNull);
    expect(validator('festa124'), isNotNull);
  });

  test('displayName exige entre 2 y 80 caracteres', () {
    expect(AuthValidators.displayName('Ana'), isNull);
    expect(AuthValidators.displayName(' A '), isNotNull);
    expect(AuthValidators.displayName('a' * 81), isNotNull);
  });
}
