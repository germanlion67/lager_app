import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/artikel_db_service.dart';
import '../models/artikel_model.dart';
import 'artikel_detail_screen.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  String? _scanResult;
  bool _isProcessing = false;
  final MobileScannerController _controller = MobileScannerController();

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.first;
    final String? code = barcode.rawValue;

    if (code != null) {
      setState(() {
        _scanResult = code;
        _isProcessing = true;
      });

      int? artikelId = int.tryParse(code);
      if (artikelId != null) {
        final artikel = await ArtikelDbService().getAlleArtikel();
        final gefunden = artikel.firstWhere(
          (a) => a.id == artikelId,
          orElse: () => Artikel(
            id: null,
            name: 'Nicht gefunden',
            menge: 0,
            ort: '',
            fach: '',
            beschreibung: '',
            bildPfad: '',
            remoteBildPfad: '',
            erstelltAm: DateTime.now(),
            aktualisiertAm: DateTime.now(),
          ),
        );

        if (!mounted) return;

        if (gefunden.id != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArtikelDetailScreen(artikel: gefunden),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Artikel nicht gefunden')),
          );
        }
      }

      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR-Scan')),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),
          if (_scanResult != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Letzter Scan: $_scanResult'),
            ),
        ],
      ),
    );
  }
}
