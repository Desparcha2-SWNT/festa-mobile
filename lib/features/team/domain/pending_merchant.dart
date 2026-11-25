import '../../merchant/domain/merchant_profile.dart';

/// Un comercio que espera la verificación manual del equipo Festa (RF3, SCRUM-61), como lo devuelve
/// `GET /api/users/admin/merchants`: el mismo perfil que llena el comercio, más su cuenta y la fecha de envío.
class PendingMerchant {
  const PendingMerchant({required this.accountId, required this.profile, this.submittedAt});

  factory PendingMerchant.fromJson(Map<String, dynamic> json) => PendingMerchant(
    accountId: json['accountId'] as String,
    profile: MerchantProfile.fromJson(json),
    submittedAt: json['createdAt'] is String ? DateTime.parse(json['createdAt'] as String) : null,
  );

  /// La cuenta del comercio: es el id con el que se aprueba o se rechaza.
  final String accountId;
  final MerchantProfile profile;
  final DateTime? submittedAt;
}
