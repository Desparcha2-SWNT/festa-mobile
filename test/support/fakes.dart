import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/auth/data/auth_api.dart';
import 'package:festa/features/auth/data/token_storage.dart';
import 'package:festa/features/auth/domain/account.dart';
import 'package:festa/features/auth/domain/auth_session.dart';
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
