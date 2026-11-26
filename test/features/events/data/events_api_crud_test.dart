import 'package:dio/dio.dart';
import 'package:festa/features/events/data/events_api.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/events/domain/event_draft.dart';
import 'package:festa/features/location/domain/geo_point.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un evento tal como lo devuelve event-service en las rutas de creación, edición, cancelación y detalle.
Map<String, dynamic> eventJson({String status = 'published'}) => {
  'eventId': 'e1',
  'title': 'Noche de jazz',
  'description': 'Bandas en vivo',
  'descriptionAiGenerated': false,
  'category': 'musical',
  'startsAt': '2099-01-01T23:00:00.000Z',
  'endsAt': '2099-01-02T02:00:00.000Z',
  'organizerName': 'Ana',
  'organizerType': 'merchant',
  'ticketed': false,
  'priceCents': 0,
  'capacity': 30,
  'coverImageUrl': null,
  'status': status,
  'venue': {
    'name': 'Bloque I',
    'address': 'Calle 1 # 2-3',
    'location': {'lat': 4.7829, 'lng': -74.0421},
  },
};

/// Dio que graba la petición enviada y responde con [body].
(Dio, List<RequestOptions>) fakeDio(Object body) {
  final sent = <RequestOptions>[];
  final dio = Dio(BaseOptions(baseUrl: 'http://festa.test'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          sent.add(options);
          handler.resolve(Response(requestOptions: options, statusCode: 200, data: body));
        },
      ),
    );
  return (dio, sent);
}

EventDraft draft() => EventDraft(
  title: 'Noche de jazz',
  venueName: 'Bloque I',
  venueAddress: 'Calle 1 # 2-3',
  location: const GeoPoint(latitude: 4.7829, longitude: -74.0421),
  startsAt: DateTime.utc(2099, 1, 1, 23),
  endsAt: DateTime.utc(2099, 1, 2, 2),
  category: EventCategory.musical,
  description: 'Bandas en vivo',
);

void main() {
  test('create hace POST /api/events con el borrador, el id del comercio y el nombre del organizador', () async {
    final (dio, sent) = fakeDio(eventJson());

    final event = await EventsApi(dio).create(draft(), merchantId: 'm1', organizerName: 'Ana');

    expect(sent.single.method, 'POST');
    expect(sent.single.path, '/api/events');
    final body = sent.single.data as Map<String, dynamic>;
    expect(body['merchantId'], 'm1');
    expect(body['organizerName'], 'Ana');
    expect(body['title'], 'Noche de jazz');
    expect(event.id, 'e1');
    expect(event.status, EventStatus.published);
  });

  test('update hace PATCH /api/events/:id solo con los cambios que se envían', () async {
    final (dio, sent) = fakeDio(eventJson());

    final event = await EventsApi(dio).update('e1', {'title': 'Noche de jazz 2'});

    expect(sent.single.method, 'PATCH');
    expect(sent.single.path, '/api/events/e1');
    expect(sent.single.data, {'title': 'Noche de jazz 2'});
    expect(event.title, 'Noche de jazz');
  });

  test('cancel hace POST /api/events/:id/cancel con el motivo y devuelve el evento cancelado', () async {
    final (dio, sent) = fakeDio(eventJson(status: 'cancelled'));

    final event = await EventsApi(dio).cancel('e1', reason: 'lluvia');

    expect(sent.single.method, 'POST');
    expect(sent.single.path, '/api/events/e1/cancel');
    expect(sent.single.data, {'reason': 'lluvia'});
    expect(event.status, EventStatus.cancelled);
  });

  test('byId hace GET /api/events/:id y devuelve el evento completo', () async {
    final (dio, sent) = fakeDio(eventJson());

    final event = await EventsApi(dio).byId('e1');

    expect(sent.single.method, 'GET');
    expect(sent.single.path, '/api/events/e1');
    expect(event.venueName, 'Bloque I');
    expect(event.location, const GeoPoint(latitude: 4.7829, longitude: -74.0421));
  });

  test('mine hace GET /api/events/mine y devuelve la lista del usuario', () async {
    final (dio, sent) = fakeDio({
      'items': [eventJson(), eventJson(status: 'hidden')],
    });

    final events = await EventsApi(dio).mine();

    expect(sent.single.method, 'GET');
    expect(sent.single.path, '/api/events/mine');
    expect(events.map((e) => e.status), [EventStatus.published, EventStatus.hidden]);
  });
}
