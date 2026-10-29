import 'package:festa/core/network/api_exception.dart';
import 'package:festa/features/auth/data/auth_api.dart';
import 'package:festa/features/auth/data/token_storage.dart';
import 'package:festa/features/auth/domain/account.dart';
import 'package:festa/features/auth/domain/auth_session.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthApi extends Mock implements AuthApi {}

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
