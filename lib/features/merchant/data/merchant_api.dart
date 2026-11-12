import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';

/// Solicitud de comercio que recibe festa-user-service (`SubmitMerchantRequest`).
/// Teléfono y NIT/RUT no se envían: el backend todavía no los acepta (decisión pendiente del equipo).
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

  /// Valor del enum del backend: CULTURAL, MUSICAL, DEPORTIVO, GASTRONOMICO u OTRO.
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

/// Estado de verificación del comercio, tal como lo devuelve `MerchantResponse`.
class MerchantStatus {
  const MerchantStatus({required this.verificationStatus, this.rejectionReason});

  factory MerchantStatus.fromJson(Map<String, dynamic> json) => MerchantStatus(
    verificationStatus: (json['verificationStatus'] as String? ?? '').toUpperCase(),
    rejectionReason: json['rejectionReason'] as String?,
  );

  final String verificationStatus;
  final String? rejectionReason;

  bool get approved => verificationStatus == 'APPROVED';
  bool get rejected => verificationStatus == 'REJECTED';
}

/// Endpoints de comercio de user-service, expuestos por el gateway bajo `/api/users`.
/// Exigen JWT: se construye con el cliente autenticado.
class MerchantApi {
  MerchantApi(this._dio);

  final Dio _dio;

  Future<MerchantStatus> submit(MerchantRequest request) =>
      _call(() => _dio.post<Map<String, dynamic>>('/api/users/me/merchant', data: request.toJson()));

  Future<MerchantStatus> myMerchant() => _call(() => _dio.get<Map<String, dynamic>>('/api/users/me/merchant'));

  Future<MerchantStatus> _call(Future<Response<Map<String, dynamic>>> Function() request) async {
    try {
      return MerchantStatus.fromJson((await request()).data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
