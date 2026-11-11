import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/http_providers.dart';
import '../data/consents_api.dart';
import '../data/device_location.dart';
import '../data/location_consent_store.dart';

final locationConsentStoreProvider = Provider<LocationConsentStore>((ref) => SharedPreferencesLocationConsentStore());

final consentsApiProvider = Provider<ConsentsApi>((ref) => ConsentsApi(ref.watch(authenticatedDioProvider)));

final deviceLocationProvider = Provider<DeviceLocation>((ref) => const GeolocatorDeviceLocation());
