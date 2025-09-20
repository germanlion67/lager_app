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
    final db = await database;

    // Tabelle löschen
    await db.execute("DROP TABLE IF EXISTS artikel");

    // Neu erstellen
    await db.execute(_createTableSql);

    // Startwert für ID setzen
    await db.insert('sqlite_sequence', {'name': 'artikel', 'seq': startId - 1});

    logger.w("🗑️ Datenbank zurückgesetzt. Nächste ID startet bei $startId");
  }


  Future<int> insertArtikel(Artikel artikel) async {
    final db = await database;
    return await db.insert('artikel', artikel.toMap());
  }

  Future<List<Artikel>> getAlleArtikel() async {
    final db = await database;
    final maps = await db.query('artikel', orderBy: 'id DESC');
    return maps.map((map) => Artikel.fromMap(map)).toList();
  }

  Future<int> updateArtikel(Artikel artikel) async {
    final db = await database;
    return await db.update(
      'artikel',
      artikel.toMap(),
      where: 'id = ?',
      whereArgs: [artikel.id],
    );
  }

  Future<int> deleteArtikel(int id) async {
    final db = await database;
    return await db.delete('artikel', where: 'id = ?', whereArgs: [id]);
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

  // Findet alle Artikel mit lokalen Bildern, die noch nicht zu Nextcloud synchronisiert wurden
  Future<List<Artikel>> getUnsyncedArtikel() async {
    final db = await database;
    final maps = await db.query(
      'artikel',
      where: 'bildPfad IS NOT NULL AND bildPfad != "" AND (remoteBildPfad IS NULL OR remoteBildPfad = "")',
      orderBy: 'id DESC',
    );
    return maps.map((map) => Artikel.fromMap(map)).toList();
  }

  Future<void> deleteAlleArtikel() async {
    final db = await database;
    await db.delete('artikel');
    final count = (await db.rawQuery('SELECT COUNT(*) FROM artikel')).first.values.first as int;
    logger.i("Artikel gelöscht, verbleibende Einträge: $count");
  }

  Future<void> insertArtikelList(List<Artikel> artikelList) async {
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
  }
}
