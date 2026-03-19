// lib/services/pdf_service_shared.dart
//
// Plattformunabhängige PDF-Aufbau-Logik + abstrakte PdfSaver-Schnittstelle.
// Kein dart:io, kein dart:html.

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/artikel_model.dart';

/// Abstrakte Schnittstelle für plattformspezifisches PDF-Speichern.
///
/// Implementierungen:
/// - [pdf_service_io.dart]  → Mobile & Desktop
/// - [pdf_service_web.dart] → Flutter Web
abstract class PdfSaver {
  /// Speichert [pdfBytes] und gibt den lokalen Pfad zurück.
  /// Web: Löst Browser-Download aus, gibt `null` zurück.
  /// Abbruch durch Benutzer: gibt `null` zurück.
  Future<String?> savePdfBytes(
    Uint8List pdfBytes,
    String fileName,
    String dialogTitle,
  );

  /// Öffnet / teilt eine gespeicherte PDF.
  /// Web: No-op, gibt immer `true` zurück.
  Future<bool> openPdf(String filePath);

  /// Liest Bild-Bytes von einem lokalen Pfad.
  /// Web: gibt immer `null` zurück (kein lokales Dateisystem).
  Future<Uint8List?> readLocalImageBytes(String path);
}

// ---------------------------------------------------------------------------
// PDF-Aufbau-Service
// ---------------------------------------------------------------------------

/// Plattformunabhängiger PDF-Aufbau-Service.
/// Gibt fertige [Uint8List]-Bytes zurück — kein Speichern, kein Öffnen.
class PdfBuilderService {
  final Logger _logger = Logger();

  /// Baut eine Artikellisten-PDF.
  Future<Uint8List> buildArtikelListePdf(List<Artikel> artikelListe) async {
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
                    pw.Text('Ort: ${artikel.ort} | Fach: ${artikel.fach}'),
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
      return Uint8List.fromList(await pdf.save());
    } catch (e, stack) {
      _logger.e('PDF-Aufbau Fehler (Liste):', error: e, stackTrace: stack);
      throw Exception('Fehler beim PDF-Aufbau: $e');
    }
  }

  /// Baut eine Artikel-Detail-PDF.
  /// [imageBytes] optional — kein Bild wenn `null`.
  Future<Uint8List> buildArtikelDetailPdf(
    Artikel artikel, {
    Uint8List? imageBytes,
  }) async {
    try {
      pw.Image? artikelBild;
      if (imageBytes != null) {
        try {
          artikelBild = pw.Image(pw.MemoryImage(imageBytes));
        } catch (e) {
          _logger.w('pw.Image Konvertierung fehlgeschlagen: $e');
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

              // Artikel-Info + optionales Bild
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
                            artikel.remoteBildPfad?.isNotEmpty == true
                                ? artikel.remoteBildPfad!
                                : artikel.bildPfad,
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
                      'ZUSAETZLICHE INFORMATIONEN',
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
                  'Erstellt mit Lager-App | ${_formatDate(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );

      return Uint8List.fromList(await pdf.save());
    } catch (e, stack) {
      _logger.e('PDF-Aufbau Fehler (Detail):', error: e, stackTrace: stack);
      throw Exception('Fehler beim PDF-Aufbau: $e');
    }
  }

  // ── Private Hilfsmethoden ──────────────────────────────────────────────────

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
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
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
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
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

  pw.TableRow _tableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 14)),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    return '${l.year.toString().padLeft(4, '0')}'
        '-${l.month.toString().padLeft(2, '0')}'
        '-${l.day.toString().padLeft(2, '0')}'
        ' ${l.hour.toString().padLeft(2, '0')}'
        ':${l.minute.toString().padLeft(2, '0')}'
        ':${l.second.toString().padLeft(2, '0')}';
  }

  /// Public — wird von pdf_service.dart für Dateinamen genutzt.
  String fileTimestamp() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}'
        '-${n.month.toString().padLeft(2, '0')}'
        '-${n.day.toString().padLeft(2, '0')}'
        '_${n.hour.toString().padLeft(2, '0')}'
        '-${n.minute.toString().padLeft(2, '0')}'
        '-${n.second.toString().padLeft(2, '0')}';
  }
}