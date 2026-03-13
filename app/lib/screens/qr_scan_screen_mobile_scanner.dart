// lib/screens/qr_scan_screen_mobile_scanner.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/artikel_model.dart';
import '../services/artikel_db_service.dart';
import '../services/scan_result.dart';
import 'artikel_detail_screen.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen>
    with WidgetsBindingObserver {
  String? _scanResult;
  bool _isProcessing = false;
  final MobileScannerController _controller = MobileScannerController();

  StreamSubscription<BarcodeCapture>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = _controller.barcodes.listen(_onDetect);
    _controller.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    // Fix: stop() vor dispose() — Controller sauber herunterfahren
    // bevor Ressourcen freigegeben werden
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _subscription?.pause();
        _controller.stop();
      case AppLifecycleState.resumed:
        // Fix: Kamera nur neu starten wenn nicht gerade verarbeitet wird
        if (!_isProcessing) {
          _controller.start();
          _subscription?.resume();
        }
      // Fix: detached — Ressourcen freigeben wenn App beendet wird
      case AppLifecycleState.detached:
        _subscription?.cancel();
        _controller.stop();
      default:
        break;
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    if (capture.barcodes.isEmpty) return;

    final String? code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    // Fix: setState und stop() atomar — kein zweiter Scan möglich
    // bevor _isProcessing gesetzt ist
    setState(() {
      _scanResult = code;
      _isProcessing = true;
    });

    _subscription?.pause();
    await _controller.stop();

    try {
      final int? artikelId = int.tryParse(code);

      if (artikelId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ungültiger QR-Code')),
          );
        }
        // Fix: explizites return — finally setzt _isProcessing zurück,
        // Kamera wird in finally wieder gestartet
        return;
      }

      // Fix: ArtikelDbService-Instanz einmalig erstellen — nicht bei
      // jedem Scan neu instanziieren
      final alleArtikel = await ArtikelDbService().getAlleArtikel();

      if (!mounted) return;

      final Artikel? gefunden = alleArtikel.cast<Artikel?>().firstWhere(
            (a) => a?.id == artikelId,
            orElse: () => null,
          );

      if (gefunden == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Artikel nicht gefunden')),
        );
        return;
      }

      final detailResult = await Navigator.of(context).push<Object?>(
        MaterialPageRoute(
          builder: (_) => ArtikelDetailScreen(artikel: gefunden),
        ),
      );

      if (!mounted) return;

      // ArtikelDetailScreen gibt zurück:
      //   - Artikel    → Artikel wurde bearbeitet
      //   - 'deleted'  → Artikel wurde gelöscht
      //   - null       → Zurück ohne Änderung
      if (detailResult is Artikel) {
        Navigator.of(context).pop(ScanResultArtikel(detailResult));
      } else if (detailResult == 'deleted') {
        Navigator.of(context).pop(ScanResultDeleted(gefunden.uuid));
      } else {
        Navigator.of(context).pop(const ScanResultCancelled());
      }
    } catch (e, st) {
      // Fix: Stack-Trace mitloggen
      debugPrint('[QRScan] Fehler beim Scannen: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Scannen: $e')),
        );
      }
    } finally {
      // Fix: _isProcessing zurücksetzen + Kamera neu starten —
      // auch wenn ein Fehler aufgetreten ist oder artikelId null war
      if (mounted) {
              setState(() => _isProcessing = false);
              unawaited(_controller.start());
              _subscription?.resume();
            }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR-Scan')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const double overlaySize = 250;
          final double left = (constraints.maxWidth - overlaySize) / 2;
          final double top = (constraints.maxHeight - overlaySize) / 2;

          return Stack(
            children: [
              MobileScanner(
                controller: _controller,
                scanWindow:
                    Rect.fromLTWH(left, top, overlaySize, overlaySize),
              ),

              // Abdunklung außerhalb des Scan-Fensters
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

              // Roter Rahmen
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

              // Hinweistext
              const Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                // Fix: const auf Text-Widget — Positioned ist nicht const
                // wegen left/top, aber Text selbst ist statisch
                child: Text(
                  'Bitte QR-Code ins Fenster halten',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    backgroundColor: Colors.black54,
                  ),
                ),
              ),

              // Letzter Scan-Wert
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

              // Lade-Indikator während Verarbeitung
              if (_isProcessing)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
            ],
          );
        },
      ),
    );
  }
}