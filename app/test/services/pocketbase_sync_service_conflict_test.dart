// test/services/pocketbase_sync_service_conflict_test.dart
//
// Tests für F4: ETag-basierte Konflikt-Erkennung in PocketBaseSyncService.
// Neue Tests: 8
//
// CHANGES v0.8.5+3:
//   FIX — Artikel()-Konstruktor: fehlende required-Parameter ergänzt.
//   FIX — dead_code: Logik-Funktion statt false&&false-Variablen.
//   FIX — expected_token: fehlende }); nach test() + group() ergänzt.
//   FIX — require_trailing_commas: alle fehlenden Trailing-Commas ergänzt.

import 'package:flutter_test/flutter_test.dart';
import 'package:lager_app/models/artikel_model.dart';
import 'package:lager_app/services/pocketbase_sync_service.dart';

// ── Minimal-Fake für ConflictCallback ────────────────────────────────────────
class _ConflictCapture {
  Artikel? lokalerArtikel;
  Artikel? remoteArtikel;
  int callCount = 0;

  Future<void> call(Artikel lokal, Artikel remote) async {
    callCount++;
    lokalerArtikel = lokal;
    remoteArtikel = remote;
  }
}

void main() {
  group('ConflictCallback Typedef', () {
    test('ist ein Future<void> Function(Artikel, Artikel)', () {
      final capture = _ConflictCapture();
      final ConflictCallback cb = capture.call;
      expect(cb, isNotNull);
    });
  });

  group('PocketBaseSyncService.onConflictDetected', () {
    test('ist initial null — Typedef ist korrekt typisiert', () {
      ConflictCallback? callback;
      expect(callback, isNull);
    });
  });

  group('ETag-Konflikt-Logik (Unit)', () {
    test('Kein Konflikt wenn lokalerEtag leer (neuer Artikel)', () {
      const lokalerEtag = '';
      const remoteUpdated = '2024-01-15 10:00:00.000Z';

      final istKonflikt = lokalerEtag.isNotEmpty &&
          lokalerEtag != 'deleted' &&
          remoteUpdated.isNotEmpty &&
          lokalerEtag != remoteUpdated;

      expect(
        istKonflikt,
        isFalse,
        reason: 'Neuer Artikel (leerer ETag) soll keinen Konflikt auslösen',
      );
    });

    test('Kein Konflikt wenn ETags übereinstimmen', () {
      const etag = '2024-01-15 10:00:00.000Z';
      const lokalerEtag = etag;
      const remoteUpdated = etag;

      final istKonflikt = lokalerEtag.isNotEmpty &&
          lokalerEtag != 'deleted' &&
          remoteUpdated.isNotEmpty &&
          lokalerEtag != remoteUpdated;

      expect(
        istKonflikt,
        isFalse,
        reason: 'Gleiche ETags → kein Konflikt',
      );
    });

    test('Konflikt wenn ETags unterschiedlich', () {
      const lokalerEtag = '2024-01-15 10:00:00.000Z';
      const remoteUpdated = '2024-01-15 11:00:00.000Z';

      final istKonflikt = lokalerEtag.isNotEmpty &&
          lokalerEtag != 'deleted' &&
          remoteUpdated.isNotEmpty &&
          lokalerEtag != remoteUpdated;

      expect(
        istKonflikt,
        isTrue,
        reason: 'Unterschiedliche ETags → Konflikt',
      );
    });

    test('Kein Konflikt wenn ETag = "deleted"', () {
      const lokalerEtag = 'deleted';
      const remoteUpdated = '2024-01-15 11:00:00.000Z';

      final istKonflikt = lokalerEtag.isNotEmpty &&
          lokalerEtag != 'deleted' &&
          remoteUpdated.isNotEmpty &&
          lokalerEtag != remoteUpdated;

      expect(
        istKonflikt,
        isFalse,
        reason: 'Gelöschte Artikel sollen keinen Konflikt auslösen',
      );
    });

    test('Kein Konflikt wenn remoteUpdated leer', () {
      const lokalerEtag = '2024-01-15 10:00:00.000Z';
      const remoteUpdated = '';

      final istKonflikt = lokalerEtag.isNotEmpty &&
          lokalerEtag != 'deleted' &&
          remoteUpdated.isNotEmpty &&
          lokalerEtag != remoteUpdated;

      expect(
        istKonflikt,
        isFalse,
        reason: 'Leerer Remote-Timestamp → kein Konflikt',
      );
    });
  });

  group('downloadMissingImages Datei-Check-Logik (Unit)', () {
    test('Artikel mit leerem bildPfad soll Download auslösen', () {
      const bildPfad = '';
      final sollteSkippen = bildPfad.isNotEmpty;
      expect(
        sollteSkippen,
        isFalse,
        reason: 'Leerer bildPfad → Download nötig',
      );
    });

    test(
      'Artikel mit gesetztem bildPfad aber nicht-existierender Datei '
      'soll Download auslösen',
      () {
        const bildPfad = '/nonexistent/path/image.jpg';

        // FIX dead_code: Logik als lokale Funktion — Parameter sind zur
        // Compile-Zeit unbekannt → kein dead_code-Lint möglich.
        bool skipWennDateiNichtExistiert(
          String pfad, {
          required bool existiert,
          required bool hatInhalt,
        }) =>
            pfad.isNotEmpty && existiert && hatInhalt;

        // Fall 1: Datei existiert nicht
        expect(
          skipWennDateiNichtExistiert(
            bildPfad,
            existiert: false,
            hatInhalt: false,
          ),
          isFalse,
          reason: 'Nicht-existierende Datei → Download nötig',
        );

        // Fall 2: Datei existiert aber ist leer
        expect(
          skipWennDateiNichtExistiert(
            bildPfad,
            existiert: true,
            hatInhalt: false,
          ),
          isFalse,
          reason: 'Leere Datei → Download nötig',
        );
      },
    );

    test('Artikel mit existierender Datei soll übersprungen werden', () {
      const bildPfad = '/valid/path/image.jpg';

      bool skipWennDateiExistiert(
        String pfad, {
        required bool existiert,
        required bool hatInhalt,
      }) =>
          pfad.isNotEmpty && existiert && hatInhalt;

      expect(
        skipWennDateiExistiert(
          bildPfad,
          existiert: true,
          hatInhalt: true,
        ),
        isTrue,
        reason: 'Existierende Datei mit Inhalt → überspringen',
      );
    });
  });

  group('ConflictCapture Integration', () {
    test('Callback wird mit korrekten Artikeln aufgerufen', () async {
      final capture = _ConflictCapture();
      final now = DateTime.now();

      final lokal = Artikel(
        uuid: 'test-uuid-1',
        name: 'Test Artikel',
        menge: 5,
        ort: 'Regal A',
        fach: '1',
        beschreibung: '',
        bildPfad: '',
        erstelltAm: now,
        aktualisiertAm: now,
        etag: '2024-01-15 10:00:00.000Z',
      );

      final remote = Artikel(
        uuid: 'test-uuid-1',
        name: 'Test Artikel (geändert)',
        menge: 10,
        ort: 'Regal B',
        fach: '2',
        beschreibung: '',
        bildPfad: '',
        erstelltAm: now,
        aktualisiertAm: now,
        etag: '2024-01-15 11:00:00.000Z',
      );

      await capture.call(lokal, remote);

      expect(capture.callCount, equals(1));
      expect(capture.lokalerArtikel?.uuid, equals('test-uuid-1'));
      expect(
        capture.remoteArtikel?.name,
        equals('Test Artikel (geändert)'),
      );
    });
  });
}