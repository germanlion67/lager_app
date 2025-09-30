//lib/services/pdf_service.dart

//📄 PDF-Service für Artikelverwaltung
//
//Funktionen:
//• generateArtikelListePdf() - Erstellt eine formatierte PDF-Liste aller Artikel
//• generateArtikelDetailPdf() - Erstellt eine detaillierte PDF für einen einzelnen Artikel im DIN A4 Format
//  - Bindet vorhandene Bilder direkt in die PDF ein
//  - Zeigt bei fehlendem lokalem Bild den Nextcloud-Pfad an
//  - Professionelles Layout mit Tabellen und strukturierten Informationen
//
//Die PDFs werden über einen Save-Dialog gespeichert (standardmäßig im Download-Ordner).
//Bei Abbruch des Dialogs wird null zurückgegeben (kein automatisches Speichern).
//Geeignet für Berichte, Inventarlisten, Archivierung oder Dokumentation.


import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';

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

  /// Erstellt eine detaillierte PDF für einen einzelnen Artikel im DIN A4 Format
  /// Bindet Bilder ein wenn vorhanden, andernfalls wird der Nextcloud-Pfad angezeigt
  /// Gibt null zurück wenn der Save-Dialog abgebrochen wurde
  Future<File?> generateArtikelDetailPdf(Artikel artikel) async {
    final pdf = pw.Document();

    // Versuche das Bild zu laden, falls vorhanden
    pw.Image? artikelBild;
    if (artikel.bildPfad.isNotEmpty && File(artikel.bildPfad).existsSync()) {
      try {
        final imageFile = File(artikel.bildPfad);
        final imageBytes = await imageFile.readAsBytes();
        artikelBild = pw.Image(pw.MemoryImage(imageBytes));
      } catch (e) {
        // Bild konnte nicht geladen werden, wird ignoriert
        artikelBild = null;
      }
    }

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 2),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('ARTIKEL-DETAILS', 
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text('Exportiert am: ${DateTime.now().toLocal().toString().substring(0, 19)}',
                    style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
            
            pw.SizedBox(height: 30),
            
            // Artikel-Info und Bild nebeneinander (wenn Bild vorhanden)
            artikelBild != null 
              ? pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Artikel-Daten (linke Spalte)
                    pw.Expanded(
                      flex: 3,
                      child: _buildArtikelInfoColumn(artikel),
                    ),
                    pw.SizedBox(width: 20),
                    // Bild (rechte Spalte)
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        children: [
                          pw.Container(
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(),
                            ),
                            child: pw.AspectRatio(
                              aspectRatio: 1,
                              child: artikelBild,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text('Bildpfad:', 
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Text(artikel.bildPfad, 
                            style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ),
                  ],
                )
              : pw.Column(
                  children: [
                    _buildArtikelInfoColumn(artikel),
                    // Kein lokales Bild - zeige Nextcloud-Pfad wenn vorhanden
                    if (artikel.remoteBildPfad?.isNotEmpty == true) ...[
                      pw.SizedBox(height: 20),
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Nextcloud-Bildpfad:', 
                              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 4),
                            pw.Text(artikel.remoteBildPfad ?? '', 
                              style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
            
            // Erweiterte Informationen
            pw.SizedBox(height: 30),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('ZUSÄTZLICHE INFORMATIONEN', 
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text('Erstellt am: ${artikel.erstelltAm.toLocal().toString().substring(0, 19)}', 
                          style: const pw.TextStyle(fontSize: 11)),
                      ),
                      pw.Expanded(
                        child: pw.Text('Aktualisiert am: ${artikel.aktualisiertAm.toLocal().toString().substring(0, 19)}', 
                          style: const pw.TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  if (artikel.id != null) ...[
                    pw.SizedBox(height: 8),
                    pw.Text('Artikel-ID: ${artikel.id}', 
                      style: const pw.TextStyle(fontSize: 11)),
                  ],
                ],
              ),
            ),
            
            // Footer
            pw.Spacer(),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide()),
              ),
              child: pw.Text('Erstellt mit Lager-App • ${DateTime.now().toLocal().toString().substring(0, 19)}', 
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center),
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

  /// Hilfsmethode für die Artikel-Informationen Spalte
  pw.Widget _buildArtikelInfoColumn(Artikel artikel) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Artikelname
          pw.Text(artikel.name, 
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 15),
          
          // Hauptdaten in Tabellen-Format
          pw.Table(
            columnWidths: const {
              0: pw.FixedColumnWidth(100),
              1: pw.FlexColumnWidth(),
            },
            children: [
              pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text('Menge:', 
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text('${artikel.menge}', 
                    style: const pw.TextStyle(fontSize: 14)),
                ),
              ]),
              pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text('Lagerort:', 
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text(artikel.ort, 
                    style: const pw.TextStyle(fontSize: 14)),
                ),
              ]),
              pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text('Fach:', 
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text(artikel.fach, 
                    style: const pw.TextStyle(fontSize: 14)),
                ),
              ]),
            ],
          ),
          
          // Beschreibung (wenn vorhanden)
          if (artikel.beschreibung.isNotEmpty) ...[
            pw.SizedBox(height: 15),
            pw.Text('Beschreibung:', 
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5),
              ),
              child: pw.Text(artikel.beschreibung, 
                style: const pw.TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  /// Öffnet eine PDF-Datei mit dem Standard-PDF-Viewer des Systems
  static Future<bool> openPdf(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final uri = Uri.file(filePath);
        return await launchUrl(uri);
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
