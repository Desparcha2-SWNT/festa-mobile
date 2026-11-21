import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/design.dart';
import '../../../core/network/api_exception.dart';
import '../../events/domain/event.dart';
import '../../events/presentation/event_formatters.dart';
import '../application/orders_providers.dart';

/// RF11: compra de boletas en el detalle de un evento con boleta y precio. Crea la orden (retiene el cupo)
/// y abre el checkout de Wompi en el navegador; la app nunca recibe datos de tarjeta.
class TicketBar extends ConsumerStatefulWidget {
  const TicketBar({required this.event, super.key});

  final Event event;

  /// Máximo de boletas por orden. Lo acota la app; payment-service valida el cupo real.
  static const maxPerOrder = 4;

  /// Solo un evento con boleta, con precio, publicado y que no ha terminado (la compra no es gratis).
  static bool appliesTo(Event event) =>
      event.ticketed && !event.isFree && event.status == EventStatus.published && event.endsAt.isAfter(DateTime.now());

  @override
  ConsumerState<TicketBar> createState() => _TicketBarState();
}

class _TicketBarState extends ConsumerState<TicketBar> {
  int _quantity = 1;
  bool _sending = false;

  Future<void> _buy() async {
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(ordersApiProvider);
    final openCheckout = ref.read(checkoutLauncherProvider);
    // La clave combina el evento y el instante: un doble toque no crea dos órdenes (Idempotency-Key).
    final key = '${widget.event.id}-${DateTime.now().microsecondsSinceEpoch}';
    setState(() => _sending = true);
    try {
      final checkout = await api.createOrder(eventId: widget.event.id, quantity: _quantity, idempotencyKey: key);
      final url = checkout.checkoutUrl;
      if (url == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Esta orden ya no está pendiente de pago.')));
        return;
      }
      final opened = await openCheckout(url);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? 'Completa el pago en Wompi. Tus entradas aparecerán cuando se apruebe.'
                : 'No pudimos abrir el pago. Intenta de nuevo.',
          ),
        ),
      );
      ref.invalidate(myOrdersProvider);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(FestaSpace.sm),
        child: Row(
          children: [
            IconButton(
              key: const Key('ticket.minus'),
              tooltip: 'Quitar una boleta',
              icon: const Icon(Icons.remove),
              onPressed: _sending || _quantity <= 1 ? null : () => setState(() => _quantity--),
            ),
            Text('$_quantity', key: const Key('ticket.quantity'), style: theme.textTheme.titleMedium),
            IconButton(
              key: const Key('ticket.plus'),
              tooltip: 'Agregar una boleta',
              icon: const Icon(Icons.add),
              onPressed: _sending || _quantity >= TicketBar.maxPerOrder ? null : () => setState(() => _quantity++),
            ),
            const SizedBox(width: FestaSpace.xs),
            Expanded(
              child: Text(
                'Boleta ${EventFormatters.price(widget.event)}',
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            FilledButton(
              key: const Key('ticket.buy'),
              onPressed: _sending ? null : _buy,
              child: Text(_sending ? 'Abriendo pago…' : 'Comprar'),
            ),
          ],
        ),
      ),
    );
  }
}
