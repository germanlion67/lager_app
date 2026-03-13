// lib/services/pdf_service_stub.dart
// Web-Stub: PDF-Export ist nur auf Mobile/Desktop verfügbar

import '../models/artikel_model.dart';

class PdfService {
  // Fix: async => null → expression body ohne async —
  // kein await nötig, Future.value(null) wird implizit gewrappt
  Future<dynamic> generateArtikelListePdf(List<Artikel> artikelListe) async =>
      null;

  Future<dynamic> generateArtikelDetailPdf(Artikel artikel) async => null;

  static Future<bool> openPdf(String filePath) async => false;
}