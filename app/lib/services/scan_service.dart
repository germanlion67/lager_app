// lib/services/scan_service.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'scan_result.dart';
import 'artikel_db_service.dart';
import '../models/artikel_model.dart';

import 'scan_service_io.dart'
    if (dart.library.html) 'scan_service_stub.dart' as platform;

class ScanService {
  /// True auf Mobile/Desktop (Kamera-Scanner), false im Web (Texteingabe).
  ///
  /// B-2 FIX: bool.fromEnvironment('dart.library.html') ist zur Laufzeit
  /// immer false — kIsWeb ist der korrekte Runtime-Check.
  /// Der FAB wird auf Web weiterhin angezeigt, aber öffnet den
  /// Texteingabe-Dialog statt den Kamera-Scanner.
  static bool get isAvailable => true; // Immer true — Web zeigt Texteingabe

  /// True nur wenn Kamera-Scanner verfügbar (Mobile/Desktop).
  static bool get hasCameraScanner => !kIsWeb;

  /// Öffnet den Scanner (Kamera auf Mobile, Texteingabe auf Web/Desktop).
  ///
  /// [db] wird durchgereicht um keine neue Instanz pro Scan zu erstellen.
  static Future<void> scanArtikel(
    BuildContext context,
    List<Artikel> artikelListe,
    Future<void> Function() onRefresh,
    void Function(void Function()) setStateCallback,
    ArtikelDbService db,
  ) async {
    final Object? raw = await platform.openQrScanner(context, db);

    if (!context.mounted) return;

    switch (raw) {
      case ScanResultArtikel(:final artikel):
        await onRefresh();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Artikel geöffnet: ${artikel.name}')),
        );

      case ScanResultDeleted(:final uuid):
        await onRefresh();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Artikel gelöscht (UUID: $uuid)')),
        );

      case ScanResultCancelled():
        // Kein Feedback — Nutzer hat abgebrochen
        break;

      case ScanResultError(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $message'),
            backgroundColor: Colors.red,
          ),
        );

      case null:
        break;

      default:
        break;
    }
  }
}