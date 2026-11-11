import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/device_location.dart';
import '../domain/location_consent.dart';
import '../domain/user_location.dart';
import 'location_consent_controller.dart';
import 'location_providers.dart';

/// Ubicación desde la que se buscan los eventos cercanos.
///
/// Solo lee la del dispositivo si el usuario dio su consentimiento en la app (Ley 1581); en
/// cualquier otro caso usa la ubicación del piloto. Nunca falla: invalidarlo vuelve a intentar.
final userLocationProvider = FutureProvider<UserLocation>((ref) async {
  final consent = await ref.watch(locationConsentControllerProvider.future);
  if (consent != LocationConsent.granted) return const UserLocation.fallback(LocationFallbackReason.consentDeclined);

  try {
    return UserLocation.device(await ref.watch(deviceLocationProvider).currentPosition());
  } on LocationUnavailableException catch (e) {
    return UserLocation.fallback(e.reason);
  }
});
