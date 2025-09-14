//lib/screen/qr_scan_screen_mobile_scanner.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/artikel_db_service.dart';
import '../models/artikel_model.dart';
import 'artikel_detail_screen.dart';
import 'dart:async';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}


class _QRScanScreenState extends State<QRScanScreen> with WidgetsBindingObserver {
  String? _scanResult;
  bool _isProcessing = false;
  final MobileScannerController _controller = MobileScannerController();

  // Punkt 1: StreamSubscription statt nicht-existenter pause/resume Methoden
  StreamSubscription<BarcodeCapture>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  

    // Punkt 2: Listener auf controller.barcodes setzen
    _subscription = _controller.barcodes.listen(_onDetect);
    // Sicherstellen, dass die Kamera läuft (falls MobileScanner Widget es nicht automatisch tut)
    _controller.start();
  }

  @override
  void dispose() {
    // Punkt 3: Subscription sauber abbrechen
    _subscription?.cancel();
    _controller.dispose(); // 🔑 Kamera-Controller sauber freigeben
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Punkt 4: Auf Lifecycle achten - bei Pause die Subscription pausieren und Kamera stoppen
    if (state == AppLifecycleState.paused) {
      _subscription?.pause();
      _controller.stop(); // 🔑 Kamera pausieren, wenn App minimiert wird
    } else if (state == AppLifecycleState.resumed && !_isProcessing) {
      // Nur neu starten, wenn wir gerade nicht in einer Navigation/Verarbeitung sind
      _controller.start();
      _subscription?.resume();

    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    if (capture.barcodes.isEmpty) return;

    final barcode = capture.barcodes.first;
    final String? code = barcode.rawValue;

    if (code != null) {
    setState(() {
      _scanResult = code;
      _isProcessing = true;
    });

    try {
      final int? artikelId = int.tryParse(code);
      if (artikelId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ungültiger QR-Code')),
          );
        }
        return;
      }  

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

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ArtikelDetailScreen(artikel: gefunden),
        ),
      );


      if (gefunden.id != null) {
        // Punkt 5: Subscription pausieren und Kamera stoppen vor Navigation
        _subscription?.pause();
        await _controller.stop(); // Sicherstellen, dass die Kamera gestoppt ist
        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtikelDetailScreen(artikel: gefunden),
          ),
        );

        // Beim Zurückkommen: Status zurücksetzen und Kamera/Subscription wieder starten
        if (mounted) {
          Navigator.pop(context, result);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Artikel nicht gefunden')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Scannen: $e')),
        );
      }
    } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR-Scan')),
      body: Stack(
        children: [
          // Scanner
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Overlay mit Fokusfenster
          LayoutBuilder(
            builder: (context, constraints) {
              final double overlaySize = 250; // Größe des Fokusfensters
              final double left = (constraints.maxWidth - overlaySize) / 2;
              final double top = (constraints.maxHeight - overlaySize) / 2;

              return Stack(
                children: [
                  // Abdunkeln mit "Loch"
                  ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Colors.black54,
                      BlendMode.srcOut,
                    ),
                    child: Stack(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            backgroundBlendMode: BlendMode.dstOut,
                          ),
                        ),
                        Positioned(
                          left: left,
                          top: top,
                          child: Container(
                            width: overlaySize,
                            height: overlaySize,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Roter Rahmen ums Fokusfenster
                  Positioned(
                    left: left,
                    top: top,
                    child: Container(
                      width: overlaySize,
                      height: overlaySize,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Hinweistext unten
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              "Bitte QR-Code ins Fenster halten",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                backgroundColor: Colors.black54,
              ),
            ),
          ),

          // Letzter Scan als Text (optional)
          if (_scanResult != null)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Text(
                'Letzter Scan: $_scanResult',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
  }

