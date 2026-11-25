import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/checkin/data/check_in_api.dart';
import 'package:festa/features/checkin/domain/check_in_result.dart';
import 'package:festa/features/checkin/presentation/check_in_screen.dart';
import 'package:festa/features/checkin/presentation/qr_scanner_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCheckInApi extends Mock implements CheckInApi {}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body);

  final int status;
  final Object body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
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

const _qr = 'FESTA1.pase.evento.firma';

void main() {
  late _MockCheckInApi api;

  setUp(() => api = _MockCheckInApi());

  /// Abre el escáner con una «cámara» falsa: un botón que entrega [_qr] como si se hubiera leído.
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          checkInApiProvider.overrideWithValue(api),
          qrScannerBuilderProvider.overrideWithValue(
            (onCode) => Center(
              child: TextButton(key: const Key('fakeCamera'), onPressed: () => onCode(_qr), child: const Text('leer')),
            ),
          ),
        ],
        child: const MaterialApp(home: CheckInScreen(eventId: 'e1')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scan(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('fakeCamera')));
    await tester.pumpAndSettle();
  }

  testWidgets('una entrada válida se marca en verde y se puede escanear la siguiente', (tester) async {
    when(() => api.checkIn(eventId: 'e1', qr: _qr)).thenAnswer((_) async => const CheckInResult(valid: true));

    await pump(tester);
    expect(find.text('Apunta la cámara al QR de la entrada.'), findsOneWidget);

    await scan(tester);
    expect(find.byKey(const Key('checkIn.valid')), findsOneWidget);
    expect(find.text('Asistencia válida'), findsOneWidget);

    await tester.tap(find.byKey(const Key('checkIn.next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('checkIn.hint')), findsOneWidget);
  });

  testWidgets('un QR ya usado se rechaza y dice a qué hora entró', (tester) async {
    when(() => api.checkIn(eventId: 'e1', qr: _qr)).thenAnswer(
      (_) async => CheckInResult(valid: false, reason: 'already_used', firstUsedAt: DateTime(2026, 11, 21, 15, 5)),
    );

    await pump(tester);
    await scan(tester);

    expect(find.byKey(const Key('checkIn.rejected')), findsOneWidget);
    expect(find.text('Este QR ya se usó'), findsOneWidget);
    expect(find.text('Entró a las 3:05 p. m.'), findsOneWidget);
  });

  testWidgets('mientras se muestra un resultado, otra lectura no se envía', (tester) async {
    when(() => api.checkIn(eventId: 'e1', qr: _qr)).thenAnswer((_) async => const CheckInResult(valid: true));

    await pump(tester);
    await scan(tester);
    await scan(tester);

    verify(() => api.checkIn(eventId: 'e1', qr: _qr)).called(1);
  });

  testWidgets('sin red muestra el error y deja intentar de nuevo', (tester) async {
    when(() => api.checkIn(eventId: 'e1', qr: _qr))
        .thenThrow(const ApiException(code: ApiException.networkError, message: 'No pudimos conectarnos.'));

    await pump(tester);
    await scan(tester);

    expect(find.text('No pudimos validar la entrada'), findsOneWidget);
    expect(find.text('No pudimos conectarnos.'), findsOneWidget);
    expect(find.byKey(const Key('checkIn.next')), findsOneWidget);
  });

  group('CheckInApi', () {
    (CheckInApi, _FakeAdapter) build(int status, Object body) {
      final adapter = _FakeAdapter(status, body);
      final dio = Dio(BaseOptions(baseUrl: 'http://festa.test'))..httpClientAdapter = adapter;
      return (CheckInApi(dio), adapter);
    }

    test('envía el QR y el evento, y lee una boleta válida', () async {
      final (client, adapter) = build(200, {'valid': true, 'passId': 'p1', 'source': 'ticket', 'status': 'used'});

      final result = await client.checkIn(eventId: 'e1', qr: _qr);

      expect(adapter.last!.path, '/api/bookings/passes/check-in');
      expect(adapter.last!.data, {'qr': _qr, 'eventId': 'e1'});
      expect(result.valid, isTrue);
      expect(result.message, 'Boleta válida');
    });

    test('un 409 de booking es un rechazo con su motivo, no un error', () async {
      final (client, _) = build(409, {
        'valid': false,
        'code': 'already_used',
        'error': 'este QR ya se usó',
        'firstUsedAt': '2026-11-21T20:05:00.000Z',
      });

      final result = await client.checkIn(eventId: 'e1', qr: _qr);

      expect(result.valid, isFalse);
      expect(result.reason, 'already_used');
      expect(result.firstUsedAt, DateTime.utc(2026, 11, 21, 20, 5));
    });

    test('otros errores llegan como ApiException', () async {
      final (client, _) = build(503, {'error': 'no disponible'});

      await expectLater(client.checkIn(eventId: 'e1', qr: _qr), throwsA(isA<ApiException>()));
    });
  });
}
