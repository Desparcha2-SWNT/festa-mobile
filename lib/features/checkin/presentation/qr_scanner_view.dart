import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/design/design.dart';

/// Construye la vista de la cámara que lee QR y llama a [onCode] con el texto leído. Es un provider para
/// que las pruebas la sustituyan: en un test no hay cámara.
typedef QrScannerBuilder = Widget Function(ValueChanged<String> onCode);

final qrScannerBuilderProvider = Provider<QrScannerBuilder>(
  (ref) =>
      (onCode) => CameraQrScanner(onCode: onCode),
);

/// La cámara trasera, solo códigos QR y sin repetir el mismo código mientras siga a la vista.
class CameraQrScanner extends StatefulWidget {
  const CameraQrScanner({required this.onCode, super.key});

  final ValueChanged<String> onCode;

  @override
  State<CameraQrScanner> createState() => _CameraQrScannerState();
}

class _CameraQrScannerState extends State<CameraQrScanner> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MobileScanner(
    controller: _controller,
    onDetect: (capture) {
      final code = capture.barcodes.firstOrNull?.rawValue;
      if (code != null && code.isNotEmpty) widget.onCode(code);
    },
    errorBuilder: (context, error) => const Center(
      child: Padding(
        padding: EdgeInsets.all(FestaSpace.xl),
        child: Text(
          'No pudimos usar la cámara. Revisa que Festa tenga permiso para usarla en los ajustes del teléfono.',
          textAlign: TextAlign.center,
          style: TextStyle(color: FestaColors.textOnInverse),
        ),
      ),
    ),
  );
}
