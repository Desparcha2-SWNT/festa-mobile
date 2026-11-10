import 'account.dart';

/// Sesión emitida por auth-service.
///
/// El access token dura 15 min y solo vive en memoria. El refresh token dura 30 días,
/// se guarda cifrado en el dispositivo y rota en cada uso.
class AuthSession {
  const AuthSession({required this.accessToken, required this.refreshToken, required this.account});

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    account: Account.fromJson(json['account'] as Map<String, dynamic>),
  );

  final String accessToken;
  final String refreshToken;
  final Account account;
}
