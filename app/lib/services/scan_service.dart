// lib/services/scan_service.dart
//
// QR-Code Scanner Service.
// ⚠️ NUR für Mobile/Desktop – im Web nicht verfügbar.
//
// Verwendet Conditional Import, damit der QR-Scanner-Screen
// im Web nicht importiert wird (würde sonst nicht kompilieren).

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/artikel_model.dart';

// Conditional Import: QR-Scanner nur auf Mobile/Desktop
import 'scan_service_io.dart'
    if (dart.library.html) 'scan_service_stub.dart' as scanner;

class ScanService {
  /// Prüft ob der QR-Scanner auf dieser Plattform verfügbar ist.
  /// Kann im UI verwendet werden um den Scan-Button ein-/auszublenden.
  static bool get isAvailable => !kIsWeb;

  /// Öffnet den QR-Scanner und verarbeitet das Ergebnis.
  ///
  /// [artikelListe] – Die aktuelle Liste der Artikel (wird ggf. aktualisiert).
  /// [reloadArtikel] – Callback zum Neuladen der gesamten Liste.
  /// [setState] – setState-Funktion des aufrufenden Widgets.
  ///
  /// ⚠️ Nur auf Mobile/Desktop aufrufen. Im Web ist dies ein no-op.
  static Future<void> scanArtikel(
    BuildContext context,
    List<Artikel> artikelListe,
    Future<void> Function() reloadArtikel,
    void Function(void Function()) setState,
  ) async {
    // Web: QR-Scanner nicht verfügbar
    if (kIsWeb) {
      debugPrint('[ScanService] QR-Scanner im Web nicht verfügbar');
      return;
    }

    final result = await scanner.openQrScanner(context);
    if (!context.mounted) return;

    if (result is Artikel) {
      // Artikel wurde gescannt und gefunden/bearbeitet
      setState(() {
        final index = artikelListe.indexWhere((a) => a.uuid == result.uuid);
        if (index != -1) {
          artikelListe[index] = result;
        } else {
          // Neuer Artikel – zur Liste hinzufügen
          artikelListe.insert(0, result);
        }
      });
    } else if (result == 'deleted') {
      // Artikel wurde im Scanner-Screen gelöscht → Liste neu laden
      await reloadArtikel();
    } else if (result != null) {
      // Unbekanntes Ergebnis → sicherheitshalber neu laden
      await reloadArtikel();
    }
  }
}
