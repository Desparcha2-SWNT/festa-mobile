import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/http_providers.dart';
import '../data/merchant_api.dart';

final merchantApiProvider = Provider<MerchantApi>((ref) => MerchantApi(ref.watch(authenticatedDioProvider)));

/// Estado de verificación del comercio de la sesión.
final merchantStatusProvider = FutureProvider.autoDispose<MerchantStatus>(
  (ref) => ref.watch(merchantApiProvider).myMerchant(),
);
