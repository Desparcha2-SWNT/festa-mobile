import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/reports/data/reports_api.dart';
import 'package:festa/features/reports/domain/report.dart';
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

void main() {
  (ReportsApi, _FakeAdapter) build(int status, Object body) {
    final adapter = _FakeAdapter(status, body);
    final dio = Dio(BaseOptions(baseUrl: 'http://festa.test'))..httpClientAdapter = adapter;
    return (ReportsApi(dio), adapter);
  }

  const created = {'reportId': 'r1', 'status': 'OPEN'};

  test('envía el reporte de un evento a /api/reports con los valores de user-service', () async {
    final (api, adapter) = build(201, created);

    await api.create(
      target: ReportTarget.event,
      targetId: 'e1',
      reason: ReportReason.falseInfo,
      comment: '  La fecha no es la real.  ',
    );

    final request = adapter.seen.single;
    expect('${request.method} ${request.path}', 'POST /api/reports');
    expect(request.data, {
      'targetType': 'event',
      'targetId': 'e1',
      'reason': 'informacion_falsa',
      'comment': 'La fecha no es la real.',
    });
  });

  test('sin comentario no manda el campo', () async {
    final (api, adapter) = build(201, created);

    await api.create(target: ReportTarget.user, targetId: 'o1', reason: ReportReason.harassment, comment: '   ');

    expect(adapter.seen.single.data, {'targetType': 'user', 'targetId': 'o1', 'reason': 'acoso'});
  });

  test('los motivos coinciden con el CHECK de la tabla reports', () {
    expect(ReportReason.values.map((r) => r.api), [
      'spam',
      'fraude',
      'contenido_inapropiado',
      'informacion_falsa',
      'acoso',
      'otro',
    ]);
  });

  test('un reporte repetido llega como ApiException con el mensaje del servidor', () async {
    final (api, _) = build(409, {
      'error': {'code': 'REPORT_ALREADY_OPEN', 'message': 'Ya reportaste esto; el equipo lo está revisando'},
    });

    expect(
      () => api.create(target: ReportTarget.event, targetId: 'e1', reason: ReportReason.spam),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'REPORT_ALREADY_OPEN')
            .having((e) => e.statusCode, 'statusCode', 409),
      ),
    );
  });
}
