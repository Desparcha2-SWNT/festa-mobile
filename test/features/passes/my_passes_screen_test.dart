import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/passes/application/passes_providers.dart';
import 'package:festa/features/passes/data/passes_api.dart';
import 'package:festa/features/passes/domain/pass.dart';
import 'package:festa/features/passes/presentation/my_passes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _MockPassesApi extends Mock implements PassesApi {}

const _qr = 'FESTA1.11111111-1111-4111-8111-111111111111.22222222-2222-4222-8222-222222222222.abcdefghijklmnopqrstuv';

Pass _pass(
  String id, {
  String title = 'Noche de jazz',
  PassStatus status = PassStatus.valid,
  bool ended = false,
  bool ticket = false,
}) {
  final starts = ended ? DateTime.now().subtract(const Duration(days: 2)) : DateTime(2030, 11, 14, 15, 5);
  return Pass(
    passId: id,
    eventId: 'e-$id',
    eventTitle: title,
    status: status,
    ticket: ticket,
    eventStartsAt: starts,
    eventEndsAt: starts.add(const Duration(hours: 3)),
    qr: status == PassStatus.valid ? _qr : null,
  );
}

void main() {
  late _MockPassesApi api;

  setUp(() => api = _MockPassesApi());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [passesApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: MyPassesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lista las entradas y dice el estado de cada una', (tester) async {
    when(() => api.mine()).thenAnswer(
      (_) async => [
        _pass('p1', title: 'Noche de jazz'),
        _pass('p2', title: 'Torneo', ticket: true, status: PassStatus.used),
        _pass('p3', title: 'Feria', status: PassStatus.revoked),
        _pass('p4', title: 'Cine', ended: true),
      ],
    );

    await pump(tester);

    expect(find.text('Noche de jazz'), findsOneWidget);
    // La de jazz y la cancelada son gratis y del mismo día.
    expect(find.text('Asistencia gratis · jue 14 nov · 3:05 p. m.'), findsNWidgets(2));
    expect(find.text('Ver QR'), findsOneWidget);
    expect(find.text('Usada'), findsOneWidget);
    expect(find.textContaining('Boleta'), findsOneWidget);
    expect(find.text('Cancelada'), findsOneWidget);
    expect(find.text('Evento terminado'), findsOneWidget);
  });

  testWidgets('tocar una entrada vigente muestra su QR', (tester) async {
    when(() => api.mine()).thenAnswer((_) async => [_pass('p1')]);

    await pump(tester);
    await tester.tap(find.byKey(const Key('passes.item.p1')));
    await tester.pumpAndSettle();

    expect(find.text('Tu entrada'), findsOneWidget);
    final qr = tester.widget<QrImageView>(find.byKey(const Key('passes.qr')));
    expect(qr.semanticsLabel, 'Código QR de tu entrada');
    expect(find.text('Muéstralo en la entrada. Sirve una sola vez.'), findsOneWidget);
  });

  testWidgets('una entrada usada o cancelada no abre el QR', (tester) async {
    when(() => api.mine()).thenAnswer((_) async => [_pass('p2', status: PassStatus.used)]);

    await pump(tester);
    await tester.tap(find.byKey(const Key('passes.item.p2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('passes.qr')), findsNothing);
  });

  testWidgets('una entrada usada abre el aviso y no muestra el QR', (tester) async {
    when(() => api.mine()).thenAnswer((_) async => [_pass('p2', status: PassStatus.used)]);

    await pump(tester);
    await tester.tap(find.byKey(const Key('passes.item.p2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('passes.used')), findsOneWidget);
    expect(find.byKey(const Key('passes.qr')), findsNothing);
  });

  testWidgets('muestra el horario de inicio y de fin del evento', (tester) async {
    when(() => api.mine()).thenAnswer((_) async => [_pass('p1')]);

    await pump(tester);
    await tester.tap(find.byKey(const Key('passes.item.p1')));
    await tester.pumpAndSettle();

    expect(find.textContaining('3:05 p. m. – 6:05 p. m.'), findsOneWidget);
  });
  testWidgets('sin entradas lo dice', (tester) async {
    when(() => api.mine()).thenAnswer((_) async => []);

    await pump(tester);

    expect(find.byKey(const Key('passes.empty')), findsOneWidget);
  });

  testWidgets('si falla la carga permite reintentar', (tester) async {
    var calls = 0;
    when(() => api.mine()).thenAnswer((_) async {
      if (calls++ == 0) throw const ApiException(code: 'x', message: 'No disponible.', statusCode: 403);
      return [_pass('p1')];
    });

    await pump(tester);
    expect(find.text('No disponible.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('passes.retry')));
    await tester.pumpAndSettle();

    expect(find.text('Noche de jazz'), findsOneWidget);
  });

  test('lee el pase de booking: estado, origen, fechas y QR solo si está vigente', () {
    final valid = Pass.fromJson({
      'passId': 'p1',
      'eventId': 'e1',
      'attendanceId': 'a1',
      'eventTitle': 'Noche de jazz',
      'eventStartsAt': '2030-11-14T20:05:00.000Z',
      'eventEndsAt': '2030-11-14T23:05:00.000Z',
      'source': 'ticket',
      'status': 'valid',
      'usedAt': null,
      'qr': _qr,
    });
    expect(valid.ticket, isTrue);
    expect(valid.usable, isTrue);
    expect(valid.eventStartsAt, DateTime.utc(2030, 11, 14, 20, 5));

    final used = Pass.fromJson({'passId': 'p2', 'eventId': 'e1', 'status': 'used', 'qr': null, 'source': 'rsvp'});
    expect(used.status, PassStatus.used);
    expect(used.usable, isFalse);
  });
}
