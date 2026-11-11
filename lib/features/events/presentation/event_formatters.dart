import '../domain/event.dart';

/// Textos de fecha, hora y precio en español de Colombia, sin depender de `intl` para tres
/// formatos fijos. Siempre en la hora local del dispositivo.
abstract final class EventFormatters {
  static const _weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  static const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  /// `8:30 a. m.`
  static String time(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour < 12 ? 'a. m.' : 'p. m.'}';
  }

  /// `mié 12 nov`
  static String date(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${_weekdays[local.weekday - 1]} ${local.day} ${_months[local.month - 1]}';
  }

  /// `mié 12 nov · 8:30 a. m. a 11:30 a. m.`
  static String schedule(Event event) => '${date(event.startsAt)} · ${time(event.startsAt)} a ${time(event.endsAt)}';

  /// `Gratis` o `$10.000`
  static String price(Event event) {
    if (event.isFree) return 'Gratis';
    final pesos = (event.priceCents ~/ 100).toString();
    final grouped = pesos.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return '\$$grouped';
  }
}
