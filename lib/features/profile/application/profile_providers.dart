import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/http_providers.dart';
import '../../auth/application/session_controller.dart';
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
///
/// Devuelve `false` si la sesión cambió (o la pantalla se cerró) mientras se guardaba: el cliente toma el
/// token vigente en cada petición, así que seguir habría escrito en la cuenta nueva lo que eligió la anterior.
Future<bool> saveProfile(
  WidgetRef ref, {
  required Set<Interest> interests,
  required UserPreferences preferences,
}) async {
  final api = ref.read(profileApiProvider);
  final accountId = ref.read(sessionControllerProvider).value?.id;
  bool sameSession() => ref.context.mounted && ref.read(sessionControllerProvider).value?.id == accountId;

  await api.replaceInterests(interests);
  if (!sameSession()) return false;
  await api.updatePreferences(preferences);
  if (!sameSession()) return false;
  ref.invalidate(profileProvider);
  return true;
}
