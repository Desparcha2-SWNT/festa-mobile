import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/http_providers.dart';
import '../data/auth_api.dart';
import '../data/auth_repository.dart';
import '../data/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => const SecureTokenStorage());

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(publicDioProvider)));

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = AuthRepository(api: ref.watch(authApiProvider), storage: ref.watch(tokenStorageProvider));
  ref.onDispose(repository.dispose);
  return repository;
});
