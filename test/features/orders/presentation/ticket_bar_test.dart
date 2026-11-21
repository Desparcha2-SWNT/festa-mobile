import 'package:dio/dio.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/orders/application/orders_providers.dart';
import 'package:festa/features/orders/data/orders_api.dart';
import 'package:festa/features/orders/domain/order.dart';
import 'package:festa/features/orders/presentation/ticket_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';

/// Guarda lo que pide la pantalla; no hace red.
class _FakeOrdersApi extends OrdersApi {
  _FakeOrdersApi() : super(Dio());

  String? eventId;
  int? quantity;
  String? key;

  @override
  Future<CheckoutOrder> createOrder({
    required String eventId,
    required int quantity,
    required String idempotencyKey,
  }) async {
    this.eventId = eventId;
    this.quantity = quantity;
    key = idempotencyKey;
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

void main() {
  // El evento de prueba debe seguir sin terminar: el fixture tiene fechas fijas.
  final ticketedJson = eventJson(id: 'e1', ticketed: true, priceCents: 5000000)
    ..['endsAt'] = DateTime.now().add(const Duration(days: 3)).toUtc().toIso8601String();
  final ticketed = Event.fromJson(ticketedJson);

  Future<(_FakeOrdersApi, List<Uri>)> pump(WidgetTester tester, Event event) async {
    final api = _FakeOrdersApi();
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

  test('solo aplica a un evento con boleta, con precio y sin terminar', () {
    expect(TicketBar.appliesTo(ticketed), isTrue);
    expect(TicketBar.appliesTo(Event.fromJson(eventJson(id: 'e2'))), isFalse);
  });

  testWidgets('compra: crea la orden con la cantidad elegida y abre el checkout', (tester) async {
    final (api, opened) = await pump(tester, ticketed);

    await tester.tap(find.byKey(const Key('ticket.plus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ticket.buy')));
    await tester.pumpAndSettle();

    expect(api.eventId, 'e1');
    expect(api.quantity, 2);
    expect(api.key, startsWith('e1-'));
    expect(opened, [Uri.parse('https://checkout.wompi.co/p/?reference=ref-1')]);
    expect(find.text('Completa el pago en Wompi. Tus entradas aparecerán cuando se apruebe.'), findsOneWidget);
  });

  testWidgets('no baja de una boleta ni sube de cuatro', (tester) async {
    await pump(tester, ticketed);

    await tester.tap(find.byKey(const Key('ticket.minus')));
    await tester.pump();
    expect(find.byKey(const Key('ticket.quantity')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('ticket.quantity'))).data, '1');

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const Key('ticket.plus')));
      await tester.pump();
    }
    expect(tester.widget<Text>(find.byKey(const Key('ticket.quantity'))).data, '${TicketBar.maxPerOrder}');
  });
}
