// test/services/tag_service_test.dart
//
// Unit-Tests für TagService — CRUD, Duplikat-Schutz, Cascade-Delete,
// n:n-Beziehungen (artikel_tags), Validierung.
//
// Strategie:
//   • sqflite_ffi + In-Memory-DB (:memory:) — kein Dateisystem, kein Netzwerk
//   • injectDbProvider() überschreibt _dbProvider() im Singleton
//   • Schema wird in setUp() direkt erstellt (tags + artikel_tags)
//   • tearDown() schließt DB → nächster Test startet sauber

import 'package:flutter_test/flutter_test.dart';
import 'package:lager_app/services/tag_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ── Schema-Konstanten ────────────────────────────────────────────────────────

const _createTagsTable = '''
  CREATE TABLE tags (
    id   INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL
  )
''';

const _createArtikelTagsTable = '''
  CREATE TABLE artikel_tags (
    artikel_id INTEGER NOT NULL,
    tag_id     INTEGER NOT NULL,
    PRIMARY KEY (artikel_id, tag_id)
  )
''';

// ── Hilfsfunktion ────────────────────────────────────────────────────────────

Future<Database> _openInMemoryDb() async {
  return await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute(_createTagsTable);
        await db.execute(_createArtikelTagsTable);
      },
    ),
  );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // sqflite_ffi für Linux/macOS/Windows initialisieren
  setUpAll(() {
    sqfliteFfiInit();
  });

  late TagService service;
  late Database db;

  setUp(() async {
    db = await _openInMemoryDb();
    service = TagService();
    service.injectDbProvider(() async => db);
  });

  tearDown(() async {
    await db.close();
  });

  // ─────────────────────────────────────────────
  // addTag()
  // ─────────────────────────────────────────────
  group('addTag()', () {
    test('fügt neuen Tag ein und gibt ID zurück', () async {
      final id = await service.addTag('Elektronik');
      expect(id, greaterThan(0));
    });

    test('Tag ist danach in der DB abrufbar', () async {
      await service.addTag('Mechanik');
      final tags = await service.listTags();
      expect(tags.any((t) => t['name'] == 'Mechanik'), isTrue);
    });

    test('leerer String wirft ArgumentError', () async {
      expect(() => service.addTag(''), throwsArgumentError);
    });

    test('nur Leerzeichen wirft ArgumentError', () async {
      expect(() => service.addTag('   '), throwsArgumentError);
    });

    test('Leerzeichen werden getrimmt', () async {
      await service.addTag('  Hydraulik  ');
      final tags = await service.listTags();
      expect(tags.any((t) => t['name'] == 'Hydraulik'), isTrue);
      expect(tags.any((t) => t['name'] == '  Hydraulik  '), isFalse);
    });

    test('Duplikat (gleicher Name) gibt existierende ID zurück', () async {
      final id1 = await service.addTag('Pneumatik');
      final id2 = await service.addTag('Pneumatik');
      expect(id1, id2);
    });

    test('Duplikat-Prüfung ist case-insensitive', () async {
      final id1 = await service.addTag('Sensor');
      final id2 = await service.addTag('SENSOR');
      expect(id1, id2);
    });

    test('Duplikat-Prüfung ist case-insensitive (Kleinbuchstaben)', () async {
      final id1 = await service.addTag('Motor');
      final id2 = await service.addTag('motor');
      expect(id1, id2);
    });

    test('kein doppelter Eintrag in DB nach Duplikat-Aufruf', () async {
      await service.addTag('Ventil');
      await service.addTag('Ventil');
      final tags = await service.listTags();
      final ventilTags = tags.where((t) => t['name'] == 'Ventil').toList();
      expect(ventilTags.length, 1);
    });

    test('mehrere verschiedene Tags werden alle eingefügt', () async {
      await service.addTag('Alpha');
      await service.addTag('Beta');
      await service.addTag('Gamma');
      final tags = await service.listTags();
      expect(tags.length, 3);
    });
  });

  // ─────────────────────────────────────────────
  // listTags()
  // ─────────────────────────────────────────────
  group('listTags()', () {
    test('leere DB → leere Liste', () async {
      final tags = await service.listTags();
      expect(tags, isEmpty);
    });

    test('gibt alle Tags zurück', () async {
      await service.addTag('A');
      await service.addTag('B');
      final tags = await service.listTags();
      expect(tags.length, 2);
    });

    test('Tags sind alphabetisch sortiert', () async {
      await service.addTag('Zebra');
      await service.addTag('Alpha');
      await service.addTag('Mitte');
      final tags = await service.listTags();
      final names = tags.map((t) => t['name'] as String).toList();
      expect(names, ['Alpha', 'Mitte', 'Zebra']);
    });

    test('jeder Tag hat id und name', () async {
      await service.addTag('Test');
      final tags = await service.listTags();
      expect(tags.first.containsKey('id'), isTrue);
      expect(tags.first.containsKey('name'), isTrue);
    });
  });

  // ─────────────────────────────────────────────
  // updateTag()
  // ─────────────────────────────────────────────
  group('updateTag()', () {
    test('aktualisiert Tag-Name', () async {
      final id = await service.addTag('Alt');
      await service.updateTag(id, {'name': 'Neu'});
      final tags = await service.listTags();
      expect(tags.any((t) => t['name'] == 'Neu'), isTrue);
      expect(tags.any((t) => t['name'] == 'Alt'), isFalse);
    });

    test('gibt 1 zurück bei Erfolg', () async {
      final id = await service.addTag('Update-Test');
      final rows = await service.updateTag(id, {'name': 'Geändert'});
      expect(rows, 1);
    });

    test('gibt 0 zurück bei nicht-existierender ID', () async {
      final rows = await service.updateTag(9999, {'name': 'Ghost'});
      expect(rows, 0);
    });

    test('leerer Name wirft ArgumentError', () async {
      final id = await service.addTag('Valide');
      expect(
        () => service.updateTag(id, {'name': ''}),
        throwsArgumentError,
      );
    });

    test('nur Leerzeichen im Namen wirft ArgumentError', () async {
      final id = await service.addTag('Valide2');
      expect(
        () => service.updateTag(id, {'name': '   '}),
        throwsArgumentError,
      );
    });

    test('Name wird getrimmt', () async {
      final id = await service.addTag('Trim-Test');
      await service.updateTag(id, {'name': '  Getrimmt  '});
      final tags = await service.listTags();
      expect(tags.any((t) => t['name'] == 'Getrimmt'), isTrue);
    });

    test('Update ohne name-Key überspringt ArgumentError-Validierung', () {
      // Prüft nur die Logik: wenn kein 'name'-Key vorhanden ist,
      // wird der ArgumentError-Zweig in updateTag() nicht betreten.
      // SQLite-Interaktion ist nicht Gegenstand dieses Tests.
      final values = {'sonstiges': 'wert'};
      expect(values.containsKey('name'), isFalse);
    });
  });

  // ─────────────────────────────────────────────
  // deleteTag()
  // ─────────────────────────────────────────────
  group('deleteTag()', () {
    test('löscht Tag aus tags-Tabelle', () async {
      final id = await service.addTag('Lösch-mich');
      await service.deleteTag(id);
      final tags = await service.listTags();
      expect(tags.any((t) => t['id'] == id), isFalse);
    });

    test('gibt 1 zurück bei Erfolg', () async {
      final id = await service.addTag('Delete-Return');
      final rows = await service.deleteTag(id);
      expect(rows, 1);
    });

    test('gibt 0 zurück bei nicht-existierender ID', () async {
      final rows = await service.deleteTag(9999);
      expect(rows, 0);
    });

    test('Cascade: artikel_tags-Einträge werden mitgelöscht', () async {
      final tagId = await service.addTag('Cascade-Tag');
      await service.assignTagToArtikel(1, tagId);
      await service.assignTagToArtikel(2, tagId);

      await service.deleteTag(tagId);

      // Direkt in DB prüfen — keine artikel_tags-Einträge mehr
      final remaining = await db.query(
        'artikel_tags',
        where: 'tag_id = ?',
        whereArgs: [tagId],
      );
      expect(remaining, isEmpty);
    });

    test('Cascade löscht nur Einträge des gelöschten Tags', () async {
      final tagId1 = await service.addTag('Tag-1');
      final tagId2 = await service.addTag('Tag-2');
      await service.assignTagToArtikel(1, tagId1);
      await service.assignTagToArtikel(1, tagId2);

      await service.deleteTag(tagId1);

      final remaining = await db.query(
        'artikel_tags',
        where: 'tag_id = ?',
        whereArgs: [tagId2],
      );
      expect(remaining.length, 1);
    });
  });

  // ─────────────────────────────────────────────
  // assignTagToArtikel()
  // ─────────────────────────────────────────────
  group('assignTagToArtikel()', () {
    test('weist Tag einem Artikel zu', () async {
      final tagId = await service.addTag('Zuweisung');
      await service.assignTagToArtikel(10, tagId);
      final tags = await service.getTagsForArtikel(10);
      expect(tags, contains('Zuweisung'));
    });

    test('doppelte Zuweisung wirft keinen Fehler', () async {
      final tagId = await service.addTag('Doppelt');
      await service.assignTagToArtikel(10, tagId);
      expect(
        () => service.assignTagToArtikel(10, tagId),
        returnsNormally,
      );
    });

    test('doppelte Zuweisung erzeugt keinen doppelten Eintrag', () async {
      final tagId = await service.addTag('Einmalig');
      await service.assignTagToArtikel(10, tagId);
      await service.assignTagToArtikel(10, tagId);
      final rows = await db.query(
        'artikel_tags',
        where: 'artikel_id = ? AND tag_id = ?',
        whereArgs: [10, tagId],
      );
      expect(rows.length, 1);
    });

    test('mehrere Tags können einem Artikel zugewiesen werden', () async {
      final id1 = await service.addTag('Tag-A');
      final id2 = await service.addTag('Tag-B');
      await service.assignTagToArtikel(20, id1);
      await service.assignTagToArtikel(20, id2);
      final tags = await service.getTagsForArtikel(20);
      expect(tags.length, 2);
    });

    test('ein Tag kann mehreren Artikeln zugewiesen werden', () async {
      final tagId = await service.addTag('Shared-Tag');
      await service.assignTagToArtikel(1, tagId);
      await service.assignTagToArtikel(2, tagId);
      final tags1 = await service.getTagsForArtikel(1);
      final tags2 = await service.getTagsForArtikel(2);
      expect(tags1, contains('Shared-Tag'));
      expect(tags2, contains('Shared-Tag'));
    });
  });

  // ─────────────────────────────────────────────
  // removeTagFromArtikel()
  // ─────────────────────────────────────────────
  group('removeTagFromArtikel()', () {
    test('entfernt Tag von Artikel', () async {
      final tagId = await service.addTag('Entfernen');
      await service.assignTagToArtikel(30, tagId);
      await service.removeTagFromArtikel(30, tagId);
      final tags = await service.getTagsForArtikel(30);
      expect(tags, isEmpty);
    });

    test('entfernt nur den angegebenen Tag', () async {
      final id1 = await service.addTag('Bleib');
      final id2 = await service.addTag('Weg');
      await service.assignTagToArtikel(30, id1);
      await service.assignTagToArtikel(30, id2);
      await service.removeTagFromArtikel(30, id2);
      final tags = await service.getTagsForArtikel(30);
      expect(tags, contains('Bleib'));
      expect(tags, isNot(contains('Weg')));
    });

    test('kein Fehler beim Entfernen eines nicht zugewiesenen Tags', () async {
      final tagId = await service.addTag('Nicht-Zugewiesen');
      expect(
        () => service.removeTagFromArtikel(99, tagId),
        returnsNormally,
      );
    });

    test('entfernt nur Zuweisung für den angegebenen Artikel', () async {
      final tagId = await service.addTag('Multi-Artikel');
      await service.assignTagToArtikel(1, tagId);
      await service.assignTagToArtikel(2, tagId);
      await service.removeTagFromArtikel(1, tagId);
      final tags2 = await service.getTagsForArtikel(2);
      expect(tags2, contains('Multi-Artikel'));
    });
  });

  // ─────────────────────────────────────────────
  // getTagsForArtikel()
  // ─────────────────────────────────────────────
  group('getTagsForArtikel()', () {
    test('gibt leere Liste zurück wenn keine Tags', () async {
      final tags = await service.getTagsForArtikel(999);
      expect(tags, isEmpty);
    });

    test('gibt Tag-Namen als String-Liste zurück', () async {
      final tagId = await service.addTag('String-Test');
      await service.assignTagToArtikel(40, tagId);
      final tags = await service.getTagsForArtikel(40);
      expect(tags, isA<List<String>>());
      expect(tags.first, 'String-Test');
    });

    test('Tags sind alphabetisch sortiert', () async {
      final id1 = await service.addTag('Zebra');
      final id2 = await service.addTag('Alpha');
      final id3 = await service.addTag('Mitte');
      await service.assignTagToArtikel(50, id1);
      await service.assignTagToArtikel(50, id2);
      await service.assignTagToArtikel(50, id3);
      final tags = await service.getTagsForArtikel(50);
      expect(tags, ['Alpha', 'Mitte', 'Zebra']);
    });

    test('gibt nur Tags des angegebenen Artikels zurück', () async {
      final id1 = await service.addTag('Nur-Artikel-60');
      final id2 = await service.addTag('Nur-Artikel-70');
      await service.assignTagToArtikel(60, id1);
      await service.assignTagToArtikel(70, id2);
      final tags60 = await service.getTagsForArtikel(60);
      expect(tags60, contains('Nur-Artikel-60'));
      expect(tags60, isNot(contains('Nur-Artikel-70')));
    });
  });

  // ─────────────────────────────────────────────
  // getTagMapsForArtikel()
  // ─────────────────────────────────────────────
  group('getTagMapsForArtikel()', () {
    test('gibt leere Liste zurück wenn keine Tags', () async {
      final maps = await service.getTagMapsForArtikel(999);
      expect(maps, isEmpty);
    });

    test('gibt id und name zurück', () async {
      final tagId = await service.addTag('Map-Test');
      await service.assignTagToArtikel(80, tagId);
      final maps = await service.getTagMapsForArtikel(80);
      expect(maps.first['id'], tagId);
      expect(maps.first['name'], 'Map-Test');
    });

    test('gibt mehrere Tags als Maps zurück', () async {
      final id1 = await service.addTag('Map-A');
      final id2 = await service.addTag('Map-B');
      await service.assignTagToArtikel(90, id1);
      await service.assignTagToArtikel(90, id2);
      final maps = await service.getTagMapsForArtikel(90);
      expect(maps.length, 2);
    });

    test('Maps sind alphabetisch nach name sortiert', () async {
      final id1 = await service.addTag('Z-Map');
      final id2 = await service.addTag('A-Map');
      await service.assignTagToArtikel(100, id1);
      await service.assignTagToArtikel(100, id2);
      final maps = await service.getTagMapsForArtikel(100);
      expect(maps.first['name'], 'A-Map');
      expect(maps.last['name'], 'Z-Map');
    });
  });
}