//lib/services/pdf_service.dart

//📄 PDF-Service für Artikelverwaltung
//
//Funktionen:
//• generateArtikelListePdf() - Erstellt eine formatierte PDF-Liste aller Artikel
//• generateArtikelDetailPdf() - Erstellt eine detaillierte PDF für einen einzelnen Artikel
//
//Die PDFs werden über einen Save-Dialog gespeichert (standardmäßig im Download-Ordner).
//Bei Abbruch des Dialogs erfolgt automatisches Speichern im App-Dokumentenverzeichnis.
//Geeignet für Berichte, Inventarlisten oder Archivierung.


import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../models/artikel_model.dart';

class PdfService {
  /// Erstellt eine PDF-Liste mit allen Artikeln
  /// Gibt null zurück wenn der Save-Dialog abgebrochen wurde
  Future<File?> generateArtikelListePdf(List<Artikel> artikelListe) async {
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

    final pdfBytes = await pdf.save();
    final fileName = 'artikel_liste_${DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19)}.pdf';
    
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Artikelliste als PDF speichern',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: Uint8List.fromList(pdfBytes),
    );
    
    if (savedPath != null) {
      return File(savedPath);
    } else {
      // Benutzer hat Dialog abgebrochen
      return null;
    }
  }

  /// Erstellt eine detaillierte PDF für einen einzelnen Artikel
  /// Gibt null zurück wenn der Save-Dialog abgebrochen wurde
  Future<File?> generateArtikelDetailPdf(Artikel artikel) async {
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

    final pdfBytes = await pdf.save();
    final cleanName = artikel.name.replaceAll(RegExp(r'[^\w\s-]'), '_');
    final fileName = 'artikel_detail_${cleanName}_${DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19)}.pdf';
    
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Artikel-Details als PDF speichern',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: Uint8List.fromList(pdfBytes),
    );
    
    if (savedPath != null) {
      return File(savedPath);
    } else {
      // Benutzer hat Dialog abgebrochen
      return null;
    }
  }
}
