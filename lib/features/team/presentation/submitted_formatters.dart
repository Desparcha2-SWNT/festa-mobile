// Cuándo envió el comercio su solicitud, como en el Figma 28 y 29: «hace 2 h», «ayer», «hace 3 días».

const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// Versión corta para la lista (Figma 28): «hace 2 h», «ayer», «hace 3 días» o «el 14 nov».
String submittedShort(DateTime at, DateTime now) => switch (_ago(at, now)) {
  (unit: _Unit.moment, n: _) => 'hace un momento',
  (unit: _Unit.minutes, :final n) => 'hace $n min',
  (unit: _Unit.hours, :final n) => 'hace $n h',
  (unit: _Unit.yesterday, n: _) => 'ayer',
  (unit: _Unit.days, :final n) => 'hace $n días',
  (unit: _Unit.date, n: _) => 'el ${_date(at)}',
};

/// Versión larga para la solicitud (Figma 29): «Hace 2 horas», «Ayer», «Hace 3 días» o «El 14 nov».
String submittedLong(DateTime at, DateTime now) => switch (_ago(at, now)) {
  (unit: _Unit.moment, n: _) => 'Hace un momento',
  (unit: _Unit.minutes, :final n) => n == 1 ? 'Hace 1 minuto' : 'Hace $n minutos',
  (unit: _Unit.hours, :final n) => n == 1 ? 'Hace 1 hora' : 'Hace $n horas',
  (unit: _Unit.yesterday, n: _) => 'Ayer',
  (unit: _Unit.days, :final n) => 'Hace $n días',
  (unit: _Unit.date, n: _) => 'El ${_date(at)}',
};

enum _Unit { moment, minutes, hours, yesterday, days, date }

({_Unit unit, int n}) _ago(DateTime at, DateTime now) {
  final local = at.toLocal();
  final elapsed = now.difference(local);
  if (elapsed.inMinutes < 1) return (unit: _Unit.moment, n: 0);
  if (elapsed.inMinutes < 60) return (unit: _Unit.minutes, n: elapsed.inMinutes);
  // Días de calendario: algo enviado anoche a las 11 es «ayer», aunque hayan pasado pocas horas.
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(local.year, local.month, local.day)).inDays;
  if (days == 0) return (unit: _Unit.hours, n: elapsed.inHours);
  if (days == 1) return (unit: _Unit.yesterday, n: 1);
  if (days < 7) return (unit: _Unit.days, n: days);
  return (unit: _Unit.date, n: days);
}

String _date(DateTime at) {
  final local = at.toLocal();
  return '${local.day} ${_months[local.month - 1]}';
}
