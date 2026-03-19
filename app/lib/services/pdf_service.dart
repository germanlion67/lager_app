// lib/services/pdf_service.dart
//
// Öffentlicher Einstiegspunkt für den PDF-Service.
// Verbindet plattformunabhängige Aufbau-Logik (pdf_service_shared.dart)
// mit plattformspezifischem Speichern (pdf_service_io / pdf_service_web).

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import '../models/artikel_model.dart';
import 'pdf_service_shared.dart';

// Conditional Import — zur Compile-Zeit aufgelöst:
//   Nicht-Web → pdf_service_io.dart   (dart:io)
//   Web       → pdf_service_web.dart  (dart:html)
import 'pdf_service_io.dart'
    if (dart.library.html) 'pdf_service_web.dart';

/// PDF-Service für Artikelverwaltung.
///
/// Alle öffentlichen Methoden sind identisch zur alten Version —
/// nur der Rückgabetyp von [generateArtikelListePdf] und
/// [generateArtikelDetailPdf] ist von [File?] auf [String?] (Pfad)
/// geändert, da Web keinen [File]-Typ kennt.
///
/// Plattformverhalten:
/// - Desktop: FilePicker Save-Dialog + xdg-open (Fallback ~/Downloads/)
/// - Mobile:  Download-Ordner + share_plus
/// - Web:     Browser-nativer Download, Rückgabe immer null
class PdfService {
  final Logger _logger = Logger();
  final PdfBuilderService _builder = PdfBuilderService();
  final PdfSaver _saver = PdfSaverImpl();

  // ── Öffentliche API ────────────────────────────────────────────────────────

  /// Erstellt eine PDF-Liste mit allen Artikeln und speichert / lädt sie herunter.
  ///
  /// Rückgabe: Lokaler Pfad (Nicht-Web) oder `null` (Web / Abbruch).
  Future<String?> generateArtikelListePdf(List<Artikel> artikelListe) async {
    final pdfBytes = await _builder.buildArtikelListePdf(artikelListe);
    final fileName = 'artikel_liste_${_builder.fileTimestamp()}.pdf';

    try {
      final path = await _saver.savePdfBytes(
        pdfBytes,
        fileName,
        'Artikelliste als PDF speichern',
      );
      _logger.i(
        path != null
            ? 'Artikelliste PDF gespeichert: $path'
            : 'Artikelliste PDF: Web-Download ausgelöst oder Abbruch',
      );
      return path;
    } catch (e, stack) {
      _logger.e('Fehler beim PDF Export:', error: e, stackTrace: stack);
      throw Exception('Fehler beim PDF Export: $e');
    }
  }

  /// Erstellt eine Detail-PDF für einen Artikel.
  ///
  /// Bild-Laden:
  /// - Nicht-Web: Lokale Datei via [artikel.bildPfad]
  /// - Web:       HTTP via [artikel.remoteBildPfad]
  ///
  /// Rückgabe: Lokaler Pfad (Nicht-Web) oder `null` (Web / Abbruch).
  Future<String?> generateArtikelDetailPdf(Artikel artikel) async {
    // Bild laden — plattformabhängig über den Saver
    final imageBytes = await _loadImageBytes(artikel);

    final pdfBytes = await _builder.buildArtikelDetailPdf(
      artikel,
      imageBytes: imageBytes,
    );

    final cleanName = artikel.name
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^\w\-äöüÄÖÜß]'), '_');
    final fileName =
        'artikel_detail_${cleanName}_${_builder.fileTimestamp()}.pdf';

    try {
      final path = await _saver.savePdfBytes(
        pdfBytes,
        fileName,
        'Artikel-Details als PDF speichern',
      );
      _logger.i(
        path != null
            ? 'Artikel-Detail PDF gespeichert: $path'
            : 'Artikel-Detail PDF: Web-Download ausgelöst oder Abbruch',
      );
      return path;
    } catch (e, stack) {
      _logger.e('Fehler beim PDF Export:', error: e, stackTrace: stack);
      throw Exception('Fehler beim PDF Export: $e');
    }
  }

  /// Öffnet oder teilt eine gespeicherte PDF.
  ///
  /// Im Web No-op → gibt immer `true` zurück.
  static Future<bool> openPdf(String filePath) async {
    return PdfSaverImpl().openPdf(filePath);
  }

  // ── Private Hilfsmethoden ──────────────────────────────────────────────────

  /// Lädt Bild-Bytes plattformabhängig.
  Future<Uint8List?> _loadImageBytes(Artikel artikel) async {
    if (kIsWeb) {
      // Web: Remote-URL via HTTP laden
      final remoteUrl = artikel.remoteBildPfad;
      if (remoteUrl == null || remoteUrl.isEmpty) {
        _logger.d('Web: Kein remoteBildPfad — kein Bild im PDF');
        return null;
      }
      try {
        final response = await http.get(Uri.parse(remoteUrl));
        if (response.statusCode == 200) {
          _logger.i('Web: Bild geladen von $remoteUrl');
          return response.bodyBytes;
        }
        _logger.w('Web: HTTP ${response.statusCode} für $remoteUrl');
        return null;
      } catch (e) {
        _logger.w('Web: Bild-Download Fehler: $e');
        return null;
      }
    } else {
      // Nicht-Web: Lokale Datei über den Saver lesen
      // (dart:io bleibt in pdf_service_io.dart gekapselt)
      return _saver.readLocalImageBytes(artikel.bildPfad);
    }
  }
}