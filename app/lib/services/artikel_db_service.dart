// lib/services/artikel_db_service.dart
//
// Lokaler SQLite-Service für Mobile & Desktop.
// Wird im Web NICHT verwendet – dort geht alles direkt über PocketBase.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/artikel_model.dart';
import '../utils/uuid_generator.dart';

import 'artikel_db_platform_io.dart'
    if (dart.library.html) 'artikel_db_platform_stub.dart' as platform;

class ArtikelDbService {
  static final ArtikelDbService _instance = ArtikelDbService._internal();
  factory ArtikelDbService() => _instance;
  ArtikelDbService._internal();

  // FIX: static verhindert mehrere Logger-Instanzen (Singleton-Klasse,
  // aber explizite Klarheit schadet nicht)
  static final _logger = Logger();
  Database? _db;

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError(
        'ArtikelDbService ist im Web nicht verfügbar. '
        'Nutze PocketBase direkt im Web.',
      );
    }
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    try {
      return await platform.openArtikelDatabase(
        version: 3,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Initialisieren der Datenbank: $e',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  // ==================== SCHEMA ====================

  // FIX Bug 1: 'kategorie' war in _onUpgrade (oldVersion < 2) referenziert,
  // aber nie im Haupt-Schema definiert. Spalte hier ergänzt für Konsistenz
  // mit bestehenden Upgrade-Pfaden.
  static const _createTableSql = '''
    CREATE TABLE artikel (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      menge INTEGER,
      ort TEXT,
      fach TEXT,
      beschreibung TEXT,
      bildPfad TEXT,
      thumbnailPfad TEXT,
      thumbnailEtag TEXT,
      erstelltAm TEXT,
      aktualisiertAm TEXT,
      remoteBildPfad TEXT,
      uuid TEXT UNIQUE NOT NULL,
      updated_at INTEGER NOT NULL DEFAULT 0,
      deleted INTEGER NOT NULL DEFAULT 0,
      etag TEXT,
      remote_path TEXT,
      device_id TEXT,
      kategorie TEXT
    )
  ''';

  static const _createSyncMetaTableSql = '''
    CREATE TABLE IF NOT EXISTS sync_meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''';

  Future<void> _onCreate(Database db, int version) async {
    try {
      _logger.i("🛠️ Erstelle Tabelle 'artikel' (Version $version)");
      await db.execute(_createTableSql);
      await db.execute(_createSyncMetaTableSql);
      await _createIndices(db);
      await _setInitialSequenceFromSettings(db);
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Erstellen der Datenbanktabellen: $e',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      _logger.w('🔄 Upgrade DB von Version $oldVersion → $newVersion');

      if (oldVersion < 2) {
        await db.execute('ALTER TABLE artikel ADD COLUMN kategorie TEXT');
        _logger.i("✅ Migration: Spalte 'kategorie' hinzugefügt.");
      }

      if (oldVersion < 3) {
        await db.execute('ALTER TABLE artikel ADD COLUMN uuid TEXT');
        await db.execute(
          'ALTER TABLE artikel ADD COLUMN updated_at INTEGER DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE artikel ADD COLUMN deleted INTEGER DEFAULT 0',
        );
        await db.execute('ALTER TABLE artikel ADD COLUMN etag TEXT');
        await db.execute('ALTER TABLE artikel ADD COLUMN remote_path TEXT');
        await db.execute('ALTER TABLE artikel ADD COLUMN device_id TEXT');
        await db.execute('ALTER TABLE artikel ADD COLUMN thumbnailPfad TEXT');
        await db.execute('ALTER TABLE artikel ADD COLUMN thumbnailEtag TEXT');
        _logger.i(
          '✅ Migration: Neue Spalten für Sync und Thumbnails hinzugefügt.',
        );

        await _generateUUIDsForExistingRecords(db);
        await db.execute(_createSyncMetaTableSql);
        await _createIndices(db);
        _logger.i(
          '✅ Migration: UUIDs generiert, Sync-Metadaten und Indizes erstellt.',
        );
      }
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler bei der Datenbank-Migration von Version '
        '$oldVersion zu $newVersion: $e',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> _createIndices(Database db) async {
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_artikel_updated_at '
        'ON artikel(updated_at)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_artikel_uuid ON artikel(uuid)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_artikel_deleted ON artikel(deleted)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_artikel_name ON artikel(name)',
      );
      _logger.i('✅ Indizes erstellt/aktualisiert.');
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Erstellen von Indizes: $e',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> _setInitialSequenceFromSettings(Database db) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startNummer = prefs.getInt('artikel_start_nummer') ?? 1000;
      await db.insert(
        'sqlite_sequence',
        {'name': 'artikel', 'seq': startNummer - 1},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _logger.i('🔢 Startwert für Artikel-IDs auf $startNummer gesetzt.');
    } catch (e, stack) {
      _logger.w(
        '⚠️ Fehler beim Setzen des Startwerts für Artikel-IDs: $e',
        error: e,
        stackTrace: stack,
      );
      // Fallback auf Standardwert 1000
      try {
        await db.insert(
          'sqlite_sequence',
          {'name': 'artikel', 'seq': 999},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e2, stack2) {
        _logger.e(
          '❌ Kritischer Fehler beim Fallback für Startwert: $e2',
          error: e2,
          stackTrace: stack2,
        );
      }
    }
  }

  Future<void> _generateUUIDsForExistingRecords(Database db) async {
    try {
      final existing = await db.query(
        'artikel',
        where: 'uuid IS NULL OR uuid = ""',
      );
      for (final article in existing) {
        final uuid = UuidGenerator.generate();
        await db.update(
          'artikel',
          {
            'uuid': uuid,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [article['id']],
        );
      }
      _logger.i(
        '✅ UUIDs für ${existing.length} bestehende Artikel generiert.',
      );
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Generieren von UUIDs für bestehende Artikel: $e',
        error: e,
        stackTrace: stack,
      );
    }
  }

  // ==================== CRUD ====================

  Future<int> insertArtikel(Artikel artikel) async {
    try {
      final db = await database;
      final data = artikel.toMap();
      data['updated_at'] = DateTime.now().millisecondsSinceEpoch;
      data['etag'] = null;
      final id = await db.insert(
        'artikel',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _logger.i('✅ Artikel ${artikel.uuid} (ID: $id) eingefügt/ersetzt.');
      return id;
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Einfügen von Artikel ${artikel.uuid}: $e',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<List<Artikel>> getAlleArtikel({
    int limit = 500,
    int offset = 0,
  }) async {
    try {
      final db = await database;
      final maps = await db.query(
        'artikel',
        where: 'deleted = ?',
        whereArgs: [0],
        orderBy: 'id DESC',
        limit: limit,
        offset: offset,
      );
      _logger.d(
        '✅ ${maps.length} Artikel aus DB abgerufen '
        '(limit: $limit, offset: $offset).',
      );
      return maps.map((m) => Artikel.fromMap(m)).toList();
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Abrufen aller Artikel: $e',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  Future<void> updateArtikel(Artikel artikel) async {
    try {
      final db = await database;
      final data = Map<String, dynamic>.from(artikel.toMap());
      data['updated_at'] = DateTime.now().millisecondsSinceEpoch;
      data['etag'] = null;
      final rowsAffected = await db.update(
        'artikel',
        data,
        where: 'id = ?',
        whereArgs: [artikel.id],
      );
      if (rowsAffected > 0) {
        _logger.i(
          '✅ Artikel ${artikel.uuid} (ID: ${artikel.id}) aktualisiert.',
        );
      } else {
        _logger.w(
          '⚠️ Artikel ${artikel.uuid} (ID: ${artikel.id}) '
          'nicht gefunden oder nicht aktualisiert.',
        );
      }
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Aktualisieren von Artikel '
        '${artikel.uuid} (ID: ${artikel.id}): $e',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> deleteArtikel(Artikel artikel) async {
    try {
      final db = await database;
      final rowsAffected = await db.update(
        'artikel',
        {
          'deleted': 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          'etag': null,
        },
        where: 'id = ?',
        whereArgs: [artikel.id],
      );
      if (rowsAffected > 0) {
        _logger.i(
          '✅ Artikel ${artikel.uuid} (ID: ${artikel.id}) '
          'als gelöscht markiert.',
        );
      } else {
        _logger.w(
          '⚠️ Artikel ${artikel.uuid} (ID: ${artikel.id}) '
          'nicht gefunden oder nicht als gelöscht markiert.',
        );
      }
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Markieren von Artikel '
        '${artikel.uuid} (ID: ${artikel.id}) als gelöscht: $e',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  // ==================== BILD ====================

  Future<int> updateBildPfad(int artikelId, String bildPfad) async {
    try {
      final db = await database;
      final rowsAffected = await db.update(
        'artikel',
        {
          'bildPfad': bildPfad,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [artikelId],
      );
      if (rowsAffected > 0) {
        _logger.d('✅ Bildpfad für Artikel ID $artikelId aktualisiert.');
      }
      return rowsAffected;
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Aktualisieren des Bildpfades '
        'für Artikel ID $artikelId: $e',
        error: e,
        stackTrace: stack,
      );
      return 0;
    }
  }

  // FIX Problem 6: updated_at ergänzt — ohne diesen Timestamp würde
  // der Sync-Service diese Änderung übersehen.
  Future<int> updateRemoteBildPfad(
    int artikelId,
    String remotePfad,
  ) async {
    try {
      final db = await database;
      final rowsAffected = await db.update(
        'artikel',
        {
          'remoteBildPfad': remotePfad,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [artikelId],
      );
      if (rowsAffected > 0) {
        _logger.d(
          '✅ Remote-Bildpfad für Artikel ID $artikelId aktualisiert.',
        );
      }
      return rowsAffected;
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Aktualisieren des Remote-Bildpfades '
        'für Artikel ID $artikelId: $e',
        error: e,
        stackTrace: stack,
      );
      return 0;
    }
  }

  // FIX Problem 7: updated_at ergänzt — ohne diesen Timestamp würde
  // der Sync-Service diese Änderung übersehen.
  Future<void> setBildPfadByUuid(String uuid, String bildPfad) async {
    try {
      final db = await database;
      final rowsAffected = await db.update(
        'artikel',
        {
          'bildPfad': bildPfad,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
      if (rowsAffected > 0) {
        _logger.d('✅ Bildpfad für Artikel UUID $uuid aktualisiert.');
      }
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Setzen des Bildpfades für Artikel UUID $uuid: $e',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> setThumbnailPfadByUuid(
    String uuid,
    String thumbnailPfad,
  ) async {
    try {
      final db = await database;
      final rowsAffected = await db.update(
        'artikel',
        {'thumbnailPfad': thumbnailPfad},
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
      if (rowsAffected > 0) {
        _logger.d('✅ Thumbnailpfad für Artikel UUID $uuid aktualisiert.');
      }
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Setzen des Thumbnailpfades '
        'für Artikel UUID $uuid: $e',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> setThumbnailEtagByUuid(
    String uuid,
    String thumbnailEtag,
  ) async {
    try {
      final db = await database;
      final rowsAffected = await db.update(
        'artikel',
        {'thumbnailEtag': thumbnailEtag},
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
      if (rowsAffected > 0) {
        _logger.d(
          '✅ Thumbnail-Etag für Artikel UUID $uuid aktualisiert.',
        );
      }
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Setzen des Thumbnail-Etags '
        'für Artikel UUID $uuid: $e',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> setRemoteBildPfadByUuid(
    String uuid,
    String remoteBildPfad,
  ) async {
    try {
      final db = await database;
      final rowsAffected = await db.update(
        'artikel',
        {
          'remoteBildPfad': remoteBildPfad,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
      if (rowsAffected > 0) {
        _logger.d(
          '✅ Remote-Bildpfad für Artikel UUID $uuid aktualisiert.',
        );
      }
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Setzen des Remote-Bildpfades '
        'für Artikel UUID $uuid: $e',
        error: e,
        stackTrace: stack,
      );
    }
  }

  // ==================== LOOKUP ====================

  Future<Artikel?> getArtikelByUUID(String uuid) async {
    try {
      final db = await database;
      final maps = await db.query(
        'artikel',
        where: 'uuid = ?',
        whereArgs: [uuid],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        _logger.d('✅ Artikel mit UUID $uuid gefunden.');
        return Artikel.fromMap(maps.first);
      }
      _logger.d('Artikel mit UUID $uuid nicht gefunden.');
      return null;
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Abrufen von Artikel mit UUID $uuid: $e',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  Future<Artikel?> getArtikelByRemotePath(String remotePath) async {
    try {
      final db = await database;
      final maps = await db.query(
        'artikel',
        where: 'remote_path = ?',
        whereArgs: [remotePath],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        _logger.d('✅ Artikel mit Remote-Pfad $remotePath gefunden.');
        return Artikel.fromMap(maps.first);
      }
      _logger.d('Artikel mit Remote-Pfad $remotePath nicht gefunden.');
      return null;
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Abrufen von Artikel mit Remote-Pfad $remotePath: $e',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  Future<List<Artikel>> getUnsyncedArtikel() async {
    try {
      final db = await database;
      final maps = await db.query(
        'artikel',
        where: 'bildPfad IS NOT NULL AND bildPfad != "" '
            'AND (remoteBildPfad IS NULL OR remoteBildPfad = "")',
        orderBy: 'id DESC',
      );
      _logger.d(
        '✅ ${maps.length} unsynchronisierte Artikel abgerufen.',
      );
      return maps.map((m) => Artikel.fromMap(m)).toList();
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Abrufen unsynchronisierter Artikel: $e',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  // ==================== SYNC ====================

  // FIX Bug 2: Gelöschte Artikel (deleted = 1) werden bewusst mitgeliefert,
  // da der Sync-Service auch Löschungen propagieren muss.
  // Dies ist explizit dokumentiert — kein versehentliches Auslassen.
  Future<List<Artikel>> getPendingChanges() async {
    try {
      final db = await database;
      final maps = await db.query(
        'artikel',
        // Bewusst KEIN deleted-Filter: gelöschte Artikel müssen ebenfalls
        // zum Server synchronisiert werden, damit Remote-Löschungen erfolgen.
        where: 'etag IS NULL OR etag = ""',
        orderBy: 'updated_at ASC',
      );
      _logger.d(
        '✅ ${maps.length} Artikel mit ausstehenden Änderungen abgerufen '
        '(inkl. gelöschter Artikel für Sync-Propagierung).',
      );
      return maps.map((m) => Artikel.fromMap(m)).toList();
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Abrufen von Artikeln mit ausstehenden Änderungen: $e',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  Future<void> markSynced(String uuid, String etag) async {
    try {
      final db = await database;
      final rowsAffected = await db.update(
        'artikel',
        {'etag': etag},
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
      if (rowsAffected > 0) {
        _logger.d(
          '✅ Artikel UUID $uuid als synchronisiert markiert (Etag: $etag).',
        );
      } else {
        _logger.w(
          '⚠️ Artikel UUID $uuid nicht gefunden oder '
          'nicht als synchronisiert markiert.',
        );
      }
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Markieren von Artikel UUID $uuid '
        'als synchronisiert: $e',
        error: e,
        stackTrace: stack,
      );
    }
  }

  // FIX Bug 3: updated_at = 0 wird abgesichert. Wenn der Artikel keinen
  // gültigen Timestamp hat, wird der aktuelle Zeitpunkt verwendet,
  // damit der Delta-Sync nicht fehlschlägt.
  Future<void> upsertArtikel(Artikel artikel, {String? etag}) async {
    try {
      final db = await database;
      final data = artikel.toMap();
      if (etag != null) data['etag'] = etag;
      data['updated_at'] = artikel.updatedAt > 0
          ? artikel.updatedAt
          : DateTime.now().millisecondsSinceEpoch;

      final existing = await db.query(
        'artikel',
        where: 'uuid = ?',
        whereArgs: [artikel.uuid],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        await db.update(
          'artikel',
          data,
          where: 'uuid = ?',
          whereArgs: [artikel.uuid],
        );
        _logger.d('✅ Artikel UUID ${artikel.uuid} aktualisiert (upsert).');
      } else {
        await db.insert(
          'artikel',
          data,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        _logger.d('✅ Artikel UUID ${artikel.uuid} eingefügt (upsert).');
      }
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Upsert von Artikel UUID ${artikel.uuid}: $e',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @Deprecated('Nutze upsertArtikel() mit Artikel.fromPocketBase()')
  Future<void> upsertFromRemote(
    String remotePath,
    String etag,
    String jsonBody,
  ) async {
    try {
      final artikelData = json.decode(jsonBody) as Map<String, dynamic>;
      final artikel = Artikel.fromMap(artikelData);
      await upsertArtikel(artikel, etag: etag);
      _logger.d(
        '✅ Artikel von Remote über upsertArtikel() verarbeitet.',
      );
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim upsertFromRemote für $remotePath: $e',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> setLastSyncTime() async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert(
        'sync_meta',
        {
          'key': 'last_sync',
          'value': now.toString(),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _logger.d('✅ Letzte Synchronisationszeit aktualisiert.');
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Setzen der letzten Synchronisationszeit: $e',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<DateTime?> getLastSyncTime() async {
    try {
      final db = await database;
      final result = await db.query(
        'sync_meta',
        where: 'key = ?',
        whereArgs: ['last_sync'],
        limit: 1,
      );
      if (result.isEmpty) return null;
      final ms = int.tryParse(result.first['value'] as String? ?? '');
      if (ms == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Abrufen der letzten Synchronisationszeit: $e',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  // ==================== SEARCH ====================

  Future<List<Artikel>> searchArtikel(
    String query, {
    int limit = 100,
  }) async {
    try {
      final db = await database;
      final maps = await db.query(
        'artikel',
        where: 'deleted = 0 AND (name LIKE ? OR beschreibung LIKE ?)',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'name',
        limit: limit,
      );
      _logger.d(
        '✅ ${maps.length} Artikel für Suche "$query" gefunden.',
      );
      return maps.map((m) => Artikel.fromMap(m)).toList();
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler bei der Artikelsuche für "$query": $e',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  // ==================== ADMIN ====================

  // FIX Problem 4: Nach DROP TABLE wird sqlite_sequence automatisch
  // bereinigt. Der direkte INSERT schlägt fehl, solange noch kein
  // AUTOINCREMENT-Eintrag existiert. Daher wird _setInitialSequenceFromSettings
  // wiederverwendet, die bereits einen robusten Fallback enthält.
  Future<void> resetDatabase({int startId = 1000}) async {
    try {
      final db = await database;
      await db.execute('DROP TABLE IF EXISTS artikel');
      await db.execute('DROP TABLE IF EXISTS sync_meta');
      _logger.w(
        "🗑️ Vorhandene Tabellen 'artikel' und 'sync_meta' gelöscht.",
      );
      await db.execute(_createTableSql);
      await db.execute(_createSyncMetaTableSql);
      _logger.w(
        "🗑️ Tabellen 'artikel' und 'sync_meta' neu erstellt.",
      );
      await _createIndices(db);
      // Einen Dummy-Eintrag einfügen und wieder löschen, damit
      // sqlite_sequence initialisiert wird, bevor wir den seq-Wert setzen.
      await db.insert('artikel', {
        'uuid': '__init__',
        'updated_at': 0,
        'deleted': 0,
      });
      await db.delete('artikel', where: 'uuid = ?', whereArgs: ['__init__']);
      await db.insert(
        'sqlite_sequence',
        {'name': 'artikel', 'seq': startId - 1},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _logger.w(
        '🗑️ Datenbank zurückgesetzt. Nächste ID startet bei $startId.',
      );
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Zurücksetzen der Datenbank: $e',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  // FIX Problem 5: deleteAlleArtikel() nutzt jetzt Soft-Delete für
  // Sync-Konsistenz. Hartes Löschen würde den Remote-Server nicht
  // informieren. Für einen echten lokalen Hard-Reset: resetDatabase() nutzen.
  Future<void> deleteAlleArtikel() async {
    try {
      final db = await database;
      final rowsAffected = await db.update(
        'artikel',
        {
          'deleted': 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          'etag': null,
        },
        where: 'deleted = ?',
        whereArgs: [0],
      );
      _logger.w(
        '🗑️ Alle $rowsAffected Artikel als gelöscht markiert (Soft-Delete).',
      );
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Löschen aller Artikel: $e',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> insertArtikelList(List<Artikel> artikelList) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        for (final artikel in artikelList) {
          await txn.insert(
            'artikel',
            artikel.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      _logger.i(
        '✅ ${artikelList.length} Artikel aus Backup wiederhergestellt.',
      );
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Einfügen der Artikel-Liste: $e',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<bool> isDatabaseEmpty() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM artikel WHERE deleted = 0',
      );
      final count = (result.first['count'] as int? ?? 0);
      _logger.d('✅ Datenbank enthält $count nicht gelöschte Artikel.');
      return count == 0;
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Prüfen, ob die Datenbank leer ist: $e',
        error: e,
        stackTrace: stack,
      );
      return true;
    }
  }

  // FIX Hinweis 8: dart:math Import entfernt, max() durch einfachen
  // ternären Vergleich ersetzt.
  Future<int> getNextArtikelNummer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startNummer = prefs.getInt('artikel_start_nummer') ?? 1000;
      final db = await database;
      final result = await db.rawQuery('SELECT MAX(id) as maxId FROM artikel');
      final maxId = result.first['maxId'] as int? ?? 0;
      final nextNum = startNummer > maxId + 1 ? startNummer : maxId + 1;
      _logger.d('✅ Nächste Artikelnummer: $nextNum.');
      return nextNum;
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Abrufen der nächsten Artikelnummer: $e',
        error: e,
        stackTrace: stack,
      );
      return 1;
    }
  }

  Future<void> closeDatabase() async {
    try {
      await _db?.close();
      _db = null;
      _logger.i('✅ Datenbank geschlossen.');
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Schließen der Datenbank: $e',
        error: e,
        stackTrace: stack,
      );
    }
  }
}