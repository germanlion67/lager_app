import 'package:flutter/foundation.dart' show kIsWeb;
//import 'package:sqflite/sqflite.dart'; // Für Mobile (Android/iOS)
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Für Desktop
import 'package:path/path.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:math';
import '../models/artikel_model.dart';

class ArtikelDbService {
  static final ArtikelDbService _instance = ArtikelDbService._internal();
  factory ArtikelDbService() => _instance;
  ArtikelDbService._internal();

  final logger = Logger();
  Database? _db;

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite wird im Web nicht unterstützt');
    }
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    try {
      String path;

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // ✅ Desktop mit FFI
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;

        final dbPath = await databaseFactoryFfi.getDatabasesPath();
        path = join(dbPath, 'artikel.db');

        return await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 3,
            onCreate: (db, version) async {
              logger.i("🛠️ Erstelle Tabelle 'artikel' (Version $version)");
              await db.execute(_createTableSql);
              await db.execute(_createSyncMetaTableSql);
              try {
                await db.execute(_createFtsTableSql);
              } catch (e) {
                logger.w('FTS5 nicht verfügbar: $e');
              }
              await _createIndices(db);
              // ⬇️ Startwert für IDs aus Einstellungen verwenden
              await _setInitialSequenceFromSettings(db);
            },
            onUpgrade: (db, oldVersion, newVersion) async {
              await _upgradeDb(db, oldVersion, newVersion);
            },
          ),
        );
      } else {
        // ✅ Mobile (Android/iOS)
        final dbPath = await getDatabasesPath();
        path = join(dbPath, 'artikel.db');

        return await openDatabase(
          path,
          version: 3,
          onCreate: (db, version) async {
            logger.i("🛠️ Erstelle Tabelle 'artikel' (Version $version)");
            await db.execute(_createTableSql);
            await db.execute(_createSyncMetaTableSql);
            try {
              await db.execute(_createFtsTableSql);
            } catch (e) {
              logger.w('FTS5 nicht verfügbar: $e');
            }
            await _createIndices(db);
            // ⬇️ Startwert für IDs aus Einstellungen verwenden
            await _setInitialSequenceFromSettings(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            await _upgradeDb(db, oldVersion, newVersion);
          },
        );
      }
    } catch (e, stack) {
      logger.e("❌ Fehler beim Initialisieren der DB", error: e, stackTrace: stack);
      rethrow;
    }
  }

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
      updated_at INTEGER NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0,
      etag TEXT,
      remote_path TEXT,
      device_id TEXT
    )
  ''';

  static const _createSyncMetaTableSql = '''
    CREATE TABLE IF NOT EXISTS sync_meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''';

  static const _createFtsTableSql = '''
    CREATE VIRTUAL TABLE IF NOT EXISTS artikel_fts USING fts5(
      name, beschreibung, ort, fach, kategorie, content='artikel', content_rowid='id'
    );
  ''';

  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    logger.w("🔄 Upgrade DB von Version $oldVersion → $newVersion");
    
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE artikel ADD COLUMN kategorie TEXT");
      logger.i("➕ Spalte 'kategorie' hinzugefügt");
    }

    if (oldVersion < 3) {
      // Sync-Felder hinzufügen
      await db.execute("ALTER TABLE artikel ADD COLUMN uuid TEXT");
      await db.execute("ALTER TABLE artikel ADD COLUMN updated_at INTEGER DEFAULT 0");
      await db.execute("ALTER TABLE artikel ADD COLUMN deleted INTEGER DEFAULT 0");
      await db.execute("ALTER TABLE artikel ADD COLUMN etag TEXT");
      await db.execute("ALTER TABLE artikel ADD COLUMN remote_path TEXT");
      await db.execute("ALTER TABLE artikel ADD COLUMN device_id TEXT");
      await db.execute("ALTER TABLE artikel ADD COLUMN thumbnailPfad TEXT");
      await db.execute("ALTER TABLE artikel ADD COLUMN thumbnailEtag TEXT");
      
      // UUID für bestehende Artikel generieren
      await _generateUUIDsForExistingRecords(db);
      
      // Sync-Meta Tabelle und Indizes erstellen
      await db.execute(_createSyncMetaTableSql);
      await db.execute(_createFtsTableSql);
      await _createIndices(db);
      
      logger.i("➕ Sync-Felder hinzugefügt");
    }
  }

  Future<void> _createIndices(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_artikel_updated_at ON artikel(updated_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_artikel_uuid ON artikel(uuid)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_artikel_deleted ON artikel(deleted)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_artikel_name ON artikel(name)');
  }

  /// Setzt den lokalen Bildpfad anhand der UUID
  Future<void> setBildPfadByUuid(String uuid, String bildPfad) async {
    try {
      final db = await database;
      await db.update(
        'artikel',
        {'bildPfad': bildPfad},
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
      logger.d('Bildpfad für UUID $uuid aktualisiert: $bildPfad');
    } catch (e, stackTrace) {
      logger.e('Fehler beim Aktualisieren des Bildpfads nach UUID', error: e, stackTrace: stackTrace);
      throw DatabaseException('Bildpfad konnte nicht aktualisiert werden: $e');
    }
  }

  /// Setzt den Thumbnail-Pfad anhand der UUID
  Future<void> setThumbnailPfadByUuid(String uuid, String thumbnailPfad) async {
    try {
      final db = await database;
      await db.update(
        'artikel',
        {'thumbnailPfad': thumbnailPfad},
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
      logger.d('ThumbnailPfad für UUID $uuid aktualisiert: $thumbnailPfad');
    } catch (e, stackTrace) {
      logger.e('Fehler beim Aktualisieren des ThumbnailPfads nach UUID', error: e, stackTrace: stackTrace);
      throw DatabaseException('ThumbnailPfad konnte nicht aktualisiert werden: $e');
    }
  }

  /// Setzt den Thumbnail-ETag anhand der UUID
  Future<void> setThumbnailEtagByUuid(String uuid, String thumbnailEtag) async {
    try {
      final db = await database;
      await db.update(
        'artikel',
        {'thumbnailEtag': thumbnailEtag},
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
      logger.d('Thumbnail-ETag für UUID $uuid aktualisiert: $thumbnailEtag');
    } catch (e, stackTrace) {
      logger.e('Fehler beim Aktualisieren des Thumbnail-ETags nach UUID', error: e, stackTrace: stackTrace);
      throw DatabaseException('Thumbnail-ETag konnte nicht aktualisiert werden: $e');
    }
  }

  Future<void> _generateUUIDsForExistingRecords(Database db) async {
    // Bestehende Artikel ohne UUID aktualisieren
    final existingArticles = await db.query('artikel', where: 'uuid IS NULL OR uuid = ""');
    for (final article in existingArticles) {
      final uuid = _generateUUID();
      final updatedAt = DateTime.now().millisecondsSinceEpoch;
      await db.update(
        'artikel',
        {'uuid': uuid, 'updated_at': updatedAt},
        where: 'id = ?',
        whereArgs: [article['id']],
      );
    }
  }

  // UUID-Generierung für DB-Service
  static String _generateUUID() {
    return '${_randomHex(8)}-${_randomHex(4)}-${_randomHex(4)}-${_randomHex(4)}-${_randomHex(12)}';
  }

  static String _randomHex(int length) {
    final random = Random();
    const chars = '0123456789abcdef';
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(16)))
    );
  }

  // Datenbank zurücksetzen nach testphase
  Future<void> resetDatabase({int startId = 1000}) async {
    try {
      final db = await database;

      // Tabelle löschen
      await db.execute("DROP TABLE IF EXISTS artikel");

      // Neu erstellen
      await db.execute(_createTableSql);

      // Startwert für ID setzen
      await db.insert('sqlite_sequence', {'name': 'artikel', 'seq': startId - 1});

      logger.w("🗑️ Datenbank zurückgesetzt. Nächste ID startet bei $startId");
    } catch (e, stackTrace) {
      logger.e('Fehler beim Zurücksetzen der Datenbank', error: e, stackTrace: stackTrace);
      throw DatabaseException('Datenbank konnte nicht zurückgesetzt werden: $e');
    }
  }


  Future<int> insertArtikel(Artikel artikel) async {
    try {
      final db = await database;
      return await db.insert('artikel', artikel.toMap());
    } catch (e, stackTrace) {
      logger.e('Fehler beim Einfügen eines Artikels', error: e, stackTrace: stackTrace);
      throw DatabaseException('Artikel konnte nicht gespeichert werden: $e');
    }
  }

  Future<List<Artikel>> getAlleArtikel() async {
    try {
      final db = await database;
      final maps = await db.query('artikel', orderBy: 'id DESC');
      return maps.map((map) => Artikel.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.e('Fehler beim Laden aller Artikel', error: e, stackTrace: stackTrace);
      throw DatabaseException('Artikel konnten nicht geladen werden: $e');
    }
  }

  Future<int> updateArtikel(Artikel artikel) async {
    try {
      final db = await database;
      return await db.update(
        'artikel',
        artikel.toMap(),
        where: 'id = ?',
        whereArgs: [artikel.id],
      );
    } catch (e, stackTrace) {
      logger.e('Fehler beim Aktualisieren eines Artikels', error: e, stackTrace: stackTrace);
      throw DatabaseException('Artikel konnte nicht aktualisiert werden: $e');
    }
  }

  Future<int> deleteArtikel(int id) async {
    try {
      final db = await database;
      return await db.delete('artikel', where: 'id = ?', whereArgs: [id]);
    } catch (e, stackTrace) {
      logger.e('Fehler beim Löschen eines Artikels', error: e, stackTrace: stackTrace);
      throw DatabaseException('Artikel konnte nicht gelöscht werden: $e');
    }
  }

  Future<int> updateBildPfad(int artikelId, String bildPfad) async {
    try {
      final db = await database;
      return await db.update(
        'artikel',
        {'bildPfad': bildPfad},
        where: 'id = ?',
        whereArgs: [artikelId],
      );
    } catch (e, stackTrace) {
      logger.e('Fehler beim Aktualisieren des Bildpfads', error: e, stackTrace: stackTrace);
      throw DatabaseException('Bildpfad konnte nicht aktualisiert werden: $e');
    }
  }

  Future<int> updateRemoteBildPfad(int artikelId, String remotePfad) async {
    try {
      final db = await database;
      return await db.update(
        'artikel',
        {'remoteBildPfad': remotePfad},
        where: 'id = ?',
        whereArgs: [artikelId],
      );
    } catch (e, stackTrace) {
      logger.e('Fehler beim Aktualisieren des Remote-Bildpfads', error: e, stackTrace: stackTrace);
      throw DatabaseException('Remote-Bildpfad konnte nicht aktualisiert werden: $e');
    }
  }

  // Findet alle Artikel mit lokalen Bildern, die noch nicht zu Nextcloud synchronisiert wurden
  Future<List<Artikel>> getUnsyncedArtikel() async {
    try {
      final db = await database;
      final maps = await db.query(
        'artikel',
        where: 'bildPfad IS NOT NULL AND bildPfad != "" AND (remoteBildPfad IS NULL OR remoteBildPfad = "")',
        orderBy: 'id DESC',
      );
      return maps.map((map) => Artikel.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.e('Fehler beim Laden unsynchronisierter Artikel', error: e, stackTrace: stackTrace);
      throw DatabaseException('Unsynchronisierte Artikel konnten nicht geladen werden: $e');
    }
  }

  Future<void> deleteAlleArtikel() async {
    try {
      final db = await database;
      await db.delete('artikel');
      final count = (await db.rawQuery('SELECT COUNT(*) FROM artikel')).first.values.first as int;
      logger.i("Artikel gelöscht, verbleibende Einträge: $count");
    } catch (e, stackTrace) {
      logger.e('Fehler beim Löschen aller Artikel', error: e, stackTrace: stackTrace);
      throw DatabaseException('Alle Artikel konnten nicht gelöscht werden: $e');
    }
  }

  Future<void> insertArtikelList(List<Artikel> artikelList) async {
    try {
      final db = await database;
      int count = 0;
      for (final artikel in artikelList) {
        await db.insert(
          'artikel',
          artikel.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace, // Überschreibt ggf. vorhandene IDs
        );
        count++;
        logger.d("Artikel eingefügt/überschrieben: ID=${artikel.id}, Name=${artikel.name}");
      }
      logger.i("$count Artikel aus Backup wiederhergestellt.");
    } catch (e, stackTrace) {
      logger.e('Fehler beim Einfügen der Artikelliste', error: e, stackTrace: stackTrace);
      throw DatabaseException('Artikelliste konnte nicht eingefügt werden: $e');
    }
  }

  /// Setzt den Remote-Bildpfad für einen Artikel anhand der UUID
  Future<void> setRemoteBildPfadByUuid(String uuid, String remoteBildPfad) async {
    try {
      final db = await database;
      await db.update(
        'artikel',
        {
          'remoteBildPfad': remoteBildPfad,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
      logger.d('remoteBildPfad gesetzt für UUID=$uuid: $remoteBildPfad');
    } catch (e, stackTrace) {
      logger.e('Fehler beim Setzen von remoteBildPfad', error: e, stackTrace: stackTrace);
      throw DatabaseException('remoteBildPfad konnte nicht gesetzt werden: $e');
    }
  }

  // ===== SYNC-SPEZIFISCHE METHODEN =====

  /// Gibt alle lokalen Änderungen seit dem letzten Sync zurück
  Future<List<Artikel>> getPendingChanges() async {
    try {
      final db = await database;
      final lastSyncTime = await _getLastSyncTime();
      final maps = await db.query(
        'artikel',
        where: 'updated_at > ?',
        whereArgs: [lastSyncTime],
        orderBy: 'updated_at ASC'
      );
      return maps.map((map) => Artikel.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.e('Fehler beim Laden ausstehender Änderungen', error: e, stackTrace: stackTrace);
      throw DatabaseException('Ausstehende Änderungen konnten nicht geladen werden: $e');
    }
  }

  /// Markiert einen Artikel als synchronisiert mit neuem ETag
  Future<void> markSynced(String uuid, String etag) async {
    try {
      final db = await database;
      await db.update(
        'artikel',
        {'etag': etag},
        where: 'uuid = ?',
        whereArgs: [uuid]
      );
    } catch (e, stackTrace) {
      logger.e('Fehler beim Markieren als synchronisiert', error: e, stackTrace: stackTrace);
      throw DatabaseException('Artikel konnte nicht als synchronisiert markiert werden: $e');
    }
  }

  /// Setzt den letzten Sync-Zeitstempel
  Future<void> setLastSyncTime() async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert(
        'sync_meta',
        {
          'key': 'last_sync',
          'value': now.toString(),
          'updated_at': now
        },
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    } catch (e, stackTrace) {
      logger.e('Fehler beim Setzen der Sync-Zeit', error: e, stackTrace: stackTrace);
      throw DatabaseException('Sync-Zeit konnte nicht gesetzt werden: $e');
    }
  }

  /// Holt den letzten Sync-Zeitstempel
  Future<int> _getLastSyncTime() async {
    try {
      final db = await database;
      final result = await db.query(
        'sync_meta',
        where: 'key = ?',
        whereArgs: ['last_sync'],
        limit: 1
      );
      if (result.isEmpty) return 0;
      return int.tryParse(result.first['value'] as String) ?? 0;
    } catch (e) {
      logger.w('Konnte letzten Sync-Zeitstempel nicht laden: $e');
      return 0;
    }
  }

  /// Findet Artikel anhand des Remote-Pfades
  Future<Artikel?> getArtikelByRemotePath(String remotePath) async {
    try {
      final db = await database;
      final maps = await db.query(
        'artikel',
        where: 'remote_path = ?',
        whereArgs: [remotePath],
        limit: 1
      );
      return maps.isNotEmpty ? Artikel.fromMap(maps.first) : null;
    } catch (e, stackTrace) {
      logger.e('Fehler beim Suchen nach Remote-Pfad', error: e, stackTrace: stackTrace);
      throw DatabaseException('Artikel mit Remote-Pfad konnte nicht gefunden werden: $e');
    }
  }

  /// Findet Artikel anhand der UUID
  Future<Artikel?> getArtikelByUUID(String uuid) async {
    try {
      final db = await database;
      final maps = await db.query(
        'artikel',
        where: 'uuid = ?',
        whereArgs: [uuid],
        limit: 1
      );
      return maps.isNotEmpty ? Artikel.fromMap(maps.first) : null;
    } catch (e, stackTrace) {
      logger.e('Fehler beim Suchen nach UUID', error: e, stackTrace: stackTrace);
      throw DatabaseException('Artikel mit UUID konnte nicht gefunden werden: $e');
    }
  }

  /// Fügt oder aktualisiert einen Artikel aus Remote-Daten
  Future<void> upsertFromRemote(String remotePath, String etag, String jsonBody) async {
    try {
      final artikelData = json.decode(jsonBody) as Map<String, dynamic>;
      
      // Remote-Metadaten hinzufügen
      artikelData['etag'] = etag;
      artikelData['remote_path'] = remotePath;
      
      final artikel = Artikel.fromMap(artikelData);
      
      final db = await database;
      await db.insert(
        'artikel',
        artikel.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace
      );
      
      logger.d('Artikel aus Remote eingefügt/aktualisiert: UUID=${artikel.uuid}');
    } catch (e, stackTrace) {
      logger.e('Fehler beim Einfügen aus Remote', error: e, stackTrace: stackTrace);
      throw DatabaseException('Remote-Artikel konnte nicht eingefügt werden: $e');
    }
  }

  /// Sucht Artikel mit FTS (falls verfügbar) oder LIKE-Suche
  Future<List<Artikel>> searchArtikel(String query, {int limit = 100}) async {
    try {
      final db = await database;
      List<Map<String, dynamic>> maps;
      
      if (kIsWeb) {
        // Fallback für Web: LIKE-Suche
        maps = await db.query(
          'artikel',
          where: 'deleted = 0 AND (name LIKE ? OR beschreibung LIKE ?)',
          whereArgs: ['%$query%', '%$query%'],
          orderBy: 'name',
          limit: limit
        );
      } else {
        // Versuche FTS5-Suche für Desktop/Mobile
        try {
          maps = await db.rawQuery('''
            SELECT a.* FROM artikel a
            JOIN artikel_fts f ON a.rowid = f.rowid
            WHERE artikel_fts MATCH ? AND a.deleted = 0
            ORDER BY a.name
            LIMIT ?
          ''', ['$query*', limit]);
        } catch (e) {
          // Fallback auf LIKE-Suche wenn FTS nicht verfügbar
          logger.w('FTS nicht verfügbar, verwende LIKE-Suche: $e');
          maps = await db.query(
            'artikel',
            where: 'deleted = 0 AND (name LIKE ? OR beschreibung LIKE ?)',
            whereArgs: ['%$query%', '%$query%'],
            orderBy: 'name',
            limit: limit
          );
        }
      }
      
      return maps.map((map) => Artikel.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.e('Fehler bei der Suche', error: e, stackTrace: stackTrace);
      throw DatabaseException('Suche konnte nicht durchgeführt werden: $e');
    }
  }

  /// Schließt die Datenbankverbindung explizit
  /// Sollte beim Beenden der App aufgerufen werden
  Future<void> closeDatabase() async {
    try {
      if (_db != null) {
        await _db!.close();
        _db = null;
        logger.d('Datenbankverbindung geschlossen');
      }
    } catch (e, stackTrace) {
      logger.e('Fehler beim Schließen der Datenbankverbindung', error: e, stackTrace: stackTrace);
      throw DatabaseException('Datenbank konnte nicht geschlossen werden: $e');
    }
  }

  Future<void> deleteOldDatabase() async {
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, 'artikel.db');
  await deleteDatabase(path);
  _db = null; // Datenbank-Instanz zurücksetzen
  logger.i('Datenbank gelöscht: $path');
  }

  /// Setzt die SQLite-Sequenz beim Erstellen der DB basierend auf den Einstellungen
  Future<void> _setInitialSequenceFromSettings(Database db) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startNummer = prefs.getInt('artikel_start_nummer') ?? 1000;
      
      // Setze Startwert für IDs (minus 1, da AUTOINCREMENT beim nächsten Insert incrementiert)
      await db.insert('sqlite_sequence', {'name': 'artikel', 'seq': startNummer - 1});
      logger.i("🔢 Startwert für Artikel-IDs auf $startNummer gesetzt");
    } catch (e) {
      logger.w('Fehler beim Setzen des Startwerts, verwende Fallback: $e');
      await db.insert('sqlite_sequence', {'name': 'artikel', 'seq': 999});
    }
  }

  /// Prüft, ob die Datenbank bereits Artikel enthält
  Future<bool> isDatabaseEmpty() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM artikel');
      final count = result.isNotEmpty ? result.first['count'] as int : 0;
      return count == 0;
    } catch (e) {
      logger.e('Fehler beim Prüfen der Datenbank: $e');
      return false;
    }
  }

  /// Ermittelt die nächste Artikelnummer basierend auf den Einstellungen
  Future<int> getNextArtikelNummer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startNummer = prefs.getInt('artikel_start_nummer') ?? 1000;
      
      // Prüfe die höchste vorhandene ID in der DB
      final db = await database;
      final result = await db.rawQuery('SELECT MAX(id) as maxId FROM artikel');
      final maxId = result.isNotEmpty && result.first['maxId'] != null 
          ? result.first['maxId'] as int 
          : 0;
      
      // Verwende das Maximum aus Einstellung und vorhandener höchster ID + 1
      return max(startNummer, maxId + 1);
    } catch (e) {
      logger.e('Fehler beim Ermitteln der nächsten Artikelnummer: $e');
      return 1000; // Fallback
    }
  }
}

/// Custom Exception für Datenbank-Fehler
class DatabaseException implements Exception {
  final String message;
  const DatabaseException(this.message);
  
  @override
  String toString() => 'DatabaseException: $message';
}
