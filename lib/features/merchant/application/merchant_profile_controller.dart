import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/http_providers.dart';
import '../data/merchant_api.dart';
import '../domain/merchant_profile.dart';

final merchantApiProvider = Provider<MerchantApi>((ref) => MerchantApi(ref.watch(authenticatedDioProvider)));

final merchantProfileControllerProvider = AsyncNotifierProvider<MerchantProfileController, MerchantProfile?>(
  MerchantProfileController.new,
);

class MerchantProfileController extends AsyncNotifier<MerchantProfile?> {
  @override
  Future<MerchantProfile?> build() => ref.watch(merchantApiProvider).getMyProfile();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(merchantApiProvider).getMyProfile());
  }

  Future<void> submit(MerchantProfileInput profile) async {
    final saved = await ref.read(merchantApiProvider).submitProfile(profile);
    state = AsyncData(saved);
  }

  Future<void> updateProfile(MerchantProfileInput profile) async {
    final saved = await ref.read(merchantApiProvider).updateProfile(profile);
    state = AsyncData(saved);
  }
}
