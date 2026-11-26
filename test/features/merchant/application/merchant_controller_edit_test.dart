import 'dart:async';

import 'package:festa/features/auth/application/session_controller.dart';
import 'package:festa/features/auth/domain/account.dart';
import 'package:festa/features/location/domain/geo_point.dart';
import 'package:festa/features/merchant/application/merchant_controller.dart';
import 'package:festa/features/merchant/application/merchant_providers.dart';
import 'package:festa/features/merchant/data/merchant_api.dart';
import 'package:festa/features/merchant/domain/merchant_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fakes.dart';

class _FakeSession extends SessionController {
  /// Simula que otra cuenta inicia sesión (la respuesta de la anterior puede llegar tarde).
  void switchTo(Account? account) => state = AsyncData(account);

  @override
  Future<Account?> build() async => testMerchantAccount;
}

MerchantProfile _profile({required String businessName, required MerchantStatus status, String? rejectionReason}) =>
    MerchantProfile(
      draft: MerchantDraft(
        businessName: businessName,
        category: MerchantCategory.gastronomico,
        address: 'Calle 1 # 2-3',
        location: const GeoPoint(latitude: 4.6, longitude: -74.0),
      ),
      status: status,
      rejectionReason: rejectionReason,
    );

MerchantDraft _draft(String businessName) => MerchantDraft(
  businessName: businessName,
  category: MerchantCategory.gastronomico,
  address: 'Calle 1 # 2-3',
  location: const GeoPoint(latitude: 4.6, longitude: -74.0),
);

class _MockApi extends Mock implements MerchantApi {}

void main() {
  setUpAll(() => registerFallbackValue(_draft('x')));

  late _MockApi api;
  late ProviderContainer container;

  setUp(() {
    api = _MockApi();
    container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(() => _FakeSession()),
        merchantApiProvider.overrideWithValue(api),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<MerchantController> loadWith(MerchantProfile current) async {
    when(() => api.mine()).thenAnswer((_) async => current);
    final sub = container.listen(merchantControllerProvider, (_, _) {});
    await container.read(merchantControllerProvider.future);
    addTearDown(sub.close);
    return container.read(merchantControllerProvider.notifier);
  }

  test('editar un perfil pendiente envía PATCH con el borrador y guarda la fila devuelta', () async {
    final controller = await loadWith(_profile(businessName: 'Café', status: MerchantStatus.pending));
    final saved = _profile(businessName: 'Café Central', status: MerchantStatus.pending);
    when(() => api.update(any())).thenAnswer((_) async => saved);

    await controller.save(_draft('Café Central'));

    verify(
      () => api.update(any(that: isA<MerchantDraft>().having((d) => d.businessName, 'businessName', 'Café Central'))),
    ).called(1);
    verifyNever(() => api.submit(any()));
    final state = container.read(merchantControllerProvider).value!;
    expect(state.draft.businessName, 'Café Central');
    expect(state.status, MerchantStatus.pending);
  });

  test('editar un perfil verificado conserva el estado verificado en la fila devuelta', () async {
    final controller = await loadWith(_profile(businessName: 'Café', status: MerchantStatus.verified));
    when(() => api.update(any()))
        .thenAnswer((_) async => _profile(businessName: 'Café Central', status: MerchantStatus.verified));

    await controller.save(_draft('Café Central'));

    final state = container.read(merchantControllerProvider).value!;
    expect(state.draft.businessName, 'Café Central');
    expect(state.status, MerchantStatus.verified);
    expect(state.canPublish, isTrue);
  });

  test('corregir un perfil rechazado reenvía los datos y vuelve a pendiente sin el motivo anterior', () async {
    final controller = await loadWith(
      _profile(businessName: 'Café', status: MerchantStatus.rejected, rejectionReason: 'Dirección incompleta'),
    );
    when(() => api.update(any()))
        .thenAnswer((_) async => _profile(businessName: 'Café Central', status: MerchantStatus.pending));

    await controller.save(_draft('Café Central'));

    final state = container.read(merchantControllerProvider).value!;
    expect(state.draft.businessName, 'Café Central');
    expect(state.status, MerchantStatus.pending);
    expect(state.rejectionReason, isNull);
  });

  test('si la sesión cambia mientras se guarda, la respuesta tardía no pisa el perfil de la cuenta nueva', () async {
    const otraCuenta = Account(id: 'm2', email: 'otro@escuelaing.edu.co', displayName: 'Otro', role: Role.merchant);
    final cuentaVieja = _profile(businessName: 'Café', status: MerchantStatus.verified);
    final cuentaNueva = _profile(businessName: 'Panadería', status: MerchantStatus.pending);
    final controller = await loadWith(cuentaVieja);
    when(() => api.mine()).thenAnswer((_) async => cuentaNueva); // lo que verá la cuenta que entra

    final respuesta = Completer<MerchantProfile>();
    when(() => api.update(any())).thenAnswer((_) => respuesta.future);
    final guardado = controller.save(_draft('Café Central'));

    // Otro comercio inicia sesión antes de que llegue la respuesta de la cuenta anterior.
    (container.read(sessionControllerProvider.notifier) as _FakeSession).switchTo(otraCuenta);
    expect((await container.read(merchantControllerProvider.future))?.draft.businessName, 'Panadería');

    respuesta.complete(_profile(businessName: 'Café Central', status: MerchantStatus.verified));
    await guardado;

    final state = container.read(merchantControllerProvider).value!;
    expect(state.draft.businessName, 'Panadería');
    expect(state.status, MerchantStatus.pending);
  });
}
