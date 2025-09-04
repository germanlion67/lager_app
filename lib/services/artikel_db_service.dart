//lib/services/artikel_db_service.dart

//Diese Datei stellt die zentrale Datenbanklogik bereit.
//Sie kann direkt mit dem Artikel-Modell verwendet werden 
//und ist bereit für Erweiterungen wie Lagerbestandswarnungen oder Synchronisation.


import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart';
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
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'artikel.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
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
        ''');
      },
    );
  }

  Future<int> insertArtikel(Artikel artikel) async {
    try {
      final db = await database;
      return await db.insert('artikel', artikel.toMap());
    } catch (e) {
      logger.e('Fehler in insertArtikel:', e);
      rethrow;
    }
  }

  Future<List<Artikel>> getAlleArtikel() async {
    try {
      final db = await database;
      final maps = await db.query('artikel');
      return maps.map((map) => Artikel.fromMap(map)).toList();
    } catch (e) {
      logger.e('Fehler in getAlleArtikel:', e);
      rethrow;
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
    } catch (e) {
      logger.e('Fehler in updateArtikel:', e);
      rethrow;
    }
  }

  Future<int> deleteArtikel(int id) async {
    try {
      final db = await database;
      return await db.delete('artikel', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      logger.e('Fehler in deleteArtikel:', e);
      rethrow;
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
    } catch (e) {
      logger.e('Fehler in updateRemoteBildPfad:', e);
      rethrow;
    }
  }
}

// Diese Methode aktualisiert den remoteBildPfad eines Artikels in der Datenbank.
// Sie nimmt die Artikel-ID und den neuen Pfad als Parameter entgegen.
// Die Methode gibt die Anzahl der aktualisierten Datensätze zurück.
// Dies ist nützlich, wenn du den Pfad eines auf Nextcloud hochgeladenen Bildes speichern möchtest.
// Du kannst diese Methode in deinem Upload-Workflow aufrufen,
// nachdem das Bild erfolgreich hochgeladen wurde und du den neuen Pfad erhalten hast.
// Beispielaufruf:
// await ArtikelDbService().updateRemoteBildPfad(artikelId, neuerRemotePfad);
