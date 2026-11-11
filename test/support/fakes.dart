import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/auth/data/auth_api.dart';
import 'package:festa/features/auth/data/token_storage.dart';
import 'package:festa/features/auth/domain/account.dart';
import 'package:festa/features/auth/domain/auth_session.dart';
import 'package:festa/features/events/domain/event.dart';
import 'package:festa/features/location/data/consents_api.dart';
import 'package:festa/features/location/data/device_location.dart';
import 'package:festa/features/location/data/location_consent_store.dart';
import 'package:festa/features/location/domain/geo_point.dart';
import 'package:festa/features/location/domain/location_consent.dart';
import 'package:festa/features/location/domain/user_location.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthApi extends Mock implements AuthApi {}

class MockConsentsApi extends Mock implements ConsentsApi {}

class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this.refreshToken]);

  String? refreshToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveRefreshToken(String token) async => refreshToken = token;

  @override
  Future<void> clear() async => refreshToken = null;
}

const testAccount = Account(id: 'a1', email: 'ana@escuelaing.edu.co', displayName: 'Ana', role: Role.user);

AuthSession testSession([String suffix = '1']) =>
    AuthSession(accessToken: 'access-$suffix', refreshToken: 'refresh-$suffix', account: testAccount);

const invalidRefresh = ApiException(
  code: 'INVALID_REFRESH_TOKEN',
  message: 'La sesión expiró. Inicia sesión de nuevo.',
  statusCode: 401,
);

const networkFailure = ApiException(code: ApiException.networkError, message: 'Sin conexión');

class InMemoryLocationConsentStore implements LocationConsentStore {
  final Map<String, StoredLocationConsent> consents = {};

  @override
  Future<StoredLocationConsent?> read(String accountId) async => consents[accountId];

  @override
  Future<void> save(String accountId, StoredLocationConsent consent) async => consents[accountId] = consent;
}

/// Ubicación del dispositivo simulada: devuelve [position] o, si se da [failure], falla con esa razón.
class FakeDeviceLocation implements DeviceLocation {
  FakeDeviceLocation({this.position = testDevicePoint, this.failure});

  final GeoPoint position;
  final LocationFallbackReason? failure;
  int calls = 0;

  @override
  Future<GeoPoint> currentPosition() async {
    calls++;
    if (failure case final reason?) throw LocationUnavailableException(reason);
    return position;
  }
}

const testDevicePoint = GeoPoint(latitude: 4.65, longitude: -74.06);

/// Evento tal como lo devuelve event-service (`toApi`).
Map<String, dynamic> eventJson({
  String id = 'e1',
  String title = '10ª Feria del Autómata',
  String category = 'musical',
  bool ticketed = false,
  int priceCents = 0,
  bool aiDescription = true,
}) => {
  'eventId': id,
  'organizerId': 'o1',
  'organizerType': ticketed ? 'merchant' : 'user',
  'organizerName': 'Programa de Ingeniería Mecánica',
  'title': title,
  'description': 'Muestra de autómatas que dan vida a la literatura colombiana.',
  'descriptionAiGenerated': aiDescription,
  'category': category,
  'tags': <String>[],
  'startsAt': '2026-11-12T13:30:00.000Z',
  'endsAt': '2026-11-12T16:30:00.000Z',
  'venue': {
    'name': 'Bloque I',
    'address': 'AK 45 #205-59',
    'location': {'lat': 4.7829, 'lng': -74.0421},
  },
  'capacity': 30,
  'ticketed': ticketed,
  'priceCents': priceCents,
  'currency': 'COP',
  'featured': false,
  'isLive': false,
  'coverImageUrl': null,
  'status': 'published',
};

Event testEvent({String id = 'e1', String title = '10ª Feria del Autómata', String category = 'musical'}) =>
    Event.fromJson(eventJson(id: id, title: title, category: category));
