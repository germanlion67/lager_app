// lib/services/artikel_db_service.dart
//
// Lokaler SQLite-Service für Mobile & Desktop.
// Wird im Web NICHT verwendet – dort geht alles direkt über PocketBase.
//
// ⚠️ Verwendet Conditional Import für dart:io (Platform-Erkennung),
// damit die Datei im Web kompiliert, auch wenn sie dort nie aufgerufen wird.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/artikel_model.dart';

// Conditional Import: dart:io nur auf Mobile/Desktop
import 'artikel_db_platform_io.dart'
    if (dart.library.html) 'artikel_db_platform_stub.dart' as platform;

class ArtikelDbService {
  static final ArtikelDbService _instance = ArtikelDbService._internal();
  factory ArtikelDbService() => _instance;
  ArtikelDbService._internal();

  final logger = Logger();
  Database? _db;

  /// Gibt die Datenbank-Instanz zurück.
  /// Wirft einen Fehler im Web – dort PocketBase direkt nutzen.
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
      logger.e('❌ Fehler beim Initialisieren der DB', error: e, stackTrace: stack);
      rethrow;
    }
  }

  // ==================== SCHEMA ====================

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

  Future<void> _onCreate(Database db, int version) async {
    logger.i("🛠️ Erstelle Tabelle 'artikel' (Version $version)");
    await db.execute(_createTableSql);
    await db.execute(_createSyncMetaTableSql);
    await _createIndices(db);
    await _setInitialSequenceFromSettings(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    logger.w("🔄 Upgrade DB von Version $oldVersion → $newVersion");

    if (oldVersion < 2) {
      await db.execute("ALTER TABLE artikel ADD COLUMN kategorie TEXT");
    }

    if (oldVersion < 3) {
      await db.execute("ALTER TABLE artikel ADD COLUMN uuid TEXT");
      await db.execute("ALTER TABLE artikel ADD COLUMN updated_at INTEGER DEFAULT 0");
      await db.execute("ALTER TABLE artikel ADD COLUMN deleted INTEGER DEFAULT 0");
      await db.execute("ALTER TABLE artikel ADD COLUMN etag TEXT");
      await db.execute("ALTER TABLE artikel ADD COLUMN remote_path TEXT");
      await db.execute("ALTER TABLE artikel ADD COLUMN device_id TEXT");
      await db.execute("ALTER TABLE artikel ADD COLUMN thumbnailPfad TEXT");
      await db.execute("ALTER TABLE artikel ADD COLUMN thumbnailEtag TEXT");

      await _generateUUIDsForExistingRecords(db);
      await db.execute(_createSyncMetaTableSql);
      await _createIndices(db);
    }
  }

  Future<void> _createIndices(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_artikel_updated_at ON artikel(updated_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_artikel_uuid ON artikel(uuid)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_artikel_deleted ON artikel(deleted)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_artikel_name ON artikel(name)');
  }

  Future<void> _setInitialSequenceFromSettings(Database db) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startNummer = prefs.getInt('artikel_start_nummer') ?? 1000;
      await db.insert('sqlite_sequence', {'name': 'artikel', 'seq': startNummer - 1});
      logger.i("🔢 Startwert für Artikel-IDs auf $startNummer gesetzt");
    } catch (e) {
      logger.w('Fehler beim Setzen des Startwerts: $e');
      await db.insert('sqlite_sequence', {'name': 'artikel', 'seq': 999});
    }
  }

  Future<void> _generateUUIDsForExistingRecords(Database db) async {
    final existing = await db.query('artikel', where: 'uuid IS NULL OR uuid = ""');
    for (final article in existing) {
      final uuid = _generateUUID();
      await db.update(
        'artikel',
        {'uuid': uuid, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [article['id']],
      );
    }
  }

  // ==================== CRUD ====================

  Future<int> insertArtikel(Artikel artikel) async {
    final db = await database;
    final data = artikel.toMap();
    data['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    return await db.insert('artikel', data);
  }

  Future<List<Artikel>> getAlleArtikel() async {
    final db = await database;
    final maps = await db.query('artikel',
      where: 'deleted = ?',
      whereArgs: [0],
      orderBy: 'id DESC',
    );
    return maps.map((m) => Artikel.fromMap(m)).toList();
  }

  Future<void> updateArtikel(Artikel artikel) async {
    final db = await database;
    final data = Map<String, dynamic>.from(artikel.toMap());
    data['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await db.update('artikel', data, where: 'id = ?', whereArgs: [artikel.id]);
  }

  Future<void> deleteArtikel(Artikel artikel) async {
    final db = await database;
    await db.update(
      'artikel',
      {'deleted': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [artikel.id],
    );
  }

  // ==================== BILD ====================

  Future<int> updateBildPfad(int artikelId, String bildPfad) async {
    final db = await database;
    return await db.update(
      'artikel',
      {'bildPfad': bildPfad, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [artikelId],
    );
  }

  Future<int> updateRemoteBildPfad(int artikelId, String remotePfad) async {
    final db = await database;
    return await db.update(
      'artikel',
      {'remoteBildPfad': remotePfad},
      where: 'id = ?',
      whereArgs: [artikelId],
    );
  }

  Future<void> setBildPfadByUuid(String uuid, String bildPfad) async {
    final db = await database;
    await db.update('artikel', {'bildPfad': bildPfad},
      where: 'uuid = ?', whereArgs: [uuid],
    );
  }

  Future<void> setThumbnailPfadByUuid(String uuid, String thumbnailPfad) async {
    final db = await database;
    await db.update('artikel', {'thumbnailPfad': thumbnailPfad},
      where: 'uuid = ?', whereArgs: [uuid],
    );
  }

  Future<void> setThumbnailEtagByUuid(String uuid, String thumbnailEtag) async {
    final db = await database;
    await db.update('artikel', {'thumbnailEtag': thumbnailEtag},
      where: 'uuid = ?', whereArgs: [uuid],
    );
  }

  Future<void> setRemoteBildPfadByUuid(String uuid, String remoteBildPfad) async {
    final db = await database;
    await db.update(
      'artikel',
      {'remoteBildPfad': remoteBildPfad, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  // ==================== LOOKUP ====================

  Future<Artikel?> getArtikelByUUID(String uuid) async {
    final db = await database;
    final maps = await db.query('artikel',
      where: 'uuid = ?', whereArgs: [uuid], limit: 1,
    );
    return maps.isNotEmpty ? Artikel.fromMap(maps.first) : null;
  }

  Future<Artikel?> getArtikelByRemotePath(String remotePath) async {
    final db = await database;
    final maps = await db.query('artikel',
      where: 'remote_path = ?', whereArgs: [remotePath], limit: 1,
    );
    return maps.isNotEmpty ? Artikel.fromMap(maps.first) : null;
  }

  Future<List<Artikel>> getUnsyncedArtikel() async {
    final db = await database;
    final maps = await db.query('artikel',
      where: 'bildPfad IS NOT NULL AND bildPfad != "" AND (remoteBildPfad IS NULL OR remoteBildPfad = "")',
      orderBy: 'id DESC',
    );
    return maps.map((m) => Artikel.fromMap(m)).toList();
  }

  // ==================== SYNC ====================

  Future<List<Artikel>> getPendingChanges() async {
    final db = await database;
    final lastSync = await _getLastSyncTime();
    final maps = await db.query('artikel',
      where: 'updated_at > ?',
      whereArgs: [lastSync],
      orderBy: 'updated_at ASC',
    );
    return maps.map((m) => Artikel.fromMap(m)).toList();
  }

  Future<void> markSynced(String uuid, String etag) async {
    final db = await database;
    await db.update('artikel', {'etag': etag},
      where: 'uuid = ?', whereArgs: [uuid],
    );
  }

  Future<void> upsertFromRemote(String remotePath, String etag, String jsonBody) async {
    final db = await database;
    final artikelData = json.decode(jsonBody) as Map<String, dynamic>;
    artikelData['etag'] = etag;
    artikelData['remote_path'] = remotePath;

    final artikel = Artikel.fromMap(artikelData);
    final existing = await db.query('artikel',
      where: 'uuid = ?', whereArgs: [artikel.uuid], limit: 1,
    );

    if (existing.isNotEmpty) {
      await db.update('artikel', artikel.toMap(),
        where: 'uuid = ?', whereArgs: [artikel.uuid],
      );
    } else {
      await db.insert('artikel', artikel.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> setLastSyncTime() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('sync_meta', {
      'key': 'last_sync',
      'value': now.toString(),
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> _getLastSyncTime() async {
    try {
      final db = await database;
      final result = await db.query('sync_meta',
        where: 'key = ?', whereArgs: ['last_sync'], limit: 1,
      );
      if (result.isEmpty) return 0;
      return int.tryParse(result.first['value'] as String) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ==================== SEARCH ====================

  Future<List<Artikel>> searchArtikel(String query, {int limit = 100}) async {
    final db = await database;
    final maps = await db.query('artikel',
      where: 'deleted = 0 AND (name LIKE ? OR beschreibung LIKE ?)',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name',
      limit: limit,
    );
    return maps.map((m) => Artikel.fromMap(m)).toList();
  }

  // ==================== ADMIN ====================

  Future<void> resetDatabase({int startId = 1000}) async {
    final db = await database;
    await db.execute("DROP TABLE IF EXISTS artikel");
    await db.execute(_createTableSql);
    await db.insert('sqlite_sequence', {'name': 'artikel', 'seq': startId - 1});
    logger.w("🗑️ Datenbank zurückgesetzt. Nächste ID startet bei $startId");
  }

  Future<void> deleteAlleArtikel() async {
    final db = await database;
    await db.delete('artikel');
  }

  Future<void> insertArtikelList(List<Artikel> artikelList) async {
    final db = await database;
    for (final artikel in artikelList) {
      await db.insert('artikel', artikel.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    logger.i("${artikelList.length} Artikel aus Backup wiederhergestellt.");
  }

  Future<bool> isDatabaseEmpty() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM artikel');
    return (result.first['count'] as int) == 0;
  }

  Future<int> getNextArtikelNummer() async {
    final prefs = await SharedPreferences.getInstance();
    final startNummer = prefs.getInt('artikel_start_nummer') ?? 1000;
    final db = await database;
    final result = await db.rawQuery('SELECT MAX(id) as maxId FROM artikel');
    final maxId = result.first['maxId'] as int? ?? 0;
    return max(startNummer, maxId + 1);
  }

  Future<void> closeDatabase() async {
    await _db?.close();
    _db = null;
  }

  // ==================== HELPER ====================

  static String _generateUUID() {
    return '${_randomHex(8)}-${_randomHex(4)}-${_randomHex(4)}-${_randomHex(4)}-${_randomHex(12)}';
  }

  static String _randomHex(int length) {
    final random = Random();
    const chars = '0123456789abcdef';
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(16))),
    );
  }

  // ==================== DEBUG ====================

  Future<int> debugCountArtikel() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) as c FROM artikel');
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> debugDumpArtikel({int limit = 50}) async {
    final db = await database;
    return await db.rawQuery('SELECT * FROM artikel LIMIT ?', [limit]);
  }
}
