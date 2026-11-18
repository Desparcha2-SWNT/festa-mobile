import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/attendees/application/attendees_providers.dart';
import 'package:festa/features/attendees/presentation/attendee_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('retryAttendees', () {
    const forbidden = ApiException(code: 'not_organizer', message: 'x', statusCode: 403);
    const notFound = ApiException(code: 'not_found', message: 'x', statusCode: 404);
    const offline = ApiException(code: ApiException.networkError, message: 'x');

    test('no reintenta un 403 ni un 404', () {
      expect(retryAttendees(0, forbidden), isNull);
      expect(retryAttendees(0, notFound), isNull);
    });

    test('reintenta un error de red dos veces, cada vez con más espera', () {
      expect(retryAttendees(0, offline), const Duration(milliseconds: 300));
      expect(retryAttendees(1, offline), const Duration(milliseconds: 600));
      expect(retryAttendees(2, offline), isNull);
    });
  });

  test('la hora de confirmación se muestra en formato de 12 horas', () {
    expect(formatConfirmedAt(DateTime(2026, 1, 3, 0, 7)), '3 ene, 12:07 a. m.');
    expect(formatConfirmedAt(DateTime(2026, 12, 31, 12, 30)), '31 dic, 12:30 p. m.');
  });
}
