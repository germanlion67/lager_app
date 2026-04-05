// test/services/artikel_db_service_test.dart
//
// O-002: Integrations-Tests für ArtikelDbService
//
// Strategie:
//   - sqflite_common_ffi mit inMemoryDatabasePath — kein Dateisystem
//   - SharedPreferences.setMockInitialValues({}) für Prefs-Abhängigkeiten
//   - setUp(): frische In-Memory-DB + leere Tabelle vor jedem Test
//   - Singleton-Problem: ArtikelDbService() gibt immer _instance zurück →
//     wir nutzen resetDatabase() + injectDatabase() für saubere Isolation
//
// Testet:
//   - insertArtikel(): Einfügen, UUID-Eindeutigkeit, ConflictAlgorithm
//   - getAlleArtikel(): Pagination, deleted-Filter
//   - updateArtikel(): Feldaktualisierung, updated_at
//   - deleteArtikel(): Soft-Delete (deleted=1)
//   - getArtikelByUUID(): Treffer, kein Treffer
//   - getArtikelByRemotePath(): Treffer, kein Treffer
//   - getPendingChanges(): etag=null Filter
//   - markSynced(): etag + remote_path setzen
//   - upsertArtikel(): Insert + Update, bildPfad-Schutz
//   - searchArtikel(): LIKE-Suche, deleted-Filter
//   - existsKombination(): Duplikat-Check
//   - existsArtikelnummer(): Duplikat-Check
//   - setLastSyncTime() / getLastSyncTime(): Roundtrip
//   - isDatabaseEmpty(): leer / nicht leer
//   - getMaxArtikelnummer(): null / Wert
//   - deleteAlleArtikel(): Soft-Delete alle
//   - insertArtikelList(): Batch-Insert, etag=null
//   - updateBildPfad() / updateRemoteBildPfad(): Feldupdate
//   - setBildPfadByUuid() / setThumbnailPfadByUuid() / setThumbnailEtagByUuid()
//   - setRemoteBildPfadByUuid(): dirty-Flag (etag=null)
//   - getUnsyncedArtikel(): Filter

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lager_app/models/artikel_model.dart';
import 'package:lager_app/services/artikel_db_service.dart';
import 'package:lager_app/utils/uuid_generator.dart';

