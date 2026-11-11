import '../../location/domain/geo_point.dart';

/// Categoría del comercio (`BusinessCategory` en user-service).
enum MerchantCategory {
  cultural('Cultural'),
  musical('Musical'),
  deportivo('Deportivo'),
  gastronomico('Gastronómico'),
  otro('Otro');

  const MerchantCategory(this.label);

  final String label;

  String get apiValue => name.toUpperCase();

  static MerchantCategory fromApi(String value) => MerchantCategory.values.byName(value.toLowerCase());
}

/// Estado de la verificación manual que hace el equipo Festa (RF3).
enum MerchantStatus {
  pending,
  verified,
  rejected;

  static MerchantStatus fromApi(String value) => MerchantStatus.values.byName(value.toLowerCase());
}

/// Lo que el comercio llena en el formulario. Es lo mismo al enviarlo por primera vez y al editarlo.
class MerchantDraft {
  const MerchantDraft({
    required this.businessName,
    required this.category,
    required this.address,
    required this.location,
    this.description = '',
  });

  final String businessName;
  final MerchantCategory category;
  final String address;
  final GeoPoint location;
  final String description;

  Map<String, dynamic> toJson() => {
    'businessName': businessName,
    'category': category.apiValue,
    'address': address,
    'latitude': location.latitude,
    'longitude': location.longitude,
    'description': description,
  };
}

/// Perfil de comercio de la cuenta, tal como lo devuelve user-service (`/users/me/merchant`).
class MerchantProfile {
  const MerchantProfile({required this.draft, required this.status, this.rejectionReason});

  factory MerchantProfile.fromJson(Map<String, dynamic> json) => MerchantProfile(
    draft: MerchantDraft(
      businessName: json['businessName'] as String,
      category: MerchantCategory.fromApi(json['category'] as String),
      address: json['address'] as String,
      location: GeoPoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      ),
      description: json['description'] as String? ?? '',
    ),
    status: MerchantStatus.fromApi(json['verificationStatus'] as String),
    rejectionReason: json['rejectionReason'] as String?,
  );

  final MerchantDraft draft;
  final MerchantStatus status;

  /// Motivo que escribió el equipo Festa al rechazar; solo viene si [status] es `rejected`.
  final String? rejectionReason;
}
