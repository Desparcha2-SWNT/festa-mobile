import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/http_providers.dart';
import '../data/profile_api.dart';
import '../domain/user_profile.dart';

final profileApiProvider = Provider<ProfileApi>((ref) => ProfileApi(ref.watch(authenticatedDioProvider)));

/// Intereses y preferencias guardados del usuario de la sesión.
///
/// Sin reintento automático (Riverpod 3 reintenta solo): el error se muestra enseguida con su botón «Reintentar».
final profileProvider = FutureProvider.autoDispose<UserProfile>(
  (ref) => ref.watch(profileApiProvider).getProfile(),
  retry: (_, _) => null,
);

/// Guarda intereses y preferencias (dos llamadas: la API los maneja por separado) y refresca el perfil.
/// Lanza `ApiException` si algo falla; la pantalla muestra el mensaje.
Future<void> saveProfile(
  WidgetRef ref, {
  required Set<Interest> interests,
  required UserPreferences preferences,
}) async {
  final api = ref.read(profileApiProvider);
  await api.replaceInterests(interests);
  await api.updatePreferences(preferences);
  ref.invalidate(profileProvider);
}
