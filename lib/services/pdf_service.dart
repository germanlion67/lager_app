//lib/services/pdf_service.dart

//📄 Verwendung:
//Übergib eine Liste von Artikel-Objekten
//Die Methode generateArtikelListePdf() erstellt eine formatierte PDF-Datei
//Die Datei wird im lokalen Dokumentenverzeichnis gespeichert


import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/artikel_model.dart';

class PdfService {
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
                pw.Text('Letzte Aktualisierung: ${artikel.aktualisiertAm.toLocal()}'),
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
}
