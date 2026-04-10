// test/utils/attachment_utils_test.dart
//
// Unit-Tests für attachment_utils.dart.
//
// Testet:
//   - validateAttachment(): Größe, Anzahl, MIME-Typ, Erweiterung, Leer
//   - mimeTypeFromExtension(): Alle Mappings, unbekannte Erweiterung
//   - iconForMimeType(): Alle Kategorien
//   - colorForMimeType(): Alle Kategorien
//   - AttachmentValidation: ok/fehler

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lager_app/models/attachment_model.dart';
import 'package:lager_app/utils/attachment_utils.dart';

void main() {
  group('AttachmentUtils', () {
    group('validateAttachment()', () {
      test('akzeptiert gültige PDF-Datei', () {
        final result = validateAttachment(
          bytes: Uint8List(1024),
          dateiName: 'rechnung.pdf',
          mimeType: 'application/pdf',
          aktuelleAnzahl: 0,
        );

        expect(result.isValid, isTrue);
        expect(result.fehler, isNull);
      });

      test('akzeptiert gültige Bilddatei', () {
        final result = validateAttachment(
          bytes: Uint8List(500000),
          dateiName: 'foto.jpg',
          mimeType: 'image/jpeg',
          aktuelleAnzahl: 5,
        );

        expect(result.isValid, isTrue);
      });

      test('lehnt ab wenn Limit erreicht', () {
        final result = validateAttachment(
          bytes: Uint8List(1024),
          dateiName: 'test.pdf',
          mimeType: 'application/pdf',
          aktuelleAnzahl: kMaxAttachmentsPerArtikel,
        );

        expect(result.isValid, isFalse);
        expect(result.fehler, contains('Maximale Anzahl'));
        expect(result.fehler, contains('$kMaxAttachmentsPerArtikel'));
      });

      test('lehnt ab wenn Limit überschritten', () {
        final result = validateAttachment(
          bytes: Uint8List(1024),
          dateiName: 'test.pdf',
          mimeType: 'application/pdf',
          aktuelleAnzahl: kMaxAttachmentsPerArtikel + 5,
        );

        expect(result.isValid, isFalse);
      });

      test('lehnt zu große Datei ab', () {
        final result = validateAttachment(
          bytes: Uint8List(kMaxAttachmentBytes + 1),
          dateiName: 'riesig.pdf',
          mimeType: 'application/pdf',
          aktuelleAnzahl: 0,
        );

        expect(result.isValid, isFalse);
        expect(result.fehler, contains('zu groß'));
        expect(result.fehler, contains('MB'));
      });

      test('akzeptiert Datei genau am Größenlimit', () {
        final result = validateAttachment(
          bytes: Uint8List(kMaxAttachmentBytes),
          dateiName: 'genau_limit.pdf',
          mimeType: 'application/pdf',
          aktuelleAnzahl: 0,
        );

        expect(result.isValid, isTrue);
      });

      test('lehnt leere Datei ab', () {
        final result = validateAttachment(
          bytes: Uint8List(0),
          dateiName: 'leer.pdf',
          mimeType: 'application/pdf',
          aktuelleAnzahl: 0,
        );

        expect(result.isValid, isFalse);
        expect(result.fehler, contains('leer'));
      });

      test('lehnt unerlaubten MIME-Typ ab', () {
        final result = validateAttachment(
          bytes: Uint8List(1024),
          dateiName: 'script.js',
          mimeType: 'application/javascript',
          aktuelleAnzahl: 0,
        );

        expect(result.isValid, isFalse);
        expect(result.fehler, contains('nicht erlaubt'));
        expect(result.fehler, contains('application/javascript'));
      });

      test('lehnt HTML ab', () {
        final result = validateAttachment(
          bytes: Uint8List(1024),
          dateiName: 'page.html',
          mimeType: 'text/html',
          aktuelleAnzahl: 0,
        );

        expect(result.isValid, isFalse);
      });

      test('prüft Erweiterung wenn kein MIME-Typ vorhanden', () {
        final result = validateAttachment(
          bytes: Uint8List(1024),
          dateiName: 'dokument.pdf',
          mimeType: null,
          aktuelleAnzahl: 0,
        );

        expect(result.isValid, isTrue);
      });

      test('lehnt unbekannte Erweiterung ab wenn kein MIME-Typ', () {
        final result = validateAttachment(
          bytes: Uint8List(1024),
          dateiName: 'virus.exe',
          mimeType: null,
          aktuelleAnzahl: 0,
        );

        expect(result.isValid, isFalse);
        expect(result.fehler, contains('nicht erlaubt'));
      });

      test('prüft Erweiterung bei leerem MIME-Typ', () {
        final result = validateAttachment(
          bytes: Uint8List(1024),
          dateiName: 'tabelle.xlsx',
          mimeType: '',
          aktuelleAnzahl: 0,
        );

        expect(result.isValid, isTrue);
      });

      test('akzeptiert alle erlaubten MIME-Typen', () {
        for (final mime in kErlaubteMimeTypes) {
          final result = validateAttachment(
            bytes: Uint8List(1024),
            dateiName: 'test.dat',
            mimeType: mime,
            aktuelleAnzahl: 0,
          );

          expect(result.isValid, isTrue,
              reason: 'MIME-Typ $mime sollte erlaubt sein',);
        }
      });

      test('Priorität: Limit wird vor Größe geprüft', () {
        final result = validateAttachment(
          bytes: Uint8List(kMaxAttachmentBytes + 1),
          dateiName: 'test.pdf',
          mimeType: 'application/pdf',
          aktuelleAnzahl: kMaxAttachmentsPerArtikel,
        );

        expect(result.isValid, isFalse);
        expect(result.fehler, contains('Maximale Anzahl'));
      });
    });

    group('mimeTypeFromExtension()', () {
      test('erkennt PDF', () {
        expect(mimeTypeFromExtension('rechnung.pdf'), 'application/pdf');
      });

      test('erkennt JPG und JPEG', () {
        expect(mimeTypeFromExtension('foto.jpg'), 'image/jpeg');
        expect(mimeTypeFromExtension('foto.jpeg'), 'image/jpeg');
      });

      test('erkennt PNG', () {
        expect(mimeTypeFromExtension('bild.png'), 'image/png');
      });

      test('erkennt WebP', () {
        expect(mimeTypeFromExtension('bild.webp'), 'image/webp');
      });

      test('erkennt Word-Dokumente', () {
        expect(mimeTypeFromExtension('brief.doc'), 'application/msword');
        expect(
          mimeTypeFromExtension('brief.docx'),
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      });

      test('erkennt Excel-Dokumente', () {
        expect(mimeTypeFromExtension('tabelle.xls'), 'application/vnd.ms-excel');
        expect(
          mimeTypeFromExtension('tabelle.xlsx'),
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      });

      test('erkennt CSV', () {
        expect(mimeTypeFromExtension('daten.csv'), 'text/csv');
      });

      test('erkennt TXT', () {
        expect(mimeTypeFromExtension('notiz.txt'), 'text/plain');
      });

      test('gibt null bei unbekannter Erweiterung', () {
        expect(mimeTypeFromExtension('script.exe'), isNull);
        expect(mimeTypeFromExtension('archive.zip'), isNull);
      });

      test('gibt null bei Datei ohne Erweiterung', () {
        expect(mimeTypeFromExtension('README'), isNull);
      });

      test('erkennt ODT', () {
        expect(
          mimeTypeFromExtension('dokument.odt'),
          'application/vnd.oasis.opendocument.text',
        );
      });
    });

    group('iconForMimeType()', () {
      test('Bild-Icon für image/*', () {
        expect(iconForMimeType('image/jpeg'), Icons.image);
        expect(iconForMimeType('image/png'), Icons.image);
      });

      test('PDF-Icon für application/pdf', () {
        expect(iconForMimeType('application/pdf'), Icons.picture_as_pdf);
      });

      test('Dokument-Icon für Word', () {
        expect(iconForMimeType('application/msword'), Icons.description);
      });

      test('Tabellen-Icon für Excel', () {
        expect(iconForMimeType('application/vnd.ms-excel'), Icons.table_chart);
      });

      test('Tabellen-Icon für CSV', () {
        expect(iconForMimeType('text/csv'), Icons.table_chart);
      });

      test('Text-Icon für text/plain', () {
        expect(iconForMimeType('text/plain'), Icons.text_snippet);
      });

      test('Fallback-Icon für unbekannten Typ', () {
        expect(iconForMimeType('application/octet-stream'), Icons.insert_drive_file);
      });

      test('Fallback-Icon für null', () {
        expect(iconForMimeType(null), Icons.insert_drive_file);
      });
    });

    group('colorForMimeType()', () {
      test('Blau für Bilder', () {
        expect(colorForMimeType('image/jpeg'), Colors.blue);
      });

      test('Rot für PDF', () {
        expect(colorForMimeType('application/pdf'), Colors.red);
      });

      test('Indigo für Word', () {
        expect(colorForMimeType('application/msword'), Colors.indigo);
      });

      test('Grün für Excel', () {
        expect(colorForMimeType('application/vnd.ms-excel'), Colors.green);
      });

      test('Grün für CSV', () {
        expect(colorForMimeType('text/csv'), Colors.green);
      });

      test('BlueGrey für Text', () {
        expect(colorForMimeType('text/plain'), Colors.blueGrey);
      });

      test('Grau für unbekannt', () {
        expect(colorForMimeType('application/octet-stream'), Colors.grey);
      });

      test('Grau für null', () {
        expect(colorForMimeType(null), Colors.grey);
      });
    });

    group('AttachmentValidation', () {
      test('ok() ist gültig ohne Fehler', () {
        const v = AttachmentValidation.ok();
        expect(v.isValid, isTrue);
        expect(v.fehler, isNull);
      });

      test('fehler() ist ungültig mit Nachricht', () {
        const v = AttachmentValidation.fehler('Testfehler');
        expect(v.isValid, isFalse);
        expect(v.fehler, 'Testfehler');
      });
    });
  });
}
