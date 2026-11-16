import 'package:festa/features/merchant/data/merchant_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MerchantRequest omite la descripción opcional cuando está vacía', () {
    const request = MerchantRequest(
      businessName: 'Café Central',
      category: 'GASTRONOMICO',
      address: 'Calle 1 # 2-3',
      latitude: 4.6,
      longitude: -74,
      description: '',
    );

    expect(request.toJson(), {
      'businessName': 'Café Central',
      'category': 'GASTRONOMICO',
      'address': 'Calle 1 # 2-3',
      'latitude': 4.6,
      'longitude': -74,
    });
  });

  test('MerchantStatus reconoce VERIFIED del backend como aprobado', () {
    final status = MerchantStatus.fromJson({'verificationStatus': 'VERIFIED'});

    expect(status.approved, isTrue);
    expect(status.rejected, isFalse);
  });

  test('MerchantStatus conserva motivo y estado rechazado', () {
    final status = MerchantStatus.fromJson({
      'verificationStatus': 'REJECTED',
      'rejectionReason': 'No se pudo validar la dirección',
    });

    expect(status.rejected, isTrue);
    expect(status.rejectionReason, 'No se pudo validar la dirección');
  });
}
