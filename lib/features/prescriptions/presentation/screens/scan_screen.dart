import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Scan du QR code d'une ordonnance. Renvoie le texte lu.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _lu = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _detecter(BarcodeCapture capture) {
    if (_lu) {
      return;
    }
    for (final Barcode b in capture.barcodes) {
      final String? valeur = b.rawValue;
      if (valeur != null && valeur.isNotEmpty) {
        _lu = true;
        Navigator.pop(context, valeur);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scanner l'ordonnance")),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _detecter),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Text(
              "Placez le QR code de l'ordonnance dans le cadre",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
