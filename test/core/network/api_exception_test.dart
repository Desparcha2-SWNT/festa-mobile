import 'package:dio/dio.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _dioError({int? status, Object? data}) {
  final request = RequestOptions(path: '/api/auth/login');
  return DioException(
    requestOptions: request,
    type: status == null ? DioExceptionType.connectionError : DioExceptionType.badResponse,
    response: status == null ? null : Response<Object?>(requestOptions: request, statusCode: status, data: data),
  );
}

void main() {
  test('usa el código y el mensaje del servicio', () {
    final e = ApiException.fromDio(
      _dioError(
        status: 409,
        data: {
          'error': {'code': 'EMAIL_TAKEN', 'message': 'Ya existe una cuenta con ese correo.', 'details': null},
        },
      ),
    );

    expect(e.code, 'EMAIL_TAKEN');
    expect(e.message, 'Ya existe una cuenta con ese correo.');
    expect(e.statusCode, 409);
  });

  test('indexa los errores por campo de VALIDATION_ERROR', () {
    final e = ApiException.fromDio(
      _dioError(
        status: 400,
        data: {
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'Revisa los campos marcados.',
            'details': [
              {'field': 'password', 'message': 'Muy corta.'},
              {'field': 'email', 'message': 'No es válido.'},
            ],
          },
        },
      ),
    );

    expect(e.fieldErrors, {'password': 'Muy corta.', 'email': 'No es válido.'});
  });

  test('traduce el 429 de Kong por su código de estado', () {
    final e = ApiException.fromDio(_dioError(status: 429, data: {'message': 'API rate limit exceeded'}));

    expect(e.code, ApiException.tooManyRequests);
  });

  test('reporta error de red cuando no hay respuesta', () {
    expect(ApiException.fromDio(_dioError()).code, ApiException.networkError);
  });
}
