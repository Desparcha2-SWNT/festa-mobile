// Formatos de la lista de asistentes. Sin `intl`: la app todavía no lo usa.

const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// «14 nov, 3:05 p. m.» en la hora local del teléfono.
String formatConfirmedAt(DateTime at) {
  final local = at.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minutes = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'a. m.' : 'p. m.';
  return '${local.day} ${_months[local.month - 1]}, $hour12:$minutes $period';
}
