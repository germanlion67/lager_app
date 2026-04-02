// lib/screens/qr_scan_screen_mobile_scanner.dart
//
// QR-Scanner Screen — nutzt mobile_scanner für Kamera-Zugriff.
// Overlay-Farben (schwarz/weiß/rot) sind funktional für den Kamera-Scan
// und werden bewusst nicht über colorScheme gesteuert.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../config/app_config.dart';
import '../models/artikel_model.dart';
import '../services/app_log_service.dart';
import '../services/artikel_db_service.dart';
import '../services/scan_result.dart';
import 'artikel_detail_screen.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({
    super.key,
    required this.db,
  });

  /// Wird von außen übergeben — keine neue Instanz pro Scan.
  final ArtikelDbService db;

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen>
    with WidgetsBindingObserver {
  static final _log = AppLogService.logger;

  // Overlay-Konstanten — funktional für Kamera-Scan, nicht semantisch
  static const _overlaySize = 250.0;
  static const _overlayRadius = AppConfig.borderRadiusXLarge;
  static const _scanBorderWidth = AppConfig.strokeWidthThick;

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
        if (!_isProcessing) {
          _controller.start();
          _subscription?.resume();
        }
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

    setState(() {
      _scanResult = code;
      _isProcessing = true;
    });

    _subscription?.pause();
    await _controller.stop();

    try {
      await _verarbeiteCode(code);
    } catch (e, st) {
      _log.e('[QRScan] Fehler beim Verarbeiten', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Scannen: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        unawaited(_controller.start());
        _subscription?.resume();
      }
    }
  }

  /// Verarbeitet einen gescannten Code.
  ///
  /// Erwartet eine Artikelnummer (int, z.B. 1042).
  /// Sucht den Artikel in der lokalen DB nach [artikelnummer].
  Future<void> _verarbeiteCode(String code) async {
    _log.d('[QRScan] Code gescannt: $code');

    final int? artikelnummer = int.tryParse(code.trim());
    if (artikelnummer == null) {
      _log.w('[QRScan] Kein gültiger int-Wert: "$code"');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ungültiger QR-Code: "$code"\n'
              'Erwartet wird eine Artikelnummer (z.B. 1042)'),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final alleArtikel = await widget.db.getAlleArtikel();

    if (!mounted) return;

    final Artikel? gefunden = alleArtikel.cast<Artikel?>().firstWhere(
          (a) => a?.artikelnummer == artikelnummer,
          orElse: () => null,
        );

    if (gefunden == null) {
      _log.w('[QRScan] Kein Artikel mit Artikelnummer $artikelnummer');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Kein Artikel mit Artikelnummer $artikelnummer gefunden'),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    _log.i('[QRScan] Artikel gefunden: ${gefunden.name} '
        '(Nr. ${gefunden.artikelnummer})');

    final detailResult = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => ArtikelDetailScreen(artikel: gefunden),
      ),
    );

    if (!mounted) return;

    if (detailResult is Artikel) {
      Navigator.of(context).pop(ScanResultArtikel(detailResult));
    } else if (detailResult == 'deleted') {
      Navigator.of(context).pop(ScanResultDeleted(gefunden.uuid));
    } else {
      Navigator.of(context).pop(const ScanResultCancelled());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR-Scan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on),
            tooltip: 'Taschenlampe',
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            tooltip: 'Kamera wechseln',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double left =
              (constraints.maxWidth - _overlaySize) / 2;
          final double top =
              (constraints.maxHeight - _overlaySize) / 2;

          return Stack(
            children: [
              MobileScanner(
                controller: _controller,
                scanWindow: Rect.fromLTWH(
                    left, top, _overlaySize, _overlaySize,),
              ),

              // Abdunklung außerhalb des Scan-Fensters
              // Hinweis: Colors.black54/black/white sind hier funktional
              // für die Kamera-Overlay-Maskierung, nicht semantisch.
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
                        width: _overlaySize,
                        height: _overlaySize,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(_overlayRadius),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Scan-Rahmen
              Positioned(
                left: left,
                top: top,
                child: Container(
                  width: _overlaySize,
                  height: _overlaySize,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.red,
                      width: _scanBorderWidth,
                    ),
                    borderRadius:
                        BorderRadius.circular(_overlayRadius),
                  ),
                ),
              ),

              // Hinweistext
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Text(
                  'Artikelnummer-QR-Code ins Fenster halten',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),

              // Lade-Indikator
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