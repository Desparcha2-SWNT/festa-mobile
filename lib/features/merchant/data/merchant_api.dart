import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/merchant_profile.dart';

/// Solicitud del contrato de user-service. Teléfono y NIT/RUT aún no son aceptados por el backend.
class MerchantRequest {
  const MerchantRequest({
    required this.businessName,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.description,
  });

  final String businessName;
  final String category;
  final String address;
  final double latitude;
  final double longitude;
  final String? description;

  Map<String, dynamic> toJson() => {
    'businessName': businessName,
    'category': category,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    if (description != null && description!.isNotEmpty) 'description': description,
  };
}

/// Vista resumida del estado, compatible con el contrato usado desde develop.
class MerchantStatus {
  const MerchantStatus({required this.verificationStatus, this.rejectionReason});

  factory MerchantStatus.fromJson(Map<String, dynamic> json) => MerchantStatus(
    verificationStatus: (json['verificationStatus'] as String? ?? '').toUpperCase(),
    rejectionReason: json['rejectionReason'] as String?,
  );

  final String verificationStatus;
  final String? rejectionReason;

  bool get approved => verificationStatus == 'VERIFIED' || verificationStatus == 'APPROVED';
  bool get rejected => verificationStatus == 'REJECTED';
}

class MerchantApi {
  MerchantApi(this._dio);

  final Dio _dio;

  Future<MerchantStatus> submit(MerchantRequest request) =>
      _call(() => _dio.post<Map<String, dynamic>>('/api/users/me/merchant', data: request.toJson()));

  Future<MerchantStatus> myMerchant() => _call(() => _dio.get<Map<String, dynamic>>('/api/users/me/merchant'));

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

  Future<MerchantStatus> _call(Future<Response<Map<String, dynamic>>> Function() request) async {
    try {
      return MerchantStatus.fromJson((await request()).data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
