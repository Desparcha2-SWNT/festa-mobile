import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:festa/features/auth/data/auth_api.dart';
import 'package:festa/features/auth/domain/account.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guarda el cuerpo de la petición y responde una sesión válida.
class _CapturingAdapter implements HttpClientAdapter {
  Map<String, dynamic>? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    body = options.data as Map<String, dynamic>;
    return ResponseBody.fromString(
      jsonEncode({
        'accessToken': 'a',
        'refreshToken': 'r',
        'account': {
          'id': '6f1c2b8e-3a1d-4c3e-9b0a-1f2e3d4c5b6a',
          'email': 'ana@escuelaing.edu.co',
          'displayName': 'Ana',
          'role': 'USER',
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('el registro envía la autorización de datos que auth-service exige (SCRUM-126)', () async {
    final adapter = _CapturingAdapter();
    final api = AuthApi(Dio()..httpClientAdapter = adapter);

    await api.register(
      email: 'ana@escuelaing.edu.co',
      password: 'festa123',
      displayName: 'Ana',
      accountType: AccountType.user,
      acceptedPrivacyPolicy: true,
    );

    expect(adapter.body, containsPair('acceptedPrivacyPolicy', true));
    expect(adapter.body, containsPair('email', 'ana@escuelaing.edu.co'));
  });
}
