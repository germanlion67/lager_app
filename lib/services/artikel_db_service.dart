//lib/services/artikel_db_service.dart

//Diese Datei stellt die zentrale Datenbanklogik bereit.
//Sie kann direkt mit dem Artikel-Modell verwendet werden 
//und ist bereit für Erweiterungen wie Lagerbestandswarnungen oder Synchronisation.

//Zukunftsicher für erweiterung von Spalten durch "onUpgrade"
//bei Schemaerweiterung = Versionsnummer erhöhen, neue felder in "Artikel" und "CREATE TABLE" in "onUpgrade" 
//prüfen "if (oldVersion < x)" -> neue Spalten ergänzen


import 'package:flutter/foundation.dart' show kIsWeb;
//import 'package:sqflite/sqflite.dart'; // Für Mobile (Android/iOS)
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Für Desktop
import 'package:path/path.dart';
import 'package:logger/logger.dart';
import 'dart:io' show Platform;

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
            version: 2,
            onCreate: (db, version) async {
              logger.i("🛠️ Erstelle Tabelle 'artikel' (Version $version)");
              await db.execute(_createTableSql);
              // ⬇️ Startwert für IDs auf 1000 setzen
              await db.insert('sqlite_sequence', {'name': 'artikel', 'seq': 999});
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
          version: 2,
          onCreate: (db, version) async {
            logger.i("🛠️ Erstelle Tabelle 'artikel' (Version $version)");
            await db.execute(_createTableSql);
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
      erstelltAm TEXT,
      aktualisiertAm TEXT,
      remoteBildPfad TEXT
    )
  ''';

  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    logger.w("🔄 Upgrade DB von Version $oldVersion → $newVersion");

    if (oldVersion < 2) {
      await db.execute("ALTER TABLE artikel ADD COLUMN kategorie TEXT");
      logger.i("➕ Spalte 'kategorie' hinzugefügt");
    }

    // Beispiel für zukünftige Erweiterung:
    // if (oldVersion < 3) {
    //   await db.execute("ALTER TABLE artikel ADD COLUMN barcode TEXT");
    //   logger.i("➕ Spalte 'barcode' hinzugefügt");
    // }
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
}

/// Custom Exception für Datenbank-Fehler
class DatabaseException implements Exception {
  final String message;
  const DatabaseException(this.message);
  
  @override
  String toString() => 'DatabaseException: $message';
}
