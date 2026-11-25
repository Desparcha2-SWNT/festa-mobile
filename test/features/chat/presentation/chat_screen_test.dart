import 'dart:async';

import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/chat/application/chat_controller.dart';
import 'package:festa/features/chat/data/chat_api.dart';
import 'package:festa/features/chat/domain/chat_models.dart';
import 'package:festa/features/chat/presentation/chat_screen.dart';
import 'package:festa/features/location/application/user_location_provider.dart';
import 'package:festa/features/location/domain/geo_point.dart';
import 'package:festa/features/location/domain/user_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockChatApi extends Mock implements ChatApi {}

ChatReply _reply({String text = 'Te sugiero esta noche de jazz.', List<RecommendedEvent>? events}) => ChatReply(
  sessionId: 'session-1',
  reply: text,
  events:
      events ??
      [
        RecommendedEvent(
          eventId: 'e1',
          title: 'Noche de jazz',
          category: 'musical',
          startsAt: DateTime(2026, 11, 22, 20),
          venueName: 'Bloque G',
          priceCents: 3500000,
          isLive: false,
        ),
      ],
  disclaimer: 'Sugerencias automatizadas generadas por IA.',
);

void main() {
  late _MockChatApi api;

  setUp(() {
    api = _MockChatApi();
    registerFallbackValue(const GeoPoint(latitude: 0, longitude: 0));
  });

  Future<ProviderContainer> pump(WidgetTester tester, {UserLocation? location}) async {
    final container = ProviderContainer(
      overrides: [
        chatApiProvider.overrideWithValue(api),
        userLocationProvider.overrideWith(
          (ref) async => location ?? const UserLocation.fallback(LocationFallbackReason.consentDeclined),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
    return container;
  }

  Future<void> write(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('chat.input')), text);
    await tester.tap(find.byKey(const Key('chat.send')));
    await tester.pumpAndSettle();
  }

  testWidgets('avisa siempre que las sugerencias son automatizadas y invita a escribir', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('chat.disclaimer')), findsOneWidget);
    expect(find.textContaining('automatizadas'), findsOneWidget);
    expect(find.byKey(const Key('chat.empty')), findsOneWidget);
  });

  testWidgets('muestra la respuesta con el evento recomendado, su fecha, lugar y precio', (tester) async {
    when(
      () => api.send(
        any(),
        sessionId: any(named: 'sessionId'),
        location: any(named: 'location'),
      ),
    ).thenAnswer((_) async => _reply());
    await pump(tester);

    await write(tester, 'algo de jazz');

    expect(find.text('algo de jazz'), findsOneWidget);
    expect(find.text('Te sugiero esta noche de jazz.'), findsOneWidget);
    expect(find.text('Noche de jazz'), findsOneWidget);
    expect(find.text('Bloque G'), findsOneWidget);
    expect(find.text(r'$ 35.000'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('chat.input'))).controller!.text, isEmpty);
  });

  testWidgets('el segundo mensaje reenvía la sesión de la conversación', (tester) async {
    when(
      () => api.send(
        any(),
        sessionId: any(named: 'sessionId'),
        location: any(named: 'location'),
      ),
    ).thenAnswer((_) async => _reply(events: []));
    await pump(tester);

    await write(tester, 'primero');
    await write(tester, 'segundo');

    verify(() => api.send('primero', sessionId: null, location: null)).called(1);
    verify(() => api.send('segundo', sessionId: 'session-1', location: null)).called(1);
  });

  testWidgets('sin consentimiento no manda ubicación; con consentimiento manda la del dispositivo', (tester) async {
    when(
      () => api.send(
        any(),
        sessionId: any(named: 'sessionId'),
        location: any(named: 'location'),
      ),
    ).thenAnswer((_) async => _reply(events: []));
    const point = GeoPoint(latitude: 4.65, longitude: -74.06);
    await pump(tester, location: const UserLocation.device(point));

    await write(tester, 'cerca de mí');

    verify(() => api.send('cerca de mí', sessionId: null, location: point)).called(1);
  });

  testWidgets('un 429 muestra «vas muy rápido» y conserva la conversación', (tester) async {
    when(
      () => api.send(
        any(),
        sessionId: any(named: 'sessionId'),
        location: any(named: 'location'),
      ),
    ).thenThrow(const ApiException(code: ApiException.tooManyRequests, message: 'x', statusCode: 429));
    await pump(tester);

    await write(tester, 'hola');

    expect(find.byKey(const Key('chat.error')), findsOneWidget);
    expect(find.text(ChatController.tooManyRequestsMessage), findsOneWidget);
    expect(find.text('hola'), findsOneWidget);
  });

  testWidgets('un mensaje vacío no se manda', (tester) async {
    await pump(tester);

    await write(tester, '   ');

    verifyNever(
      () => api.send(
        any(),
        sessionId: any(named: 'sessionId'),
        location: any(named: 'location'),
      ),
    );
  });

  testWidgets('no se manda un segundo mensaje mientras el primero sigue en curso', (tester) async {
    final pending = Completer<ChatReply>();
    when(
      () => api.send(
        any(),
        sessionId: any(named: 'sessionId'),
        location: any(named: 'location'),
      ),
    ).thenAnswer((_) => pending.future);
    final container = await pump(tester);
    final controller = container.read(chatControllerProvider.notifier);

    final first = controller.send('uno');
    await tester.pump();
    expect(await controller.send('dos'), isFalse);
    pending.complete(_reply(events: []));
    await first;
    await tester.pumpAndSettle();

    verify(() => api.send('uno', sessionId: null, location: null)).called(1);
    verifyNever(
      () => api.send(
        'dos',
        sessionId: any(named: 'sessionId'),
        location: any(named: 'location'),
      ),
    );
  });
}
