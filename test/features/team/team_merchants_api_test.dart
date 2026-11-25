import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/merchant/domain/merchant_profile.dart';
import 'package:festa/features/team/data/team_merchants_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responde siempre lo mismo y guarda las peticiones.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body);

  final int status;
  final Object body;
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Un `MerchantResponse` de user-service.
Map<String, dynamic> merchantJson({String id = '11111111-1111-4111-8111-111111111111', String status = 'PENDING'}) => {
  'accountId': id,
  'businessName': 'Café La Escuela',
  'category': 'GASTRONOMICO',
  'address': 'AK 45 #205-59',
  'latitude': 4.7827,
  'longitude': -74.0425,
  'description': 'Café y postres junto al bloque G.',
  'verificationStatus': status,
  'suspended': false,
  'rejectionReason': null,
  'createdAt': '2026-11-20T15:30:00Z',
  'updatedAt': '2026-11-20T15:30:00Z',
};

void main() {
  (TeamMerchantsApi, _FakeAdapter) build(int status, Object body) {
    final adapter = _FakeAdapter(status, body);
    final dio = Dio(BaseOptions(baseUrl: 'http://festa.test'))..httpClientAdapter = adapter;
    return (TeamMerchantsApi(dio), adapter);
  }

  test('lee los comercios pendientes de /api/users/admin/merchants', () async {
    final (api, adapter) = build(200, [merchantJson()]);

    final pending = await api.pending();

    expect('${adapter.seen.single.method} ${adapter.seen.single.path}', 'GET /api/users/admin/merchants');
    final merchant = pending.single;
    expect(merchant.accountId, '11111111-1111-4111-8111-111111111111');
    expect(merchant.profile.draft.businessName, 'Café La Escuela');
    expect(merchant.profile.draft.category, MerchantCategory.gastronomico);
    expect(merchant.profile.status, MerchantStatus.pending);
    expect(merchant.submittedAt, DateTime.utc(2026, 11, 20, 15, 30));
  });

  test('aprobar envía la cuenta a la ruta de aprobación', () async {
    final (api, adapter) = build(200, merchantJson(status: 'VERIFIED'));

    await api.approve('m1');

    expect('${adapter.seen.single.method} ${adapter.seen.single.path}', 'POST /api/users/admin/merchants/m1/approve');
  });

  test('rechazar envía el motivo', () async {
    final (api, adapter) = build(200, merchantJson(status: 'REJECTED'));

    await api.reject('m1', 'La dirección no coincide.');

    final request = adapter.seen.single;
    expect('${request.method} ${request.path}', 'POST /api/users/admin/merchants/m1/reject');
    expect(request.data, {'reason': 'La dirección no coincide.'});
  });

  test('una cuenta sin rol admin recibe 403 como ApiException', () async {
    final (api, _) = build(403, {'code': 'FORBIDDEN', 'message': 'No tienes permiso'});

    await expectLater(api.pending(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)));
  });
}
