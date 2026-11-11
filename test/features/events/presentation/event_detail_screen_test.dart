import 'package:festa/app/routes.dart';
import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/events/application/events_providers.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/events/presentation/event_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fakes.dart';

void main() {
  /// Abre el detalle de `e1` con [load] como respuesta de event-service. Devuelve el contenedor
  /// para revisar el estado después.
  Future<ProviderContainer> pumpDetail(WidgetTester tester, Future<Event> Function() load) async {
    final container = ProviderContainer(overrides: [eventDetailProvider.overrideWith((ref, id) => load())]);
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: Routes.eventDetail('e1'),
      routes: [
        GoRoute(
          path: Routes.map,
          builder: (_, _) => const Scaffold(body: Text('Mapa')),
        ),
        GoRoute(
          path: Routes.eventDetailPattern,
          builder: (_, state) => EventDetailScreen(eventId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('muestra la información del evento', (tester) async {
    await pumpDetail(tester, () async => Event.fromJson(eventJson(ticketed: true, priceCents: 1000000)));

    expect(find.text('10ª Feria del Autómata'), findsOneWidget);
    expect(find.text('Musical'), findsOneWidget);
    expect(find.text('Bloque I, AK 45 #205-59'), findsOneWidget);
    expect(find.text(r'$10.000'), findsOneWidget);
    expect(find.text('Cupo para 30 personas'), findsOneWidget);
    expect(find.text('Comercio verificado'), findsOneWidget);
    expect(find.text('Descripción generada con IA'), findsOneWidget);
  });

  testWidgets('no dice «verificado» si el organizador no es un comercio verificado', (tester) async {
    await pumpDetail(tester, () async => Event.fromJson(eventJson(aiDescription: false)));

    expect(find.text('Comercio verificado'), findsNothing);
    expect(find.text('Descripción generada con IA'), findsNothing);
  });

  testWidgets('«Ver en el mapa» selecciona el evento y vuelve al mapa', (tester) async {
    final container = await pumpDetail(tester, () async => testEvent());

    await tester.tap(find.byKey(const Key('eventDetail.showOnMap')));
    await tester.pumpAndSettle();

    expect(find.text('Mapa'), findsOneWidget);
    expect(container.read(selectedEventProvider)?.id, 'e1');
  });

  testWidgets('si falla la carga muestra el mensaje y permite reintentar', (tester) async {
    var attempts = 0;
    await pumpDetail(tester, () async {
      if (attempts++ == 0) throw const ApiException(code: 'NOT_FOUND', message: 'Evento no encontrado.');
      return testEvent();
    });
    expect(find.text('Evento no encontrado.'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('10ª Feria del Autómata'), findsOneWidget);
  });
}
