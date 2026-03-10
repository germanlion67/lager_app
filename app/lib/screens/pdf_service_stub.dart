// lib/services/pdf_service_stub.dart
// Web-Stub: PDF-Export ist nur auf Mobile/Desktop verfügbar

import '../models/artikel_model.dart';

class PdfService {
  Future<dynamic> generateArtikelListePdf(List<Artikel> artikelListe) async {
    // Nicht verfügbar im Web
    return null;
  }

  Future<dynamic> generateArtikelDetailPdf(Artikel artikel) async {
    // Nicht verfügbar im Web
    return null;
  }

  static Future<bool> openPdf(String filePath) async {
    return false;
  }
}