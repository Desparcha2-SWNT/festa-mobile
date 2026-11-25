import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/auth/application/session_controller.dart';
import 'package:festa/features/auth/domain/account.dart';
import 'package:festa/features/passes/application/passes_providers.dart';
import 'package:festa/features/passes/data/passes_api.dart';
import 'package:festa/features/passes/data/passes_cache.dart';
import 'package:festa/features/passes/domain/pass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fakes.dart';

/// Almacenamiento seguro en memoria: solo lo que usa la copia (leer, escribir y borrar por clave).
class _MemoryStorage extends Mock implements FlutterSecureStorage {
  final values = <String, String>{};

  void stubAll() {
    when(() => read(key: any(named: 'key'))).thenAnswer((i) async => values[i.namedArguments[#key] as String]);
    when(
      () => write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((i) async {
      values[i.namedArguments[#key] as String] = i.namedArguments[#value] as String;
    });
    when(() => delete(key: any(named: 'key'))).thenAnswer((i) async {
      values.remove(i.namedArguments[#key] as String);
    });
  }
}

class _MockPassesApi extends Mock implements PassesApi {}

class _SignedInUser extends SessionController {
  @override
  Future<Account?> build() async => testAccount;
}

class _CountingSync extends PassesSync {
  _CountingSync() : super(api: _MockPassesApi(), cache: InMemoryPassesCache(), accountId: () => null);

  int calls = 0;

  @override
  Future<void> refresh() async => calls++;
}

const _qr = 'FESTA1.11111111-1111-4111-8111-111111111111.22222222-2222-4222-8222-222222222222.abcdefghijklmnopqrstuv';

Pass _pass(String id, {PassStatus status = PassStatus.valid}) => Pass(
  passId: id,
  eventId: 'e-$id',
  eventTitle: 'Noche de jazz',
  status: status,
  ticket: false,
  eventStartsAt: DateTime.utc(2030, 11, 14, 20, 5),
  eventEndsAt: DateTime.utc(2030, 11, 14, 23, 5),
  qr: status == PassStatus.valid ? _qr : null,
);

void main() {
  group('SecurePassesCache', () {
    late _MemoryStorage storage;
    late SecurePassesCache cache;
    final saved = DateTime.utc(2030, 11, 13, 20, 30);

    setUp(() {
      storage = _MemoryStorage()..stubAll();
      cache = SecurePassesCache(storage);
    });

    test('guarda cada cuenta en su clave y solo las entradas que se pueden mostrar', () async {
      await cache.save('a1', [_pass('p1'), _pass('p2', status: PassStatus.used)], saved);
      await cache.save('b2', [_pass('p3')], saved);

      expect([for (final pass in (await cache.read('a1'))!.passes) pass.passId], ['p1']);
      expect([for (final pass in (await cache.read('b2'))!.passes) pass.passId], ['p3']);
      expect(await cache.read('c3'), isNull);
    });

    test('readLast devuelve la copia de la última cuenta que guardó', () async {
      expect(await cache.readLast(), isNull);

      await cache.save('a1', [_pass('p1')], saved);
      await cache.save('b2', [_pass('p3')], saved);

      expect((await cache.readLast())?.accountId, 'b2');
    });

    test('borrar la copia de una cuenta no toca la de otra (cierre de sesión tardío)', () async {
      await cache.save('a1', [_pass('p1')], saved);
      await cache.save('b2', [_pass('p3')], saved);

      await cache.clear('a1');

      expect(await cache.read('a1'), isNull);
      expect(await cache.read('b2'), isNotNull);
      expect((await cache.readLast())?.accountId, 'b2');
    });

    test('tras borrar la copia de la última cuenta, readLast no devuelve nada', () async {
      await cache.save('a1', [_pass('p1')], saved);

      await cache.clear('a1');

      expect(await cache.readLast(), isNull);
    });

    test('una clave con la copia de otra cuenta no se devuelve', () async {
      storage.values[SecurePassesCache.keyFor('a1')] = SecurePassesCache.encode('b2', [_pass('p1')], saved);

      expect(await cache.read('a1'), isNull);
    });
  });

  group('PassesSync', () {
    late _MockPassesApi api;
    late InMemoryPassesCache cache;
    String? account;

    PassesSync sync() => PassesSync(api: api, cache: cache, accountId: () => account);

    setUp(() {
      api = _MockPassesApi();
      cache = InMemoryPassesCache();
      account = 'a1';
    });

    test('guarda las entradas de la cuenta de la sesión', () async {
      when(() => api.mine()).thenAnswer((_) async => [_pass('p1')]);

      await sync().refresh();

      expect([for (final pass in cache.copies['a1']!.passes) pass.passId], ['p1']);
    });

    test('sin red no falla y conserva la copia que había', () async {
      await cache.save('a1', [_pass('p1')], DateTime.utc(2030, 11, 13));
      when(() => api.mine()).thenThrow(const ApiException(code: ApiException.networkError, message: 'Sin conexión.'));

      await sync().refresh();

      expect(cache.copies['a1']!.passes.single.passId, 'p1');
    });

    test('si la sesión cambia mientras llega la respuesta, no guarda a nombre de otra cuenta', () async {
      when(() => api.mine()).thenAnswer((_) async {
        account = 'b2';
        return [_pass('p1')];
      });

      await sync().refresh();

      expect(cache.copies, isEmpty);
    });

    test('sin sesión no pide nada', () async {
      account = null;

      await sync().refresh();

      verifyNever(() => api.mine());
    });
  });

  test('al entrar con sesión se refresca la copia una vez (passesAutoSyncProvider)', () async {
    final sync = _CountingSync();
    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(_SignedInUser.new),
        passesSyncProvider.overrideWithValue(sync),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.future);

    final subscription = container.listen(passesAutoSyncProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(passesAutoSyncProvider.future);

    expect(sync.calls, 1);
  });
}
