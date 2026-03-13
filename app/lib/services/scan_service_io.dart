// lib/services/scan_service_io.dart
//
// Mobile/Desktop Implementierung des QR-Scanners.
// Wird via Conditional Import in scan_service.dart eingebunden.
// Nicht direkt importieren.

import 'package:flutter/material.dart';

import 'scan_result.dart';
import '../screens/qr_scan_screen_mobile_scanner.dart';

/// Öffnet den QR-Scanner-Screen und gibt ein typsicheres [ScanResult] zurück.
Future<Object?> openQrScanner(BuildContext context) async {
  final result = await Navigator.of(context).push<Object?>(
    MaterialPageRoute(
      builder: (_) => const QRScanScreen(),
    ),
  );
  return result;
}