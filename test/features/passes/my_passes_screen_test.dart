import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/auth/application/session_controller.dart';
import 'package:festa/features/auth/domain/account.dart';
import 'package:festa/features/passes/application/passes_providers.dart';
import 'package:festa/features/passes/data/passes_api.dart';
import 'package:festa/features/passes/data/passes_cache.dart';
import 'package:festa/features/passes/domain/pass.dart';
import 'package:festa/features/passes/presentation/my_passes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../support/fakes.dart';

class _MockPassesApi extends Mock implements PassesApi {}

class _SignedInUser extends SessionController {
  @override
  Future<Account?> build() async => testAccount;
}

/// Sin red: Dio no recibe respuesta y la app lo traduce a un error sin código.
const _offline = ApiException(code: ApiException.networkError, message: 'Sin conexión.');

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
  late InMemoryPassesCache cache;

  setUp(() {
    api = _MockPassesApi();
    cache = InMemoryPassesCache();
  });

  /// En la app solo se llega a «Mis entradas» con la sesión ya cargada: la pantalla abre con la cuenta lista.
  Future<void> pump(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        passesApiProvider.overrideWithValue(api),
        passesCacheProvider.overrideWithValue(cache),
        sessionControllerProvider.overrideWith(_SignedInUser.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(sessionControllerProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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

    // Figma 10 «Mi boleto»: chip de estado, horario de inicio a fin y aviso de un solo uso.
    expect(find.text('Mi entrada'), findsOneWidget);
    expect(find.text('Válido · 1 persona'), findsOneWidget);
    expect(find.text('jue 14 nov · 3:05 p. m. a 6:05 p. m.'), findsOneWidget);
    final qr = tester.widget<QrImageView>(find.byKey(const Key('passes.qr')));
    expect(qr.semanticsLabel, 'Código QR de tu entrada');
    expect(find.textContaining('Un solo uso: una vez escaneado, el código queda invalidado.'), findsOneWidget);
  });

  testWidgets('una boleta comprada se titula «Mi boleto»', (tester) async {
    when(() => api.mine()).thenAnswer((_) async => [_pass('p1', ticket: true)]);

    await pump(tester);
    await tester.tap(find.byKey(const Key('passes.item.p1')));
    await tester.pumpAndSettle();

    expect(find.text('Mi boleto'), findsOneWidget);
  });

  testWidgets('una entrada usada se abre sin QR y dice que ya se escaneó (Figma 10b)', (tester) async {
    when(() => api.mine()).thenAnswer((_) async => [_pass('p2', status: PassStatus.used)]);

    await pump(tester);
    await tester.tap(find.byKey(const Key('passes.item.p2')));
    await tester.pumpAndSettle();

    expect(find.text('Ya usado'), findsOneWidget);
    expect(find.byKey(const Key('passes.qr')), findsNothing);
    expect(find.byKey(const Key('passes.qr.used')), findsOneWidget);
    expect(find.text('Este boleto ya se escaneó. Un código solo sirve una vez.'), findsOneWidget);
  });

  testWidgets('una entrada cancelada no se abre', (tester) async {
    when(() => api.mine()).thenAnswer((_) async => [_pass('p3', status: PassStatus.revoked)]);

    await pump(tester);
    await tester.tap(find.byKey(const Key('passes.item.p3')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('passes.status')), findsNothing);
  });

  testWidgets('desde un plan abre el QR de su evento', (tester) async {
    when(() => api.mine()).thenAnswer((_) async => [_pass('p2', status: PassStatus.used), _pass('p1')]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [passesApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: PassForEventScreen(eventId: 'e-p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('passes.qr')), findsOneWidget);
  });

  testWidgets('desde un plan sin entrada lo dice', (tester) async {
    when(() => api.mine()).thenAnswer((_) async => [_pass('p1')]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [passesApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: PassForEventScreen(eventId: 'otro')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('passes.forEvent.missing')), findsOneWidget);
  });

  test('el horario muestra la fecha completa de fin si el evento termina otro día', () {
    final starts = DateTime(2030, 11, 14, 22);
    expect(formatPassSchedule(starts, DateTime(2030, 11, 15, 2)), 'jue 14 nov · 10:00 p. m. a vie 15 nov · 2:00 a. m.');
    expect(formatPassSchedule(starts, null), 'jue 14 nov · 10:00 p. m.');
  });

  test('la entrada de un evento prefiere la vigente y si no, la usada', () {
    expect(passForEvent([_pass('p2', status: PassStatus.used)], 'e-p2')?.passId, 'p2');
    expect(passForEvent([_pass('p3', status: PassStatus.revoked)], 'e-p3'), isNull);
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

  testWidgets('guarda en el teléfono solo las entradas que se pueden mostrar', (tester) async {
    when(() => api.mine()).thenAnswer((_) async => [_pass('p1'), _pass('p2', status: PassStatus.used)]);

    await pump(tester);

    expect([for (final pass in cache.copies[testAccount.id]!.passes) pass.passId], ['p1']);
    expect(find.byKey(const Key('passes.offline')), findsNothing);
  });

  testWidgets('sin conexión muestra las entradas guardadas, lo avisa y el QR abre', (tester) async {
    await cache.save(testAccount.id, [_pass('p1')], DateTime(2030, 11, 13, 20, 30));
    when(() => api.mine()).thenThrow(_offline);

    await pump(tester);

    expect(find.byKey(const Key('passes.offline')), findsOneWidget);
    expect(find.textContaining('guardadas el mié 13 nov · 8:30 p. m.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('passes.item.p1')));
    await tester.pumpAndSettle();
    expect(tester.widget<QrImageView>(find.byKey(const Key('passes.qr'))).semanticsLabel, 'Código QR de tu entrada');
  });

  testWidgets('con un error del servidor también usa la copia guardada', (tester) async {
    await cache.save(testAccount.id, [_pass('p1')], DateTime(2030, 11, 13, 20, 30));
    when(() => api.mine()).thenThrow(const ApiException(code: 'x', message: 'Falla.', statusCode: 503));

    await pump(tester);

    expect(find.byKey(const Key('passes.offline')), findsOneWidget);
    expect(find.text('Noche de jazz'), findsOneWidget);
  });

  testWidgets('sin conexión y sin copia guardada muestra el error', (tester) async {
    when(() => api.mine()).thenThrow(_offline);

    await pump(tester);

    expect(find.text('Sin conexión.'), findsOneWidget);
    expect(find.byKey(const Key('passes.retry')), findsOneWidget);
  });

  testWidgets('una respuesta 4xx no se tapa con la copia guardada', (tester) async {
    await cache.save(testAccount.id, [_pass('p1')], DateTime(2030, 11, 13, 20, 30));
    when(() => api.mine()).thenThrow(const ApiException(code: 'x', message: 'No disponible.', statusCode: 403));

    await pump(tester);

    expect(find.text('No disponible.'), findsOneWidget);
    expect(find.byKey(const Key('passes.offline')), findsNothing);
  });

  testWidgets('no muestra la copia guardada de otra cuenta', (tester) async {
    await cache.save('otra-cuenta', [_pass('p1')], DateTime(2030, 11, 13, 20, 30));
    when(() => api.mine()).thenThrow(_offline);

    await pump(tester);

    expect(find.text('Sin conexión.'), findsOneWidget);
    expect(find.text('Noche de jazz'), findsNothing);
  });

  test('la copia del teléfono guarda y lee el pase completo, y descarta lo ilegible', () {
    final saved = DateTime.utc(2030, 11, 13, 20, 30);
    final raw = SecurePassesCache.encode('a1', [
      _pass('p1', ticket: true),
      _pass('p2', status: PassStatus.revoked),
    ], saved);

    final cached = SecurePassesCache.decode(raw)!;
    expect(cached.accountId, 'a1');
    expect(cached.savedAt, saved);
    expect(cached.passes, hasLength(1));
    final pass = cached.passes.single;
    expect(pass.passId, 'p1');
    expect(pass.ticket, isTrue);
    expect(pass.qr, _qr);
    expect(pass.usable, isTrue);
    expect(pass.eventStartsAt?.toLocal(), DateTime(2030, 11, 14, 15, 5));

    expect(SecurePassesCache.decode('no es json'), isNull);
    expect(SecurePassesCache.decode('{"accountId": "a1"}'), isNull);
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
