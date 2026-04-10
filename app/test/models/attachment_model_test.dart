// test/models/attachment_model_test.dart
//
// Unit-Tests für AttachmentModel.
//
// Testet:
//   - Konstruktor: Pflichtfelder, optionale Felder
//   - fromPocketBase(): Normalfall, Null-Handling, Typ-Koercion
//   - dateiGroesseFormatiert: B, KB, MB, Grenzwerte
//   - typLabel: Alle MIME-Typ-Kategorien
//   - istBild: true/false
//   - copyWith(): Alle Felder
//   - ==, hashCode, toString()
//   - Konstanten: kErlaubteMimeTypes, kMaxAttachmentBytes, kMaxAttachmentsPerArtikel

import 'package:flutter_test/flutter_test.dart';
import 'package:lager_app/models/attachment_model.dart';

void main() {
  group('AttachmentModel', () {
    final fixedDate = DateTime.utc(2025, 3, 15, 14, 30, 0);

    AttachmentModel createTestModel({
      String id = 'att_001',
      String artikelUuid = 'uuid-123',
      String dateiName = 'rechnung.pdf',
      String bezeichnung = 'Lieferschein März',
      String? beschreibung = 'Wichtiges Dokument',
      String? mimeType = 'application/pdf',
      int? dateiGroesse = 2500000,
      int sortOrder = 0,
      DateTime? erstelltAm,
      String? downloadUrl = 'https://pb.example.com/files/att_001/rechnung.pdf',
    }) {
      return AttachmentModel(
        id: id,
        artikelUuid: artikelUuid,
        dateiName: dateiName,
        bezeichnung: bezeichnung,
        beschreibung: beschreibung,
        mimeType: mimeType,
        dateiGroesse: dateiGroesse,
        sortOrder: sortOrder,
        erstelltAm: erstelltAm ?? fixedDate,
        downloadUrl: downloadUrl,
      );
    }

    group('Konstruktor', () {
      test('erstellt Model mit allen Pflichtfeldern', () {
        final model = createTestModel();

        expect(model.id, 'att_001');
        expect(model.artikelUuid, 'uuid-123');
        expect(model.dateiName, 'rechnung.pdf');
        expect(model.bezeichnung, 'Lieferschein März');
        expect(model.beschreibung, 'Wichtiges Dokument');
        expect(model.mimeType, 'application/pdf');
        expect(model.dateiGroesse, 2500000);
        expect(model.sortOrder, 0);
        expect(model.erstelltAm, fixedDate);
        expect(model.downloadUrl, contains('rechnung.pdf'));
      });

      test('optionale Felder sind nullable', () {
        const model = AttachmentModel(
          id: 'att_002',
          artikelUuid: 'uuid-456',
          dateiName: 'datei.txt',
          bezeichnung: 'Test',
        );

        expect(model.beschreibung, isNull);
        expect(model.mimeType, isNull);
        expect(model.dateiGroesse, isNull);
        expect(model.sortOrder, 0);
        expect(model.erstelltAm, isNull);
        expect(model.downloadUrl, isNull);
      });
    });

    group('fromPocketBase()', () {
      test('parst vollständigen Record korrekt', () {
        final data = {
          'artikel_uuid': 'uuid-789',
          'datei': 'scan_abc123.pdf',
          'bezeichnung': 'Scan Rechnung',
          'beschreibung': 'Gescannt am 15.03.',
          'mime_type': 'application/pdf',
          'datei_groesse': 1048576,
          'sort_order': 2,
        };

        final model = AttachmentModel.fromPocketBase(
          data,
          'rec_001',
          downloadUrl: 'https://pb.example.com/files/rec_001/scan_abc123.pdf',
          created: '2025-03-15 14:30:00.000Z',
        );

        expect(model.id, 'rec_001');
        expect(model.artikelUuid, 'uuid-789');
        expect(model.dateiName, 'scan_abc123.pdf');
        expect(model.bezeichnung, 'Scan Rechnung');
        expect(model.beschreibung, 'Gescannt am 15.03.');
        expect(model.mimeType, 'application/pdf');
        expect(model.dateiGroesse, 1048576);
        expect(model.sortOrder, 2);
        expect(model.erstelltAm, isNotNull);
        expect(model.downloadUrl, contains('scan_abc123.pdf'));
      });

      test('behandelt null-Werte graceful', () {
        final data = <String, dynamic>{};
        final model = AttachmentModel.fromPocketBase(data, 'rec_002');

        expect(model.id, 'rec_002');
        expect(model.artikelUuid, '');
        expect(model.dateiName, '');
        expect(model.bezeichnung, '');
        expect(model.beschreibung, isNull);
        expect(model.mimeType, isNull);
        expect(model.dateiGroesse, isNull);
        expect(model.sortOrder, 0);
        expect(model.downloadUrl, isNull);
      });

      test('konvertiert datei_groesse von String zu int', () {
        final data = {
          'artikel_uuid': 'uuid-test',
          'datei': 'test.pdf',
          'bezeichnung': 'Test',
          'datei_groesse': '5242880',
          'sort_order': '3',
        };

        final model = AttachmentModel.fromPocketBase(data, 'rec_003');

        expect(model.dateiGroesse, 5242880);
        expect(model.sortOrder, 3);
      });

      test('konvertiert datei_groesse von double zu int', () {
        final data = {
          'artikel_uuid': 'uuid-test',
          'datei': 'test.pdf',
          'bezeichnung': 'Test',
          'datei_groesse': 1024.7,
        };

        final model = AttachmentModel.fromPocketBase(data, 'rec_004');
        expect(model.dateiGroesse, 1024);
      });

      test('parst created-Feld als UTC DateTime', () {
        final data = {
          'artikel_uuid': 'uuid-test',
          'datei': 'test.pdf',
          'bezeichnung': 'Test',
        };

        final model = AttachmentModel.fromPocketBase(
          data,
          'rec_005',
          created: '2025-06-20 08:15:30.000Z',
        );

        expect(model.erstelltAm, isNotNull);
        expect(model.erstelltAm!.isUtc, isTrue);
        expect(model.erstelltAm!.year, 2025);
        expect(model.erstelltAm!.month, 6);
        expect(model.erstelltAm!.day, 20);
      });

      test('gibt null zurück bei ungültigem Datum', () {
        final data = {
          'artikel_uuid': 'uuid-test',
          'datei': 'test.pdf',
          'bezeichnung': 'Test',
          'created': 'kein-datum',
        };

        final model = AttachmentModel.fromPocketBase(data, 'rec_006');
        expect(model.erstelltAm, isNull);
      });

      test('bevorzugt created-Parameter über data["created"]', () {
        final data = {
          'artikel_uuid': 'uuid-test',
          'datei': 'test.pdf',
          'bezeichnung': 'Test',
          'created': '2020-01-01 00:00:00.000Z',
        };

        final model = AttachmentModel.fromPocketBase(
          data,
          'rec_007',
          created: '2025-12-31 23:59:59.000Z',
        );

        expect(model.erstelltAm!.year, 2025);
      });
    });

    group('dateiGroesseFormatiert', () {
      test('gibt leeren String bei null zurück', () {
        expect(createTestModel(dateiGroesse: null).dateiGroesseFormatiert, '');
      });

      test('gibt leeren String bei 0 zurück', () {
        expect(createTestModel(dateiGroesse: 0).dateiGroesseFormatiert, '');
      });

      test('formatiert Bytes korrekt', () {
        expect(createTestModel(dateiGroesse: 512).dateiGroesseFormatiert, '512 B');
      });

      test('formatiert Kilobytes korrekt', () {
        expect(createTestModel(dateiGroesse: 1536).dateiGroesseFormatiert, '1.5 KB');
      });

      test('formatiert Megabytes korrekt', () {
        expect(createTestModel(dateiGroesse: 2621440).dateiGroesseFormatiert, '2.5 MB');
      });

      test('Grenzwert: genau 1 KB', () {
        expect(createTestModel(dateiGroesse: 1024).dateiGroesseFormatiert, '1.0 KB');
      });

      test('Grenzwert: genau 1 MB', () {
        expect(createTestModel(dateiGroesse: 1024 * 1024).dateiGroesseFormatiert, '1.0 MB');
      });

      test('große Datei: 10 MB', () {
        expect(createTestModel(dateiGroesse: 10 * 1024 * 1024).dateiGroesseFormatiert, '10.0 MB');
      });
    });

    group('typLabel', () {
      test('erkennt Bild', () {
        expect(createTestModel(mimeType: 'image/jpeg').typLabel, 'Bild');
        expect(createTestModel(mimeType: 'image/png').typLabel, 'Bild');
        expect(createTestModel(mimeType: 'image/webp').typLabel, 'Bild');
      });

      test('erkennt PDF', () {
        expect(createTestModel(mimeType: 'application/pdf').typLabel, 'PDF');
      });

      test('erkennt Word-Dokument', () {
        expect(createTestModel(mimeType: 'application/msword').typLabel, 'Dokument');
        expect(
          createTestModel(
            mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          ).typLabel,
          'Dokument',
        );
      });

      test('erkennt Excel/Tabelle', () {
        expect(createTestModel(mimeType: 'application/vnd.ms-excel').typLabel, 'Tabelle');
        expect(createTestModel(mimeType: 'text/csv').typLabel, 'Tabelle');
      });

      test('erkennt Text', () {
        expect(createTestModel(mimeType: 'text/plain').typLabel, 'Text');
      });

      test('Fallback bei unbekanntem MIME-Typ', () {
        expect(createTestModel(mimeType: 'application/octet-stream').typLabel, 'Datei');
      });

      test('Fallback bei null MIME-Typ', () {
        expect(createTestModel(mimeType: null).typLabel, 'Datei');
      });
    });

    group('istBild', () {
      test('true für Bildtypen', () {
        expect(createTestModel(mimeType: 'image/jpeg').istBild, isTrue);
        expect(createTestModel(mimeType: 'image/png').istBild, isTrue);
        expect(createTestModel(mimeType: 'image/webp').istBild, isTrue);
      });

      test('false für Nicht-Bildtypen', () {
        expect(createTestModel(mimeType: 'application/pdf').istBild, isFalse);
        expect(createTestModel(mimeType: 'text/plain').istBild, isFalse);
      });

      test('false bei null', () {
        expect(createTestModel(mimeType: null).istBild, isFalse);
      });
    });

    group('copyWith()', () {
      test('kopiert alle Felder wenn nichts geändert', () {
        final original = createTestModel();
        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.artikelUuid, original.artikelUuid);
        expect(copy.dateiName, original.dateiName);
        expect(copy.bezeichnung, original.bezeichnung);
        expect(copy.beschreibung, original.beschreibung);
        expect(copy.mimeType, original.mimeType);
        expect(copy.dateiGroesse, original.dateiGroesse);
        expect(copy.sortOrder, original.sortOrder);
        expect(copy.erstelltAm, original.erstelltAm);
        expect(copy.downloadUrl, original.downloadUrl);
      });

      test('überschreibt einzelne Felder', () {
        final original = createTestModel();
        final copy = original.copyWith(
          bezeichnung: 'Neue Bezeichnung',
          sortOrder: 5,
        );

        expect(copy.bezeichnung, 'Neue Bezeichnung');
        expect(copy.sortOrder, 5);
        expect(copy.id, original.id);
        expect(copy.dateiName, original.dateiName);
      });

      test('überschreibt downloadUrl', () {
        final original = createTestModel();
        final copy = original.copyWith(downloadUrl: 'https://new-url.com/file');

        expect(copy.downloadUrl, 'https://new-url.com/file');
      });
    });

    group('Gleichheit und Identität', () {
      test('== vergleicht nur id', () {
        final a = createTestModel(id: 'same_id', bezeichnung: 'A');
        final b = createTestModel(id: 'same_id', bezeichnung: 'B');

        expect(a, equals(b));
      });

      test('!= bei unterschiedlicher id', () {
        final a = createTestModel(id: 'id_1');
        final b = createTestModel(id: 'id_2');

        expect(a, isNot(equals(b)));
      });

      test('hashCode basiert auf id', () {
        final a = createTestModel(id: 'hash_test');
        final b = createTestModel(id: 'hash_test');

        expect(a.hashCode, equals(b.hashCode));
      });

      test('toString() enthält relevante Felder', () {
        final model = createTestModel();
        final str = model.toString();

        expect(str, contains('att_001'));
        expect(str, contains('Lieferschein März'));
        expect(str, contains('rechnung.pdf'));
        expect(str, contains('application/pdf'));
      });
    });

    group('Konstanten', () {
      test('kErlaubteMimeTypes enthält erwartete Typen', () {
        expect(kErlaubteMimeTypes, contains('application/pdf'));
        expect(kErlaubteMimeTypes, contains('image/jpeg'));
        expect(kErlaubteMimeTypes, contains('image/png'));
        expect(kErlaubteMimeTypes, contains('text/csv'));
        expect(kErlaubteMimeTypes, contains('text/plain'));
      });

      test('kErlaubteMimeTypes enthält keine unsicheren Typen', () {
        expect(kErlaubteMimeTypes, isNot(contains('application/javascript')));
        expect(kErlaubteMimeTypes, isNot(contains('text/html')));
        expect(kErlaubteMimeTypes, isNot(contains('application/x-executable')));
      });

      test('kMaxAttachmentBytes ist 10 MB', () {
        expect(kMaxAttachmentBytes, 10 * 1024 * 1024);
      });

      test('kMaxAttachmentsPerArtikel ist 20', () {
        expect(kMaxAttachmentsPerArtikel, 20);
      });
    });
  });
}
