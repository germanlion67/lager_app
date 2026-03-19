// lib/services/pdf_service_web.dart
//
// Web-Implementierung des PdfSaver.
// Verwendet package:web + dart:js_interop statt dem deprecated dart:html.
//
// Diese Datei wird NUR auf Flutter Web kompiliert (conditional import in
// pdf_service.dart). Niemals direkt importieren!

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:web/web.dart' as web;

import 'pdf_service_shared.dart';

/// Web-Implementierung: Löst einen Browser-Download aus.
///
/// Es gibt keinen lokalen Dateipfad im Web — [savePdfBytes] gibt daher
/// immer `null` zurück. Der Download wird direkt beim Aufruf ausgelöst.
class PdfSaverImpl implements PdfSaver {
  final Logger _logger = Logger();

  /// Löst einen Browser-Download für [pdfBytes] aus.
  ///
  /// Erstellt einen temporären Object-URL, klickt ihn programmatisch an
  /// und gibt ihn danach sofort wieder frei.
  /// Gibt immer `null` zurück — kein lokaler Pfad im Web.
  @override
  Future<String?> savePdfBytes(
    Uint8List pdfBytes,
    String fileName,
    String dialogTitle,
  ) async {
    try {
      // Uint8List → JSUint8Array für package:web
      final jsArray = pdfBytes.toJS;

      // Blob aus den PDF-Bytes erstellen
      final blobParts = [jsArray].toJS;
      final blobOptions = web.BlobPropertyBag(type: 'application/pdf');
      final blob = web.Blob(blobParts, blobOptions);

      // Temporäre Object-URL erzeugen
      final url = web.URL.createObjectURL(blob);

      // Unsichtbares <a>-Element erstellen und klicken
      final anchor =
          web.document.createElement('a') as web.HTMLAnchorElement
            ..href = url
            ..setAttribute('download', fileName)
            ..style.display = 'none';

      web.document.body?.append(anchor);
      anchor.click();

      // Aufräumen: Element entfernen und URL freigeben
      anchor.remove();
      web.URL.revokeObjectURL(url);

      _logger.i(
        'Web-Download ausgelöst: $fileName (${pdfBytes.length} bytes)',
      );

      // Im Web gibt es keinen lokalen Pfad → null zurückgeben
      return null;
    } catch (e, stack) {
      _logger.e('Web-Download Fehler:', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Im Web ist kein separates "Öffnen" nötig — der Download wurde bereits
  /// durch [savePdfBytes] ausgelöst. Gibt immer `true` zurück.
  @override
  Future<bool> openPdf(String filePath) async {
    _logger.d('openPdf auf Web aufgerufen — kein lokaler Pfad, kein Action.');
    return true;
  }

  /// Im Web gibt es kein lokales Dateisystem — gibt immer `null` zurück.
  @override
  Future<Uint8List?> readLocalImageBytes(String path) async {
    return null;
  }
}