import 'artikel_db_service_test_helper.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// Erstellt einen minimalen, gültigen Artikel für Tests.
/// uuid wird automatisch generiert wenn nicht angegeben.
Artikel _makeArtikel({
  String? name,
  int? artikelnummer,
  int menge = 10,
  String ort = 'Regal A',
  String fach = 'Fach 1',
  String beschreibung = 'Test',
  String bildPfad = '',
  String? uuid,
  bool deleted = false,
  String? etag,
  String? remotePath,
  String? remoteBildPfad,
}) {
  return Artikel(
    name: name ?? 'Artikel ${DateTime.now().microsecondsSinceEpoch}',
    artikelnummer: artikelnummer,
    menge: menge,
    ort: ort,
    fach: fach,
    beschreibung: beschreibung,
    bildPfad: bildPfad,
    erstelltAm: DateTime.now().toUtc(),
    aktualisiertAm: DateTime.now().toUtc(),
    uuid: uuid ?? UuidGenerator.generate(),
    updatedAt: DateTime.now().millisecondsSinceEpoch,
    deleted: deleted,
    etag: etag,
    remotePath: remotePath,
    remoteBildPfad: remoteBildPfad,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ✅ FFI für sqflite auf Desktop/Test-Umgebung
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  late ArtikelDbService service;

  setUp(() async {
    service = ArtikelDbService();
    // ✅ Frische In-Memory-DB vor jedem Test
    await ArtikelDbServiceTestHelper.setupInMemory(service);
  });

  tearDown(() async {
    await service.closeDatabase();
  });

  group('ArtikelDbService', () {
    // =======================================================================
    // insertArtikel()
    // =======================================================================
    group('insertArtikel()', () {
      test('fügt Artikel ein und gibt gültige ID zurück', () async {
        final artikel = _makeArtikel(name: 'Widerstand 10kΩ');
        final id = await service.insertArtikel(artikel);

        expect(id, greaterThan(0));
      });

      test('eingefügter Artikel ist via getAlleArtikel() abrufbar', () async {
        final artikel = _makeArtikel(name: 'LED rot');
        await service.insertArtikel(artikel);

        final alle = await service.getAlleArtikel();
        expect(alle.length, equals(1));
        expect(alle.first.name, equals('LED rot'));
      });

      test('setzt etag auf null beim Insert', () async {
        // ✅ insertArtikel() setzt data['etag'] = null explizit
        final artikel = _makeArtikel(etag: 'alter-etag');
        final id = await service.insertArtikel(artikel);

        final db = await service.database;
        final result = await db.query(
          'artikel',
          where: 'id = ?',
          whereArgs: [id],
        );
        expect(result.first['etag'], isNull);
      });

      test('aktualisiert updated_at beim Insert', () async {
        final before = DateTime.now().millisecondsSinceEpoch;
        final artikel = _makeArtikel();
        final id = await service.insertArtikel(artikel);
        final after = DateTime.now().millisecondsSinceEpoch;

        final db = await service.database;
        final result = await db.query(
          'artikel',
          where: 'id = ?',
          whereArgs: [id],
        );
        final updatedAt = result.first['updated_at'] as int;
        expect(updatedAt, greaterThanOrEqualTo(before));
        expect(updatedAt, lessThanOrEqualTo(after));
      });

      test('ConflictAlgorithm.replace: zweiter Insert mit gleicher UUID '
          'überschreibt ersten', () async {
        final uuid = UuidGenerator.generate();
        final erster = _makeArtikel(name: 'Erster', uuid: uuid);
        final zweiter = _makeArtikel(name: 'Zweiter', uuid: uuid);

        await service.insertArtikel(erster);
        await service.insertArtikel(zweiter);

        final alle = await service.getAlleArtikel();
        expect(alle.length, equals(1));
        expect(alle.first.name, equals('Zweiter'));
      });

      test('mehrere Artikel mit verschiedenen UUIDs werden alle eingefügt',
          () async {
        for (var i = 0; i < 5; i++) {
          await service.insertArtikel(_makeArtikel(name: 'Artikel $i'));
        }
        final alle = await service.getAlleArtikel();
        expect(alle.length, equals(5));
      });
    });

    // =======================================================================
    // getAlleArtikel()
    // =======================================================================
    group('getAlleArtikel()', () {
      test('gibt leere Liste zurück wenn keine Artikel vorhanden', () async {
        final alle = await service.getAlleArtikel();
        expect(alle, isEmpty);
      });

      test('filtert soft-gelöschte Artikel heraus', () async {
        await service.insertArtikel(_makeArtikel(name: 'Aktiv'));
        final geloescht = _makeArtikel(name: 'Gelöscht');
        final id = await service.insertArtikel(geloescht);

        // Soft-Delete direkt in DB setzen
        final db = await service.database;
        await db.update(
          'artikel',
          {'deleted': 1},
          where: 'id = ?',
          whereArgs: [id],
        );

        final alle = await service.getAlleArtikel();
        expect(alle.length, equals(1));
        expect(alle.first.name, equals('Aktiv'));
      });

      test('respektiert limit-Parameter', () async {
        for (var i = 0; i < 10; i++) {
          await service.insertArtikel(_makeArtikel(name: 'Artikel $i'));
        }
        final alle = await service.getAlleArtikel(limit: 3);
        expect(alle.length, equals(3));
      });

      test('respektiert offset-Parameter (Pagination)', () async {
        for (var i = 0; i < 5; i++) {
          await service.insertArtikel(_makeArtikel(name: 'Artikel $i'));
        }
        final seite1 = await service.getAlleArtikel(limit: 2, offset: 0);
        final seite2 = await service.getAlleArtikel(limit: 2, offset: 2);

        expect(seite1.length, equals(2));
        expect(seite2.length, equals(2));
        // ✅ Keine Überschneidung zwischen Seiten
        final uuids1 = seite1.map((a) => a.uuid).toSet();
        final uuids2 = seite2.map((a) => a.uuid).toSet();
        expect(uuids1.intersection(uuids2), isEmpty);
      });

      test('gibt Artikel in absteigender ID-Reihenfolge zurück', () async {
        for (var i = 0; i < 3; i++) {
          await service.insertArtikel(_makeArtikel(name: 'Artikel $i'));
        }
        final alle = await service.getAlleArtikel();
        // ✅ orderBy: 'id DESC'
        expect(alle.first.id, greaterThan(alle.last.id!));
      });
    });

    // =======================================================================
    // updateArtikel()
    // =======================================================================
    group('updateArtikel()', () {
      test('aktualisiert Felder korrekt', () async {
        final original = _makeArtikel(name: 'Alt', menge: 5);
        final id = await service.insertArtikel(original);

        final updated = original.copyWith(
          id: id,
          name: 'Neu',
          menge: 99,
        );
        await service.updateArtikel(updated);

        final alle = await service.getAlleArtikel();
        expect(alle.first.name, equals('Neu'));
        expect(alle.first.menge, equals(99));
      });

      test('setzt etag auf null beim Update (dirty-Flag)', () async {
        final artikel = _makeArtikel();
        final id = await service.insertArtikel(artikel);

        // etag direkt setzen (simuliert sync)
        final db = await service.database;
        await db.update(
          'artikel',
          {'etag': 'sync-etag'},
          where: 'id = ?',
          whereArgs: [id],
        );

        // Update → etag muss wieder null sein
        await service.updateArtikel(artikel.copyWith(id: id, name: 'Geändert'));

        final result = await db.query(
          'artikel',
          where: 'id = ?',
          whereArgs: [id],
        );
        expect(result.first['etag'], isNull);
      });

      test('aktualisiert updated_at beim Update', () async {
        final artikel = _makeArtikel();
        final id = await service.insertArtikel(artikel);

        final before = DateTime.now().millisecondsSinceEpoch;
        await service.updateArtikel(artikel.copyWith(id: id, name: 'Neu'));
        final after = DateTime.now().millisecondsSinceEpoch;

        final db = await service.database;
        final result = await db.query(
          'artikel',
          where: 'id = ?',
          whereArgs: [id],
        );
        final updatedAt = result.first['updated_at'] as int;
        expect(updatedAt, greaterThanOrEqualTo(before));
        expect(updatedAt, lessThanOrEqualTo(after));
      });
    });

    // =======================================================================
    // deleteArtikel()
    // =======================================================================
    group('deleteArtikel()', () {
      test('markiert Artikel als soft-gelöscht (deleted=1)', () async {
        final artikel = _makeArtikel();
        final id = await service.insertArtikel(artikel);

        await service.deleteArtikel(artikel.copyWith(id: id));

        final db = await service.database;
        final result = await db.query(
          'artikel',
          where: 'id = ?',
          whereArgs: [id],
        );
        expect(result.first['deleted'], equals(1));
      });

      test('gelöschter Artikel erscheint nicht in getAlleArtikel()', () async {
        final artikel = _makeArtikel();
        final id = await service.insertArtikel(artikel);
        await service.deleteArtikel(artikel.copyWith(id: id));

        final alle = await service.getAlleArtikel();
        expect(alle, isEmpty);
      });

      test('setzt etag auf null beim Soft-Delete', () async {
        final artikel = _makeArtikel();
        final id = await service.insertArtikel(artikel);

        // etag setzen
        final db = await service.database;
        await db.update(
          'artikel',
          {'etag': 'sync-etag'},
          where: 'id = ?',
          whereArgs: [id],
        );

        await service.deleteArtikel(artikel.copyWith(id: id));

        final result = await db.query(
          'artikel',
          where: 'id = ?',
          whereArgs: [id],
        );
        expect(result.first['etag'], isNull);
      });

      test('Artikel bleibt physisch in DB (Soft-Delete)', () async {
        final artikel = _makeArtikel();
        final id = await service.insertArtikel(artikel);
        await service.deleteArtikel(artikel.copyWith(id: id));

        final db = await service.database;
        final result = await db.query(
          'artikel',
          where: 'id = ?',
          whereArgs: [id],
        );
        // ✅ Physisch noch vorhanden — nur deleted=1
        expect(result.length, equals(1));
      });
    });

    // =======================================================================
    // getArtikelByUUID()
    // =======================================================================
    group('getArtikelByUUID()', () {
      test('gibt Artikel zurück wenn UUID existiert', () async {
        final uuid = UuidGenerator.generate();
        final artikel = _makeArtikel(name: 'UUID-Test', uuid: uuid);
        await service.insertArtikel(artikel);

        final result = await service.getArtikelByUUID(uuid);
        expect(result, isNotNull);
        expect(result!.name, equals('UUID-Test'));
        expect(result.uuid, equals(uuid));
      });

      test('gibt null zurück wenn UUID nicht existiert', () async {
        final result = await service.getArtikelByUUID('nicht-vorhanden');
        expect(result, isNull);
      });

      test('gibt auch soft-gelöschte Artikel zurück', () async {
        final uuid = UuidGenerator.generate();
        final artikel = _makeArtikel(uuid: uuid);
        final id = await service.insertArtikel(artikel);
        await service.deleteArtikel(artikel.copyWith(id: id));

        // ✅ getArtikelByUUID hat kein deleted-Filter
        final result = await service.getArtikelByUUID(uuid);
        expect(result, isNotNull);
        expect(result!.deleted, isTrue);
      });
    });

    // =======================================================================
    // getArtikelByRemotePath()
    // =======================================================================
    group('getArtikelByRemotePath()', () {
      test('gibt Artikel zurück wenn remote_path existiert', () async {
        final artikel = _makeArtikel(remotePath: 'rec_abc123');
        await service.insertArtikel(artikel);

        final result = await service.getArtikelByRemotePath('rec_abc123');
        expect(result, isNotNull);
        expect(result!.remotePath, equals('rec_abc123'));
      });

      test('gibt null zurück wenn remote_path nicht existiert', () async {
        final result = await service.getArtikelByRemotePath('nicht-vorhanden');
        expect(result, isNull);
      });
    });

    // =======================================================================
    // getPendingChanges()
    // =======================================================================
    group('getPendingChanges()', () {
      test('gibt Artikel mit etag=null zurück', () async {
        // ✅ insertArtikel() setzt etag=null → pending
        await service.insertArtikel(_makeArtikel(name: 'Pending'));
        final pending = await service.getPendingChanges();
        expect(pending.length, equals(1));
      });

      test('gibt Artikel mit etag="" zurück', () async {
        final artikel = _makeArtikel();
        final id = await service.insertArtikel(artikel);
        final db = await service.database;
        await db.update(
          'artikel',
          {'etag': ''},
          where: 'id = ?',
          whereArgs: [id],
        );

        final pending = await service.getPendingChanges();
        expect(pending.length, equals(1));
      });

      test('gibt Artikel mit gesetztem etag NICHT zurück', () async {
        final artikel = _makeArtikel();
        await service.insertArtikel(artikel);
        await service.markSynced(artikel.uuid, 'etag-123');

        final pending = await service.getPendingChanges();
        expect(pending, isEmpty);
      });

      test('gibt auch soft-gelöschte Artikel zurück (für Sync-Propagierung)',
          () async {
        // ✅ Gelöschte Artikel müssen zu PocketBase propagiert werden
        final artikel = _makeArtikel();
        final id = await service.insertArtikel(artikel);
        await service.deleteArtikel(artikel.copyWith(id: id));

        final pending = await service.getPendingChanges();
        expect(pending.any((a) => a.uuid == artikel.uuid), isTrue);
        expect(pending.any((a) => a.deleted), isTrue);
      });

      test('gibt mehrere pending Artikel zurück', () async {
        for (var i = 0; i < 3; i++) {
          await service.insertArtikel(_makeArtikel());
        }
        final pending = await service.getPendingChanges();
        expect(pending.length, equals(3));
      });
    });

    // =======================================================================
    // markSynced()
    // =======================================================================
    group('markSynced()', () {
      test('setzt etag für Artikel', () async {
        final artikel = _makeArtikel();
        await service.insertArtikel(artikel);

        await service.markSynced(artikel.uuid, 'etag-xyz');

        final db = await service.database;
        final result = await db.query(
          'artikel',
          where: 'uuid = ?',
          whereArgs: [artikel.uuid],
        );
        expect(result.first['etag'], equals('etag-xyz'));
      });

      test('setzt remote_path wenn angegeben (FIX Finding 3)', () async {
        final artikel = _makeArtikel();
        await service.insertArtikel(artikel);

        await service.markSynced(
          artikel.uuid,
          'etag-xyz',
          remotePath: 'rec_abc123',
        );

        final db = await service.database;
        final result = await db.query(
          'artikel',
          where: 'uuid = ?',
          whereArgs: [artikel.uuid],
        );
        expect(result.first['remote_path'], equals('rec_abc123'));
      });

      test('Artikel erscheint nach markSynced() nicht mehr in '
          'getPendingChanges()', () async {
        final artikel = _makeArtikel();
        await service.insertArtikel(artikel);

        await service.markSynced(artikel.uuid, 'etag-final');

        final pending = await service.getPendingChanges();
        expect(pending, isEmpty);
      });

      test('setzt remote_path nicht wenn null übergeben wird', () async {
        final artikel = _makeArtikel(remotePath: 'bestehender-pfad');
        await service.insertArtikel(artikel);

        // remote_path direkt setzen
        final db = await service.database;
        await db.update(
          'artikel',
          {'remote_path': 'bestehender-pfad'},
          where: 'uuid = ?',
          whereArgs: [artikel.uuid],
        );

        // markSynced ohne remotePath → remote_path bleibt unverändert
        await service.markSynced(artikel.uuid, 'neues-etag');

        final result = await db.query(
          'artikel',
          where: 'uuid = ?',
          whereArgs: [artikel.uuid],
        );
        expect(result.first['remote_path'], equals('bestehender-pfad'));
      });
    });

    // =======================================================================
    // upsertArtikel()
    // =======================================================================
    group('upsertArtikel()', () {
      test('fügt neuen Artikel ein wenn UUID nicht existiert', () async {
        final artikel = _makeArtikel(name: 'Neu via Upsert');
        await service.upsertArtikel(artikel);

        final alle = await service.getAlleArtikel();
        expect(alle.length, equals(1));
        expect(alle.first.name, equals('Neu via Upsert'));
      });

      test('aktualisiert bestehenden Artikel wenn UUID existiert', () async {
        final uuid = UuidGenerator.generate();
        final original = _makeArtikel(name: 'Original', uuid: uuid);
        await service.upsertArtikel(original);

        final updated = _makeArtikel(name: 'Aktualisiert', uuid: uuid);
        await service.upsertArtikel(updated);

        final alle = await service.getAlleArtikel();
        expect(alle.length, equals(1));
        expect(alle.first.name, equals('Aktualisiert'));
      });

      test('setzt etag wenn angegeben', () async {
        final artikel = _makeArtikel();
        await service.upsertArtikel(artikel, etag: 'upsert-etag');

        final db = await service.database;
        final result = await db.query(
          'artikel',
          where: 'uuid = ?',
          whereArgs: [artikel.uuid],
        );
        expect(result.first['etag'], equals('upsert-etag'));
      });

      test('schützt lokalen bildPfad beim Update (FIX Finding)', () async {
        // ✅ Lokaler bildPfad darf nicht durch leeren Remote-Wert überschrieben werden
        final uuid = UuidGenerator.generate();
        final lokal = _makeArtikel(
          uuid: uuid,
          bildPfad: '/local/path/bild.jpg',
        );
        await service.upsertArtikel(lokal);

        // Remote-Update mit leerem bildPfad
        final remote = _makeArtikel(uuid: uuid, bildPfad: '');
        await service.upsertArtikel(remote);

        final alle = await service.getAlleArtikel();
        // ✅ Lokaler Pfad bleibt erhalten
        expect(alle.first.bildPfad, equals('/local/path/bild.jpg'));
      });

      test('überschreibt bildPfad wenn Remote einen Wert liefert', () async {
        final uuid = UuidGenerator.generate();
        final lokal = _makeArtikel(uuid: uuid, bildPfad: '');
        await service.upsertArtikel(lokal);

        final remote = _makeArtikel(
          uuid: uuid,
          bildPfad: '/remote/path/bild.jpg',
        );
        await service.upsertArtikel(remote);

        final alle = await service.getAlleArtikel();
        expect(alle.first.bildPfad, equals('/remote/path/bild.jpg'));
      });
    });

    // =======================================================================
    // searchArtikel()
    // =======================================================================
    group('searchArtikel()', () {
      test('findet Artikel nach Name (LIKE)', () async {
        await service.insertArtikel(_makeArtikel(name: 'Widerstand 10kΩ'));
        await service.insertArtikel(_makeArtikel(name: 'Kondensator 100nF'));

        final result = await service.searchArtikel('Widerstand');
        expect(result.length, equals(1));
        expect(result.first.name, equals('Widerstand 10kΩ'));
      });

      test('findet Artikel nach Beschreibung (LIKE)', () async {
        await service.insertArtikel(
          _makeArtikel(name: 'LED', beschreibung: 'rot 5mm Vorwärtsspannung'),
        );

        final result = await service.searchArtikel('Vorwärtsspannung');
        expect(result.length, equals(1));
      });

      test('gibt leere Liste zurück wenn kein Treffer', () async {
        await service.insertArtikel(_makeArtikel(name: 'Widerstand'));
        final result = await service.searchArtikel('Kondensator');
        expect(result, isEmpty);
      });

      test('filtert soft-gelöschte Artikel heraus', () async {
        final artikel = _makeArtikel(name: 'Gelöschter Widerstand');
        final id = await service.insertArtikel(artikel);
        await service.deleteArtikel(artikel.copyWith(id: id));

        final result = await service.searchArtikel('Widerstand');
        expect(result, isEmpty);
      });

      test('respektiert limit-Parameter', () async {
        for (var i = 0; i < 5; i++) {
          await service.insertArtikel(_makeArtikel(name: 'Widerstand $i'));
        }
        final result = await service.searchArtikel('Widerstand', limit: 2);
        expect(result.length, equals(2));
      });

      test('Suche ist case-insensitive (SQLite LIKE)', () async {
        await service.insertArtikel(_makeArtikel(name: 'Widerstand'));
        // ✅ SQLite LIKE ist case-insensitive für ASCII
        final result = await service.searchArtikel('widerstand');
        expect(result.length, equals(1));
      });
    });

    // =======================================================================
    // existsKombination()
    // =======================================================================
    group('existsKombination()', () {
      test('gibt true zurück wenn Kombination existiert', () async {
        await service.insertArtikel(
          _makeArtikel(name: 'LED', ort: 'Regal A', fach: 'Fach 1'),
        );

        final exists = await service.existsKombination(
          name: 'LED',
          ort: 'Regal A',
          fach: 'Fach 1',
        );
        expect(exists, isTrue);
      });

      test('gibt false zurück wenn Kombination nicht existiert', () async {
        await service.insertArtikel(
          _makeArtikel(name: 'LED', ort: 'Regal A', fach: 'Fach 1'),
        );

        final exists = await service.existsKombination(
          name: 'LED',
          ort: 'Regal B', // anderer Ort
          fach: 'Fach 1',
        );
        expect(exists, isFalse);
      });

      test('ignoriert soft-gelöschte Artikel', () async {
        final artikel = _makeArtikel(
          name: 'LED',
          ort: 'Regal A',
          fach: 'Fach 1',
        );
        final id = await service.insertArtikel(artikel);
        await service.deleteArtikel(artikel.copyWith(id: id));

        final exists = await service.existsKombination(
          name: 'LED',
          ort: 'Regal A',
          fach: 'Fach 1',
        );
        // ✅ deleted=1 → wird ignoriert → false
        expect(exists, isFalse);
      });

      test('gibt false zurück bei leerem Name', () async {
        final exists = await service.existsKombination(
          name: '',
          ort: 'Regal A',
          fach: 'Fach 1',
        );
        expect(exists, isFalse);
      });
    });

    // =======================================================================
    // existsArtikelnummer()
    // =======================================================================
    group('existsArtikelnummer()', () {
      test('gibt true zurück wenn Artikelnummer existiert', () async {
        await service.insertArtikel(_makeArtikel(artikelnummer: 1001));

        expect(await service.existsArtikelnummer(1001), isTrue);
      });

      test('gibt false zurück wenn Artikelnummer nicht existiert', () async {
        expect(await service.existsArtikelnummer(9999), isFalse);
      });

      test('ignoriert soft-gelöschte Artikel', () async {
        final artikel = _makeArtikel(artikelnummer: 1002);
        final id = await service.insertArtikel(artikel);
        await service.deleteArtikel(artikel.copyWith(id: id));

        expect(await service.existsArtikelnummer(1002), isFalse);
      });
    });

    // =======================================================================
    // setLastSyncTime() / getLastSyncTime()
    // =======================================================================
    group('setLastSyncTime() / getLastSyncTime()', () {
      test('getLastSyncTime() gibt null zurück wenn nie gesetzt', () async {
        final result = await service.getLastSyncTime();
        expect(result, isNull);
      });

      test('Roundtrip: setLastSyncTime() → getLastSyncTime()', () async {
        final before = DateTime.now().subtract(const Duration(seconds: 1));
        await service.setLastSyncTime();
        final after = DateTime.now().add(const Duration(seconds: 1));

        final result = await service.getLastSyncTime();
        expect(result, isNotNull);
        expect(result!.isAfter(before), isTrue);
        expect(result.isBefore(after), isTrue);
      });

      test('zweiter Aufruf überschreibt ersten (ConflictAlgorithm.replace)',
          () async {
        await service.setLastSyncTime();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await service.setLastSyncTime();

        final db = await service.database;
        final result = await db.query('sync_meta', where: "key = 'last_sync'");
        // ✅ Nur ein Eintrag — replace statt insert
        expect(result.length, equals(1));
      });
    });

    // =======================================================================
    // isDatabaseEmpty()
    // =======================================================================
    group('isDatabaseEmpty()', () {
      test('gibt true zurück wenn keine Artikel vorhanden', () async {
        expect(await service.isDatabaseEmpty(), isTrue);
      });

      test('gibt false zurück wenn Artikel vorhanden', () async {
        await service.insertArtikel(_makeArtikel());
        expect(await service.isDatabaseEmpty(), isFalse);
      });

      test('gibt true zurück wenn nur soft-gelöschte Artikel vorhanden',
          () async {
        final artikel = _makeArtikel();
        final id = await service.insertArtikel(artikel);
        await service.deleteArtikel(artikel.copyWith(id: id));

        // ✅ COUNT(*) WHERE deleted=0 → 0 → isEmpty=true
        expect(await service.isDatabaseEmpty(), isTrue);
      });
    });

    // =======================================================================
    // getMaxArtikelnummer()
    // =======================================================================
    group('getMaxArtikelnummer()', () {
      test('gibt null zurück wenn keine Artikel mit Artikelnummer vorhanden',
          () async {
        await service.insertArtikel(_makeArtikel(artikelnummer: null));
        expect(await service.getMaxArtikelnummer(), isNull);
      });

      test('gibt höchste Artikelnummer zurück', () async {
        await service.insertArtikel(_makeArtikel(artikelnummer: 1001));
        await service.insertArtikel(_makeArtikel(artikelnummer: 1005));
        await service.insertArtikel(_makeArtikel(artikelnummer: 1003));

        expect(await service.getMaxArtikelnummer(), equals(1005));
      });

      test('ignoriert soft-gelöschte Artikel', () async {
        await service.insertArtikel(_makeArtikel(artikelnummer: 1001));
        final hoechste = _makeArtikel(artikelnummer: 9999);
        final id = await service.insertArtikel(hoechste);
        await service.deleteArtikel(hoechste.copyWith(id: id));

        // ✅ 9999 ist deleted → MAX = 1001
        expect(await service.getMaxArtikelnummer(), equals(1001));
      });
    });

    // =======================================================================
    // deleteAlleArtikel()
    // =======================================================================
    group('deleteAlleArtikel()', () {
      test('markiert alle aktiven Artikel als gelöscht', () async {
        for (var i = 0; i < 3; i++) {
          await service.insertArtikel(_makeArtikel());
        }
        await service.deleteAlleArtikel();

        final alle = await service.getAlleArtikel();
        expect(alle, isEmpty);
        expect(await service.isDatabaseEmpty(), isTrue);
      });

      test('setzt etag auf null bei allen gelöschten Artikeln', () async {
        final artikel = _makeArtikel();
        await service.insertArtikel(artikel);
        await service.markSynced(artikel.uuid, 'etag-123');

        await service.deleteAlleArtikel();

        final pending = await service.getPendingChanges();
        // ✅ etag=null → alle gelöschten Artikel sind pending für Sync
        expect(pending.isNotEmpty, isTrue);
      });
    });

    // =======================================================================
    // insertArtikelList()
    // =======================================================================
    group('insertArtikelList()', () {
      test('fügt alle Artikel in der Liste ein', () async {
        final liste = List.generate(5, (_) => _makeArtikel());
        await service.insertArtikelList(liste);

        final alle = await service.getAlleArtikel();
        expect(alle.length, equals(5));
      });

      test('setzt etag=null für alle eingefügten Artikel (FIX Finding 5)',
          () async {
        // ✅ Restored Artikel müssen als pending erkannt werden
        final liste = [
          _makeArtikel(etag: 'alter-etag-1'),
          _makeArtikel(etag: 'alter-etag-2'),
        ];
        await service.insertArtikelList(liste);

        final pending = await service.getPendingChanges();
        expect(pending.length, equals(2));
      });

      test('leere Liste fügt nichts ein', () async {
        await service.insertArtikelList([]);
        expect(await service.isDatabaseEmpty(), isTrue);
      });

      test('nutzt Transaktion — alle oder keiner', () async {
        // ✅ Transaktion: Bei Fehler werden keine Artikel eingefügt
        // Wir können das nicht direkt testen ohne Fehler zu provozieren,
        // aber wir prüfen dass alle 3 atomar eingefügt werden
        final liste = List.generate(3, (_) => _makeArtikel());
        await service.insertArtikelList(liste);

        final alle = await service.getAlleArtikel();
        expect(alle.length, equals(3));
      });
    });

    // =======================================================================
    // Bild-Update-Methoden
    // =======================================================================
    group('Bild-Update-Methoden', () {
      test('updateBildPfad() aktualisiert bildPfad via ID', () async {
        final artikel = _makeArtikel();
        final id = await service.insertArtikel(artikel);

        final rows = await service.updateBildPfad(id, '/neu/pfad.jpg');
        expect(rows, equals(1));

        final alle = await service.getAlleArtikel();
        expect(alle.first.bildPfad, equals('/neu/pfad.jpg'));
      });

      test('updateBildPfad() gibt 0 zurück wenn ID nicht existiert', () async {
        final rows = await service.updateBildPfad(99999, '/pfad.jpg');
        expect(rows, equals(0));
      });

      test('updateRemoteBildPfad() aktualisiert remoteBildPfad via ID',
          () async {
        final artikel = _makeArtikel();
        final id = await service.insertArtikel(artikel);

        final rows = await service.updateRemoteBildPfad(id, '/remote/bild.jpg');
        expect(rows, equals(1));

        final db = await service.database;
        final result = await db.query(
          'artikel',
          where: 'id = ?',
          whereArgs: [id],
        );
        expect(result.first['remoteBildPfad'], equals('/remote/bild.jpg'));
      });

      test('setBildPfadByUuid() aktualisiert bildPfad via UUID', () async {
        final uuid = UuidGenerator.generate();
        await service.insertArtikel(_makeArtikel(uuid: uuid));

        await service.setBildPfadByUuid(uuid, '/uuid/pfad.jpg');

        final result = await service.getArtikelByUUID(uuid);
        expect(result!.bildPfad, equals('/uuid/pfad.jpg'));
      });

      test('setThumbnailPfadByUuid() aktualisiert thumbnailPfad', () async {
        final uuid = UuidGenerator.generate();
        await service.insertArtikel(_makeArtikel(uuid: uuid));

        await service.setThumbnailPfadByUuid(uuid, '/thumb/bild.jpg');

        final db = await service.database;
        final result = await db.query(
          'artikel',
          where: 'uuid = ?',
          whereArgs: [uuid],
        );
        expect(result.first['thumbnailPfad'], equals('/thumb/bild.jpg'));
      });

      test('setThumbnailEtagByUuid() aktualisiert thumbnailEtag', () async {
        final uuid = UuidGenerator.generate();
        await service.insertArtikel(_makeArtikel(uuid: uuid));

        await service.setThumbnailEtagByUuid(uuid, 'thumb-etag-abc');

        final db = await service.database;
        final result = await db.query(
          'artikel',
          where: 'uuid = ?',
          whereArgs: [uuid],
        );
        expect(result.first['thumbnailEtag'], equals('thumb-etag-abc'));
      });

      test('setRemoteBildPfadByUuid() setzt etag=null (FIX Finding 2)',
          () async {
        final uuid = UuidGenerator.generate();
        await service.insertArtikel(_makeArtikel(uuid: uuid));
        await service.markSynced(uuid, 'sync-etag');

        // ✅ Remote-Bildpfad setzen → Artikel wird dirty
        await service.setRemoteBildPfadByUuid(uuid, '/remote/neu.jpg');

        final db = await service.database;
        final result = await db.query(
          'artikel',
          where: 'uuid = ?',
          whereArgs: [uuid],
        );
        expect(result.first['etag'], isNull);
        expect(result.first['remoteBildPfad'], equals('/remote/neu.jpg'));
      });
    });

    // =======================================================================
    // getUnsyncedArtikel()
    // =======================================================================
    group('getUnsyncedArtikel()', () {
      test('gibt Artikel mit lokalem Bild aber ohne Remote-Bild zurück',
          () async {
        await service.insertArtikel(
          _makeArtikel(bildPfad: '/local/bild.jpg', remoteBildPfad: null),
        );

        final unsynced = await service.getUnsyncedArtikel();
        expect(unsynced.length, equals(1));
      });

      test('gibt Artikel mit Remote-Bild NICHT zurück', () async {
        await service.insertArtikel(
          _makeArtikel(
            bildPfad: '/local/bild.jpg',
            remoteBildPfad: '/remote/bild.jpg',
          ),
        );

        final unsynced = await service.getUnsyncedArtikel();
        expect(unsynced, isEmpty);
      });

      test('gibt Artikel ohne lokales Bild NICHT zurück', () async {
        await service.insertArtikel(_makeArtikel(bildPfad: ''));

        final unsynced = await service.getUnsyncedArtikel();
        expect(unsynced, isEmpty);
      });
    });
  });
}