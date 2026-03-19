// lib/services/pdf_service_stub.dart
// Stub für Web — dart:io ist nicht verfügbar.

import '../models/artikel_model.dart';

class PdfService {
  /// Web: Nicht unterstützt — gibt immer null zurück.
  Future<String?> generateArtikelListePdf(List<Artikel> artikelListe) async {
    return null;
  }

  /// Web: Nicht unterstützt — gibt immer null zurück.
  Future<String?> generateArtikelDetailPdf(Artikel artikel) async {
    return null;
  }

  /// Web: No-op — gibt immer true zurück.
  static Future<bool> openPdf(String filePath) async {
    return true;
  }
}
