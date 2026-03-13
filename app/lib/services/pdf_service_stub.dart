// lib/services/pdf_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../models/artikel_model.dart';

/// PDF-Service für Artikelverwaltung.
///
/// Funktionen:
/// - [generateArtikelListePdf] — Formatierte PDF-Liste aller Artikel
/// - [generateArtikelDetailPdf] — Detaillierte PDF für einen Artikel (DIN A4)
///
/// Plattformspezifisch:
/// - Desktop: FilePicker Save-Dialog + url_launcher
/// - Mobile: Download-Ordner + share_plus
class PdfService {
  // FIX Problem 6: Instanzklasse mit Logger statt static-Durcheinander.
  final Logger _logger = Logger();

  // ---------------------------------------------------------------------------
  // Öffentliche API
  // ---------------------------------------------------------------------------

  /// Erstellt eine PDF-Liste mit allen Artikeln.
  /// Gibt `null` zurück wenn der Save-Dialog abgebrochen wurde.
  Future<File?> generateArtikelListePdf(List<Artikel> artikelListe) async {
    // FIX Hinweis 10: try/catch um den gesamten PDF-Aufbau.
    late Uint8List pdfBytes;
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Header(level: 0, text: 'Artikelliste'),
            ...artikelListe.map(
              (artikel) => pw.Container(
                margin: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      artikel.name,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text('Menge: ${artikel.menge}'),
                    pw.Text('Ort: ${artikel.ort} • Fach: ${artikel.fach}'),
                    pw.Text('Beschreibung: ${artikel.beschreibung}'),
                    pw.Text('Erstellt am: ${_formatDate(artikel.erstelltAm)}'),
                    pw.Text(
                      'Aktualisiert am: ${_formatDate(artikel.aktualisiertAm)}',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      pdfBytes = Uint8List.fromList(await pdf.save());
    } catch (e, stack) {
      _logger.e('Fehler beim PDF-Aufbau:', error: e, stackTrace: stack);
      throw Exception('Fehler beim PDF-Aufbau: $e');
    }

    final fileName =
        'artikel_liste_${_fileTimestamp()}.pdf';

    try {
      final file = await _savePdfBytes(
        pdfBytes,
        fileName,
        'Artikelliste als PDF speichern',
      );

      if (file != null) {
        _logger.i(
          'Artikelliste PDF gespeichert: ${file.path} '
          '(${await file.length()} bytes)',
        );
        return file;
      } else {
        _logger.d('Artikelliste PDF Export abgebrochen vom Benutzer');
        return null;
      }
    } catch (e, stack) {
      _logger.e('Fehler beim PDF Export:', error: e, stackTrace: stack);
      throw Exception('Fehler beim PDF Export: $e');
    }
  }

  /// Erstellt eine detaillierte PDF für einen einzelnen Artikel (DIN A4).
  /// Gibt `null` zurück wenn der Save-Dialog abgebrochen wurde.
  Future<File?> generateArtikelDetailPdf(Artikel artikel) async {
    late Uint8List pdfBytes;
    try {
      // FIX Bug 4: await file.exists() statt blockierendem existsSync().
      pw.Image? artikelBild;
      if (artikel.bildPfad.isNotEmpty &&
          await File(artikel.bildPfad).exists()) {
        try {
          final imageBytes = await File(artikel.bildPfad).readAsBytes();
          artikelBild = pw.Image(pw.MemoryImage(imageBytes));
        } catch (e) {
          _logger.w('Bild konnte nicht geladen werden: $e');
          artikelBild = null;
        }
      }

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(40),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ARTIKEL-DETAILS',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Exportiert am: ${_formatDate(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Artikel-Info und Bild nebeneinander (wenn Bild vorhanden)
              if (artikelBild != null)
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: _buildArtikelInfoColumn(artikel),
                    ),
                    pw.SizedBox(width: 20),
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
                          pw.Text(
                            'Bildpfad:',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            artikel.bildPfad,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                pw.Column(
                  children: [
                    _buildArtikelInfoColumn(artikel),
                    if (artikel.remoteBildPfad?.isNotEmpty == true) ...[
                      pw.SizedBox(height: 20),
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(border: pw.Border.all()),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Nextcloud-Bildpfad:',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              artikel.remoteBildPfad ?? '',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

              // Zusätzliche Informationen
              pw.SizedBox(height: 30),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ZUSÄTZLICHE INFORMATIONEN',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            'Erstellt am: ${_formatDate(artikel.erstelltAm)}',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            'Aktualisiert am: '
                            '${_formatDate(artikel.aktualisiertAm)}',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    if (artikel.id != null) ...[
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Artikel-ID: ${artikel.id}',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
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
                child: pw.Text(
                  'Erstellt mit Lager-App • ${_formatDate(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
      pdfBytes = Uint8List.fromList(await pdf.save());
    } catch (e, stack) {
      _logger.e('Fehler beim PDF-Aufbau:', error: e, stackTrace: stack);
      throw Exception('Fehler beim PDF-Aufbau: $e');
    }

    // FIX Problem 7: Leerzeichen → Unterstrich, Umlaute bleiben erhalten.
    final cleanName = artikel.name
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^\w\-äöüÄÖÜß]'), '_');
    final fileName = 'artikel_detail_${cleanName}_${_fileTimestamp()}.pdf';

    try {
      final file = await _savePdfBytes(
        pdfBytes,
        fileName,
        'Artikel-Details als PDF speichern',
      );

      if (file != null) {
        _logger.i(
          'Artikel-Detail PDF gespeichert: ${file.path} '
          '(${await file.length()} bytes)',
        );
        return file;
      } else {
        _logger.d('Artikel-Detail PDF Export abgebrochen vom Benutzer');
        return null;
      }
    } catch (e, stack) {
      _logger.e('Fehler beim PDF Export:', error: e, stackTrace: stack);
      throw Exception('Fehler beim PDF Export: $e');
    }
  }

  /// Öffnet oder teilt eine PDF-Datei plattformspezifisch.
  static Future<bool> openPdf(String filePath) async {
    final logger = Logger();
    try {
      final file = File(filePath);

      // FIX Problem 8: Einfache Existenzprüfung statt Polling-Loop.
      // writeAsBytes() ist bereits awaited — die Datei ist vollständig.
      if (!await file.exists()) {
        logger.w('PDF-Datei nicht gefunden: $filePath');
        return false;
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        logger.w('PDF-Datei ist leer: $filePath');
        return false;
      }

      if (Platform.isAndroid || Platform.isIOS) {
        final shareResult = await Share.shareXFiles(
          [XFile(filePath)],
          text: 'PDF-Export aus Lager-App',
          subject: 'Artikel-PDF',
        );

        final success =
            shareResult.status == ShareResultStatus.success;
        if (success) {
          logger.i('PDF geteilt: $filePath ($fileSize bytes)');
        } else {
          logger.w('Share fehlgeschlagen: ${shareResult.status}');
        }
        return success;
      } else {
        final uri = Uri.file(filePath);
        final success = await launchUrl(uri);
        if (success) {
          logger.i('PDF geöffnet: $filePath ($fileSize bytes)');
        }
        return success;
      }
    } catch (e, stack) {
      Logger().e('Fehler beim Öffnen/Teilen der PDF:', error: e, stackTrace: stack);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Private Hilfsmethoden
  // ---------------------------------------------------------------------------

  /// Speichert PDF-Bytes plattformspezifisch.
  Future<File?> _savePdfBytes(
    Uint8List pdfBytes,
    String fileName,
    String dialogTitle,
  ) async {
    if (Platform.isAndroid || Platform.isIOS) {
      return _saveMobile(pdfBytes, fileName);
    } else {
      return _saveDesktop(pdfBytes, fileName, dialogTitle);
    }
  }

  /// Speichert auf Mobile im Download-Ordner.
  Future<File?> _saveMobile(Uint8List pdfBytes, String fileName) async {
    try {
      Directory? directory;

      if (Platform.isAndroid) {
        // FIX Bug 2: getExternalStorageDirectory() statt hardcodiertem Pfad.
        // Funktioniert auf allen Android-Versionen und Geräten.
        directory = await getExternalStorageDirectory();

        // Versuche den Download-Unterordner zu erstellen
        if (directory != null) {
          final downloadDir = Directory('${directory.path}/Download');
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
          directory = downloadDir;
        }
      } else if (Platform.isIOS) {
        directory = await getDownloadsDirectory();
      }

      // Fallback zu App-Documents wenn kein öffentlicher Ordner verfügbar
      directory ??= await getApplicationDocumentsDirectory();

      final file = File('${directory.path}/$fileName');
      // FIX Bug 3: writeAsBytes() ist awaited — kein delay nötig.
      await file.writeAsBytes(pdfBytes);

      _logger.i('PDF gespeichert: ${file.path}');
      return file;
    } catch (e, stack) {
      _logger.e('Mobile Speicher Fehler:', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Speichert auf Desktop via FilePicker Save-Dialog.
  Future<File?> _saveDesktop(
    Uint8List pdfBytes,
    String fileName,
    String dialogTitle,
  ) async {
    try {
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: pdfBytes,
      );

      if (savedPath == null) {
        // Benutzer hat den Dialog abgebrochen
        return null;
      }

      final file = File(savedPath);
      // FIX Bug 3: Kein delay — writeAsBytes() ist synchron nach await.
      if (!await file.exists() || await file.length() == 0) {
        // FilePicker hat bytes-Parameter ignoriert — manuell schreiben
        await file.writeAsBytes(pdfBytes);
      }

      _logger.i('PDF gespeichert: ${file.path}');
      return file;
    } catch (e, stack) {
      _logger.e('Desktop FilePicker Fehler:', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Hilfsmethode für die Artikel-Informationen Spalte.
  pw.Widget _buildArtikelInfoColumn(Artikel artikel) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            artikel.name,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 15),
          pw.Table(
            columnWidths: const {
              0: pw.FixedColumnWidth(100),
              1: pw.FlexColumnWidth(),
            },
            children: [
              _tableRow('Menge:', '${artikel.menge}'),
              _tableRow('Lagerort:', artikel.ort),
              _tableRow('Fach:', artikel.fach),
            ],
          ),
          if (artikel.beschreibung.isNotEmpty) ...[
            pw.SizedBox(height: 15),
            pw.Text(
              'Beschreibung:',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5),
              ),
              child: pw.Text(
                artikel.beschreibung,
                style: const pw.TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Erstellt eine Tabellenzeile mit Label und Wert.
  pw.TableRow _tableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 14)),
        ),
      ],
    );
  }

  /// Formatiert ein Datum als lesbaren String.
  ///
  /// FIX Hinweis 9: Robuster als substring(0,19) auf DateTime.toString().
  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final mo = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi:$s';
  }

  /// Erstellt einen Dateiname-sicheren Timestamp.
  String _fileTimestamp() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}'
        '-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}'
        '-${now.minute.toString().padLeft(2, '0')}'
        '-${now.second.toString().padLeft(2, '0')}';
  }
}