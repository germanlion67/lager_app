// lib/services/scan_service.dart
//
// Conditional Import: automatische Plattform-Auswahl.
// Mobile/Desktop → scan_service_io.dart
// Web            → scan_service_stub.dart

import 'package:flutter/material.dart';

import 'scan_result.dart';
import '../models/artikel_model.dart';

import 'scan_service_io.dart'
    if (dart.library.html) 'scan_service_stub.dart' as platform;

class ScanService {
  /// True auf Mobile/Desktop, false im Web.
  static bool get isAvailable => !const bool.fromEnvironment('dart.library.html');

  /// Öffnet den QR-Scanner und verarbeitet das Ergebnis.
  ///
  /// Parameter spiegeln den bisherigen Aufruf in artikel_list_screen.dart:
  ///   ScanService.scanArtikel(context, _artikelListe, _ladeArtikel, setState)
  ///
  /// [artikelListe]  — aktuelle Liste (wird für Snackbar-Feedback genutzt)
  /// [onRefresh]     — wird nach erfolgreichem Scan aufgerufen
  /// [setStateCallback] — wird nach erfolgreichem Scan aufgerufen
  static Future<void> scanArtikel(
    BuildContext context,
    List<Artikel> artikelListe,
    Future<void> Function() onRefresh,
    void Function(void Function()) setStateCallback,
  ) async {
    final Object? raw = await platform.openQrScanner(context);

    if (!context.mounted) return;

    switch (raw) {
      case ScanResultArtikel(:final artikel):
        // Artikel wurde bearbeitet → Liste neu laden
        await onRefresh();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Artikel aktualisiert: ${artikel.name}')),
        );

      case ScanResultDeleted(:final uuid):
        // Artikel wurde gelöscht → aus lokaler Liste entfernen + neu laden
        await onRefresh();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Artikel gelöscht (UUID: $uuid)')),
        );

      case ScanResultCancelled():
        // Kein Feedback nötig — Nutzer hat abgebrochen
        break;

      case ScanResultError(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scanner-Fehler: $message'),
            backgroundColor: Colors.red,
          ),
        );

      case null:
        // Web-Stub oder unerwartetes null — kein Feedback
        break;

      default:
        // Unbekanntes Ergebnis — defensiv ignorieren
        break;
    }
  }
}