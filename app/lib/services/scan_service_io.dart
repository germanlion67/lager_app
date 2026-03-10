// lib/services/scan_service_io.dart
//
// Mobile/Desktop: Navigiert zum QR-Scanner Screen.

import 'package:flutter/material.dart';
import '../screens/qr_scan_screen_mobile_scanner.dart';

/// Öffnet den QR-Scanner Screen und gibt das Ergebnis zurück.
Future<dynamic> openQrScanner(BuildContext context) async {
  return await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const QRScanScreen()),
  );
}
