import 'package:dio/dio.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/orders/application/orders_providers.dart';
import 'package:festa/features/orders/data/orders_api.dart';
import 'package:festa/features/orders/domain/order.dart';
import 'package:festa/features/orders/presentation/ticket_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';

/// Guarda cada intento. Si `failures` tiene entradas, las usa en orden antes de crear la orden.
class _FakeOrdersApi extends OrdersApi {
  _FakeOrdersApi(this.failures) : super(Dio());

  final List<ApiException> failures;
  final List<String> keys = [];
  final List<int> quantities = [];

  @override
  Future<CheckoutOrder> createOrder({
    required String eventId,
    required int quantity,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    quantities.add(quantity);
    if (failures.isNotEmpty) throw failures.removeAt(0);
    return CheckoutOrder(
      order: Order(
        id: 'o-1',
        eventId: eventId,
        quantity: quantity,
        totalCents: 10000000,
        currency: 'COP',
        status: OrderStatus.pending,
      ),
      checkoutUrl: Uri.parse('https://checkout.wompi.co/p/?reference=ref-1'),
    );
  }
}

const _networkDown = ApiException(code: ApiException.networkError, message: 'Sin conexión.');
const _soldOut = ApiException(code: 'SOLD_OUT', message: 'No hay cupos suficientes.', statusCode: 409);

void main() {
  // El evento de prueba debe seguir sin terminar: el fixture tiene fechas fijas.
  final ticketedJson = eventJson(id: 'e1', ticketed: true, priceCents: 5000000)
    ..['endsAt'] = DateTime.now().add(const Duration(days: 3)).toUtc().toIso8601String();
  final ticketed = Event.fromJson(ticketedJson);

  Future<(_FakeOrdersApi, List<Uri>)> pump(
    WidgetTester tester,
    Event event, {
    List<ApiException> failures = const [],
  }) async {
    final api = _FakeOrdersApi([...failures]);
    final opened = <Uri>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersApiProvider.overrideWithValue(api),
          checkoutLauncherProvider.overrideWithValue((url) async {
            opened.add(url);
            return true;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: TicketBar(event: event)),
          ),
        ),
      ),
    );
    return (api, opened);
  }

  Future<void> tapBuy(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('ticket.buy')));
    await tester.pumpAndSettle();
  }

  test('solo aplica a un evento con boleta, con precio y sin terminar', () {
    expect(TicketBar.appliesTo(ticketed), isTrue);
    expect(TicketBar.appliesTo(Event.fromJson(eventJson(id: 'e2'))), isFalse);
  });

  testWidgets('compra: crea la orden con la cantidad elegida y abre el checkout', (tester) async {
    final (api, opened) = await pump(tester, ticketed);

    await tester.tap(find.byKey(const Key('ticket.plus')));
    await tester.pump();
    await tapBuy(tester);

    expect(api.quantities, [2]);
    expect(api.keys.single, startsWith('e1-'));
    expect(opened, [Uri.parse('https://checkout.wompi.co/p/?reference=ref-1')]);
    expect(find.text('Completa el pago en Wompi. Tus entradas aparecerán cuando se apruebe.'), findsOneWidget);
  });

  testWidgets('si la red se corta, el reintento usa la misma clave y no crea otra orden', (tester) async {
    final (api, _) = await pump(tester, ticketed, failures: [_networkDown]);

    await tapBuy(tester);
    expect(find.text('Sin conexión.'), findsOneWidget);
    await tapBuy(tester);

    expect(api.keys, hasLength(2));
    expect(api.keys[1], api.keys[0], reason: 'mismo intento: misma clave');
  });

  testWidgets('después de crear la orden, el siguiente intento usa una clave nueva', (tester) async {
    final (api, _) = await pump(tester, ticketed);

    await tapBuy(tester);
    await tapBuy(tester);

    expect(api.keys, hasLength(2));
    expect(api.keys[1], isNot(api.keys[0]));
  });

  testWidgets('si el servidor rechaza el intento (cupo agotado), el reintento usa una clave nueva', (tester) async {
    final (api, _) = await pump(tester, ticketed, failures: [_soldOut]);

    await tapBuy(tester);
    await tapBuy(tester);

    expect(api.keys[1], isNot(api.keys[0]));
  });

  testWidgets('cambiar la cantidad inicia un intento nuevo', (tester) async {
    final (api, _) = await pump(tester, ticketed, failures: [_networkDown]);

    await tapBuy(tester);
    await tester.tap(find.byKey(const Key('ticket.plus')));
    await tester.pump();
    await tapBuy(tester);

    expect(api.quantities, [1, 2]);
    expect(api.keys[1], isNot(api.keys[0]));
  });

  testWidgets('no baja de una boleta ni sube del máximo por orden', (tester) async {
    await pump(tester, ticketed);

    await tester.tap(find.byKey(const Key('ticket.minus')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('ticket.quantity'))).data, '1');

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const Key('ticket.plus')));
      await tester.pump();
    }
    expect(tester.widget<Text>(find.byKey(const Key('ticket.quantity'))).data, '${TicketBar.maxPerOrder}');
  });

  testWidgets('el máximo lo fija el evento cuando lo informa', (tester) async {
    final limited = Event.fromJson({...ticketedJson, 'maxTicketsPerOrder': 2});
    await pump(tester, limited);

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const Key('ticket.plus')));
      await tester.pump();
    }
    expect(tester.widget<Text>(find.byKey(const Key('ticket.quantity'))).data, '2');
  });
}
