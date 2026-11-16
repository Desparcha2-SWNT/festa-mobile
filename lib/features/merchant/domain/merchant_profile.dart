class MerchantProfile {
  const MerchantProfile({
    required this.accountId,
    required this.businessName,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.verificationStatus,
    required this.rejectionReason,
  });

  factory MerchantProfile.fromJson(Map<String, dynamic> json) => MerchantProfile(
    accountId: json['accountId'] as String,
    businessName: json['businessName'] as String,
    category: json['category'] as String,
    address: json['address'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    description: json['description'] as String? ?? '',
    verificationStatus: json['verificationStatus'] as String,
    rejectionReason: json['rejectionReason'] as String?,
  );

  final String accountId;
  final String businessName;
  final String category;
  final String address;
  final double latitude;
  final double longitude;
  final String description;
  final String verificationStatus;
  final String? rejectionReason;
}

class MerchantProfileInput {
  const MerchantProfileInput({
    required this.businessName,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.description,
  });

  final String businessName;
  final String category;
  final String address;
  final double latitude;
  final double longitude;
  final String description;

  Map<String, dynamic> toJson() => {
    'businessName': businessName,
    'category': category,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'description': description,
  };
}

abstract final class MerchantCategory {
  static const values = {
    'CULTURAL': 'Cultural',
    'MUSICAL': 'Musical',
    'DEPORTIVO': 'Deportivo',
    'GASTRONOMICO': 'Gastronómico',
    'OTRO': 'Otro',
  };
}
