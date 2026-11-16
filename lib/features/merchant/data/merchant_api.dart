import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/merchant_profile.dart';

class MerchantApi {
  MerchantApi(this._dio);

  final Dio _dio;

  Future<MerchantProfile?> getMyProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/users/me/merchant');
      return MerchantProfile.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiException.fromDio(e);
    }
  }

  Future<MerchantProfile> submitProfile(MerchantProfileInput profile) => _saveProfile(profile, submit: true);

  Future<MerchantProfile> updateProfile(MerchantProfileInput profile) => _saveProfile(profile, submit: false);

  Future<MerchantProfile> _saveProfile(MerchantProfileInput profile, {required bool submit}) async {
    try {
      final response = submit
          ? await _dio.post<Map<String, dynamic>>('/api/users/me/merchant', data: profile.toJson())
          : await _dio.patch<Map<String, dynamic>>('/api/users/me/merchant', data: profile.toJson());
      return MerchantProfile.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
