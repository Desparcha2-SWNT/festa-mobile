import 'package:festa/app/routes.dart';
import 'package:festa/core/config/app_config.dart';
import 'package:festa/features/events/application/events_providers.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/events/presentation/event_detail_screen.dart';
import 'package:festa/features/events/presentation/event_formatters.dart';
import 'package:festa/features/events/presentation/event_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fakes.dart';

/// Guarda lo que se compartió en vez de abrir el menú del sistema.
class _RecordingSharer implements EventSharer {
  final List<(Event, Rect?)> shared = [];

  @override
  Future<void> share(Event event, {Rect? origin}) async => shared.add((event, origin));
}

void main() {
  test('el texto lleva el plan, cuándo, dónde, el precio y dónde descargar Festa', () {
    final event = Event.fromJson(eventJson(ticketed: true, priceCents: 1000000));

    final text = eventShareText(event);

    expect(text.split('\n'), [
      '10ª Feria del Autómata',
      '📅 ${EventFormatters.schedule(event)}',
      '📍 Bloque I, AK 45 #205-59',
      r'🎟️ $10.000',
      '',
      'Lo encontré en Festa, el mapa de planes de la Escuela: ${AppConfig.downloadUrl}',
    ]);
  });

  test('sin dirección no deja la coma colgando', () {
    final json = eventJson();
    final event = Event.fromJson({
      ...json,
      'venue': {...json['venue'] as Map<String, dynamic>, 'address': ''},
    });

    expect(eventShareText(event), contains('📍 Bloque I\n'));
  });

  test('un evento gratis dice «Gratis»', () {
    expect(eventShareText(Event.fromJson(eventJson())), contains('🎟️ Gratis'));
  });

  Future<_RecordingSharer> pumpDetail(WidgetTester tester, Map<String, dynamic> json) async {
    final sharer = _RecordingSharer();
    final container = ProviderContainer(
      overrides: [
        eventDetailProvider.overrideWith((ref, id) async => Event.fromJson(json)),
        eventSharerProvider.overrideWithValue(sharer),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: Routes.eventDetail('e1'),
      routes: [
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
    return sharer;
  }

  testWidgets('«Compartir» en el detalle abre el menú del sistema con el evento', (tester) async {
    final sharer = await pumpDetail(tester, eventJson());

    await tester.tap(find.byKey(const Key('eventDetail.share')));
    await tester.pump();

    final (event, origin) = sharer.shared.single;
    expect(event.id, 'e1');
    // El iPad ubica el menú junto al botón.
    expect(origin, isNotNull);
    expect(origin!.isEmpty, isFalse);
  });

  testWidgets('un evento cancelado no se puede compartir', (tester) async {
    await pumpDetail(tester, {...eventJson(), 'status': 'cancelled'});

    expect(find.text('El organizador canceló este evento.'), findsOneWidget);
    expect(find.byKey(const Key('eventDetail.share')), findsNothing);
  });
}
