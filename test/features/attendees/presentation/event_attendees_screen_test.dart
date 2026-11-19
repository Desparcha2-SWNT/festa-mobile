import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/attendees/application/attendees_providers.dart';
import 'package:festa/features/attendees/data/attendees_api.dart';
import 'package:festa/features/attendees/domain/attendee.dart';
import 'package:festa/features/attendees/presentation/event_attendees_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAttendeesApi extends Mock implements AttendeesApi {}

const _eventId = 'e1';

Attendee _attendee(
  String id, {
  String? name,
  AttendanceSource source = AttendanceSource.rsvp,
  int tickets = 1,
  int checkedIn = 0,
}) => Attendee(
  attendanceId: id,
  displayName: name,
  source: source,
  tickets: tickets,
  checkedIn: checkedIn,
  confirmedAt: DateTime(2026, 11, 14, 15, 5),
);

AttendeePage _page(List<Attendee> items, {int? total, int offset = 0, int attendeeCount = 3, int? capacity = 80}) =>
    AttendeePage(
      items: items,
      total: total ?? items.length,
      attendeeCount: attendeeCount,
      offset: offset,
      capacity: capacity,
    );

void main() {
  late _MockAttendeesApi api;

  setUp(() => api = _MockAttendeesApi());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [attendeesApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: EventAttendeesScreen(eventId: _eventId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('el organizador ve a cada asistente, sus boletas y quién ya entró', (tester) async {
    when(() => api.list(_eventId)).thenAnswer(
      (_) async => _page([
        _attendee('a1', name: 'Ana María', source: AttendanceSource.ticket, tickets: 2, checkedIn: 2),
        _attendee('a2', name: 'Beto', source: AttendanceSource.ticket, tickets: 2, checkedIn: 1),
        _attendee('a3'),
      ]),
    );

    await pump(tester);

    expect(find.text('3 de 80 cupos'), findsOneWidget);
    expect(find.text('Ana María'), findsOneWidget);
    expect(find.text('AM'), findsOneWidget);
    expect(find.text('2 boletas · 14 nov, 3:05 p. m.'), findsNWidgets(2));
    expect(find.text('Ingresó'), findsOneWidget);
    expect(find.text('1/2 ingresaron'), findsOneWidget);
    // Sin nombre en booking: texto genérico, no un id.
    expect(find.text('Asistente sin nombre'), findsOneWidget);
    expect(find.text('Asistencia gratis · 14 nov, 3:05 p. m.'), findsOneWidget);
    expect(find.byKey(const Key('attendees.loadMore')), findsNothing);
  });

  testWidgets('sin cupo máximo muestra solo el conteo', (tester) async {
    when(() => api.list(_eventId))
        .thenAnswer((_) async => _page([_attendee('a1', name: 'Ana')], attendeeCount: 1, capacity: null));

    await pump(tester);

    expect(find.text('1 asistente'), findsOneWidget);
  });

  testWidgets('"Ver más" trae la siguiente página y la agrega a la lista', (tester) async {
    when(() => api.list(_eventId)).thenAnswer((_) async => _page([_attendee('a1', name: 'Ana')], total: 2));
    when(() => api.list(_eventId, offset: 1))
        .thenAnswer((_) async => _page([_attendee('a2', name: 'Beto')], total: 2, offset: 1));

    await pump(tester);
    expect(find.text('Ver más (1)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('attendees.loadMore')));
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Beto'), findsOneWidget);
    expect(find.byKey(const Key('attendees.loadMore')), findsNothing);
  });

  testWidgets('quien no organiza el evento ve que no tiene permiso, sin botón de reintentar', (tester) async {
    when(() => api.list(_eventId))
        .thenThrow(const ApiException(code: 'not_organizer', message: 'solo el organizador', statusCode: 403));

    await pump(tester);

    expect(find.text('No puedes ver esta lista'), findsOneWidget);
    expect(find.text('Solo el organizador del evento puede ver sus asistentes.'), findsOneWidget);
    expect(find.byKey(const Key('attendees.retry')), findsNothing);
    // Un 403 no cambia reintentando: se pidió una sola vez.
    verify(() => api.list(_eventId)).called(1);
  });

  testWidgets('sin red reintenta solo dos veces y luego ofrece reintentar a mano', (tester) async {
    var online = false;
    when(() => api.list(_eventId)).thenAnswer((_) async {
      if (!online) throw const ApiException(code: ApiException.networkError, message: 'No pudimos conectarnos.');
      return _page([_attendee('a1', name: 'Ana')]);
    });

    await pump(tester);
    expect(find.text('No pudimos conectarnos.'), findsOneWidget);
    verify(() => api.list(_eventId)).called(3); // el intento y dos reintentos automáticos

    online = true;
    await tester.tap(find.byKey(const Key('attendees.retry')));
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('un evento sin asistentes lo dice', (tester) async {
    when(() => api.list(_eventId)).thenAnswer((_) async => _page([], attendeeCount: 0));

    await pump(tester);

    expect(find.byKey(const Key('attendees.empty')), findsOneWidget);
    expect(find.text('0 de 80 cupos'), findsOneWidget);
  });
}
