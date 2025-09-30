//lib/services/pdf_service.dart

//📄 PDF-Service für Artikelverwaltung
//
//Funktionen:
//• generateArtikelListePdf() - Erstellt eine formatierte PDF-Liste aller Artikel
//• generateArtikelDetailPdf() - Erstellt eine detaillierte PDF für einen einzelnen Artikel
//
//Die PDFs werden im lokalen Dokumentenverzeichnis gespeichert und können
//für Berichte, Inventarlisten oder Archivierung verwendet werden.


import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/artikel_model.dart';

class PdfService {
  /// Erstellt eine PDF-Liste mit allen Artikeln
  Future<File> generateArtikelListePdf(List<Artikel> artikelListe) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, text: 'Artikelliste'),
          ...artikelListe.map((artikel) => pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(artikel.name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('Menge: ${artikel.menge}'),
                pw.Text('Ort: ${artikel.ort} • Fach: ${artikel.fach}'),
                pw.Text('Beschreibung: ${artikel.beschreibung}'),
                pw.Text('Erstellt am: ${artikel.erstelltAm.toLocal()}'),
                pw.Text('Aktualisiert am: ${artikel.aktualisiertAm.toLocal()}'),
              ],
            ),
          )),
        ],
      ),
    );

    final outputDir = await getApplicationDocumentsDirectory();
    final file = File('${outputDir.path}/artikel_liste.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Erstellt eine detaillierte PDF für einen einzelnen Artikel
  Future<File> generateArtikelDetailPdf(Artikel artikel) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Header(level: 0, text: 'Artikel-Details'),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(artikel.name, 
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Text('Menge: ${artikel.menge}', style: const pw.TextStyle(fontSize: 14)),
                  pw.SizedBox(height: 5),
                  pw.Text('Lagerort: ${artikel.ort}', style: const pw.TextStyle(fontSize: 14)),
                  pw.SizedBox(height: 5),
                  pw.Text('Fach: ${artikel.fach}', style: const pw.TextStyle(fontSize: 14)),
                  pw.SizedBox(height: 10),
                  if (artikel.beschreibung.isNotEmpty) ...[
                    pw.Text('Beschreibung:', 
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 5),
                    pw.Text(artikel.beschreibung, style: const pw.TextStyle(fontSize: 12)),
                    pw.SizedBox(height: 10),
                  ],
                  pw.Text('Erstellt am: ${artikel.erstelltAm.toLocal()}', 
                    style: const pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 5),
                  pw.Text('Aktualisiert am: ${artikel.aktualisiertAm.toLocal()}', 
                    style: const pw.TextStyle(fontSize: 12)),
                  if (artikel.bildPfad.isNotEmpty) ...[
                    pw.SizedBox(height: 10),
                    pw.Text('Bilddatei: ${artikel.bildPfad}', 
                      style: const pw.TextStyle(fontSize: 10)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final outputDir = await getApplicationDocumentsDirectory();
    final fileName = 'artikel_detail_${artikel.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}.pdf';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
