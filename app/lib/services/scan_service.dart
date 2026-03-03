//lib/services/scan_service.dart

import 'package:flutter/material.dart';
import '../models/artikel_model.dart';
import '../screens/qr_scan_screen_mobile_scanner.dart';

class ScanService {
  static Future<void> scanArtikel(
    BuildContext context,
    List<Artikel> artikelListe,
    Future<void> Function() reloadArtikel,
    void Function(void Function()) setState,
  ) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QRScanScreen()),
    );
    if (!context.mounted) return;
    if (result is Artikel) {
      setState(() {
        final index = artikelListe.indexWhere((a) => a.id == result.id);
        if (index != -1) {
          artikelListe[index] = result;
        }
      });
    } else if (result == 'deleted') {
      setState(() {
        artikelListe.removeWhere((a) => a.id == result.id);
      });
    } else {
      await reloadArtikel();
    }
  }
}
