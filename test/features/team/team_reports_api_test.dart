import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/reports/domain/report.dart';
import 'package:festa/features/team/data/team_reports_api.dart';
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

/// Un `ReportResponse` abierto de user-service (sin los campos nulos: `default-property-inclusion: non_null`).
Map<String, dynamic> reportJson({String id = 'r1', String targetType = 'event', String reason = 'informacion_falsa'}) =>
    {
      'reportId': id,
      'targetType': targetType,
      'targetId': 'e1',
      'reason': reason,
      'comment': 'La fecha no es la real.',
      'status': 'OPEN',
      'reporterId': 'a1',
      'createdAt': '2026-11-25T17:00:00Z',
    };

void main() {
  (TeamReportsApi, _FakeAdapter) build(int status, Object body) {
    final adapter = _FakeAdapter(status, body);
    final dio = Dio(BaseOptions(baseUrl: 'http://festa.test'))..httpClientAdapter = adapter;
    return (TeamReportsApi(dio), adapter);
  }

  test('lee la cola de reportes abiertos de user-service', () async {
    final (api, adapter) = build(200, [
      reportJson(),
      reportJson(id: 'r2', targetType: 'user', reason: 'acoso'),
      // Un motivo que la app no conoce no rompe la lista.
      reportJson(id: 'r3', reason: 'nuevo_motivo'),
    ]);

    final reports = await api.open();

    expect('${adapter.seen.single.method} ${adapter.seen.single.path}', 'GET /api/users/admin/reports');
    expect(reports.map((r) => r.reportId), ['r1', 'r2', 'r3']);
    expect(reports[0].target, ReportTarget.event);
    expect(reports[0].reason, ReportReason.falseInfo);
    expect(reports[0].comment, 'La fecha no es la real.');
    expect(reports[0].createdAt, DateTime.utc(2026, 11, 25, 17));
    expect(reports[1].target, ReportTarget.user);
    expect(reports[1].reason, ReportReason.harassment);
    expect(reports[2].reason, ReportReason.other);
  });

  test('descartar cierra el reporte sin acción', () async {
    final (api, adapter) = build(200, {...reportJson(), 'status': 'RESOLVED', 'outcome': 'dismissed'});

    await api.dismiss('r1');

    final request = adapter.seen.single;
    expect('${request.method} ${request.path}', 'POST /api/users/admin/reports/r1/resolve');
    expect(request.data, {'outcome': 'dismissed'});
  });

  test('ocultar el evento cierra el reporte con la acción y el motivo', () async {
    final (api, adapter) = build(200, reportJson());

    await api.hideEvent('r1', reason: '  Evento falso.  ');

    final request = adapter.seen.single;
    expect('${request.method} ${request.path}', 'POST /api/users/admin/reports/r1/resolve');
    expect(request.data, {'outcome': 'action_taken', 'action': 'hide_event', 'reason': 'Evento falso.'});
  });

  test('suspender la cuenta manda la fecha de fin en UTC, y sin motivo ni fecha no manda esos campos', () async {
    final (api, adapter) = build(200, reportJson(targetType: 'user'));

    await api.suspendUser('r2', reason: 'Acoso repetido.', until: DateTime.utc(2026, 12, 2, 19));
    await api.suspendUser('r3', reason: ' ');

    expect(adapter.seen[0].path, '/api/users/admin/reports/r2/resolve');
    expect(adapter.seen[0].data, {
      'outcome': 'action_taken',
      'action': 'suspend_user',
      'reason': 'Acoso repetido.',
      'suspendedUntil': '2026-12-02T19:00:00.000Z',
    });
    expect(adapter.seen[1].data, {'outcome': 'action_taken', 'action': 'suspend_user'});
  });

  test('un reporte que ya cerró otra persona llega como ApiException 409', () async {
    final (api, _) = build(409, {
      'error': {'code': 'REPORT_ALREADY_RESOLVED', 'message': 'El reporte ya está cerrado'},
    });

    expect(
      () => api.dismiss('r1'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'REPORT_ALREADY_RESOLVED')
            .having((e) => e.statusCode, 'statusCode', 409),
      ),
    );
  });

  test('lee la cuenta reportada en auth-service', () async {
    final (api, adapter) = build(200, {
      'id': 'u1',
      'email': 'ana@escuelaing.edu.co',
      'displayName': 'Ana',
      'role': 'user',
      'status': 'suspended',
      'hasPassword': true,
      'hasGoogle': false,
      'createdAt': '2026-11-01T12:00:00Z',
    });

    final account = await api.account('u1');

    expect('${adapter.seen.single.method} ${adapter.seen.single.path}', 'GET /api/auth/admin/accounts/u1');
    expect(account.displayName, 'Ana');
    expect(account.email, 'ana@escuelaing.edu.co');
    expect(account.suspended, isTrue);
  });
}
