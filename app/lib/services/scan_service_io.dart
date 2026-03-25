// lib/services/scan_service_io.dart

import 'package:flutter/material.dart';

import '../services/artikel_db_service.dart';
import '../services/scan_result.dart';
import '../screens/qr_scan_screen_mobile_scanner.dart';

/// Öffnet den QR-Scanner-Screen und gibt ein typsicheres [ScanResult] zurück.
Future<Object?> openQrScanner(
  BuildContext context,
  ArtikelDbService db,
) async {
  final result = await Navigator.of(context).push<Object?>(
    MaterialPageRoute(
      builder: (_) => QRScanScreen(db: db),
    ),
  );
  return result;
}