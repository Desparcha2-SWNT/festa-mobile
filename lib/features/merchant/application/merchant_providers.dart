import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/http_providers.dart';
import '../data/merchant_api.dart';

/// Cliente de los endpoints de comercio de user-service. Exige JWT: usa el cliente autenticado.
final merchantApiProvider = Provider<MerchantApi>((ref) => MerchantApi(ref.watch(authenticatedDioProvider)));
