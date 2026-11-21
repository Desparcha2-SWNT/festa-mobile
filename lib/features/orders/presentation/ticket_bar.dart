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

  /// Clave de idempotencia del intento en curso. Se genera una vez y se reutiliza en los reintentos (por ejemplo,
  /// si la red se corta después de que payment-service creó la orden), así el reintento no crea una segunda orden.
  /// Se renueva cuando la orden se crea, cuando el servidor rechaza el intento o cuando cambia la cantidad.
  String? _attemptKey;
  int? _attemptQuantity;

  String _keyFor(int quantity) {
    if (_attemptKey == null || _attemptQuantity != quantity) {
      _attemptKey = '${widget.event.id}-${DateTime.now().microsecondsSinceEpoch}';
      _attemptQuantity = quantity;
    }
    return _attemptKey!;
  }

  void _resetAttempt() {
    _attemptKey = null;
    _attemptQuantity = null;
  }

  /// Límite por orden: el que fija el organizador en el evento, o el máximo de la app si no lo informa.
  int get _limit => widget.event.maxTicketsPerOrder ?? TicketBar.maxPerOrder;

  Future<void> _buy() async {
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(ordersApiProvider);
    final openCheckout = ref.read(checkoutLauncherProvider);
    final key = _keyFor(_quantity);
    setState(() => _sending = true);
    try {
      final checkout = await api.createOrder(eventId: widget.event.id, quantity: _quantity, idempotencyKey: key);
      // La orden ya existe: el próximo toque es un intento nuevo.
      _resetAttempt();
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
      // Con respuesta del servidor (p. ej. cupo agotado) la orden no se creó: el próximo intento necesita una clave nueva.
      // Sin respuesta (red caída) se conserva la clave para reintentar sin duplicar la orden.
      if (e.statusCode != null) _resetAttempt();
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
              onPressed: _sending || _quantity >= _limit ? null : () => setState(() => _quantity++),
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
