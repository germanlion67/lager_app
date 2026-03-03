//lib/services/tag_service.dart

//🏷️ Funktionalität:
//Tags werden in einer eigenen Tabelle gespeichert
//Artikel können mehrere Tags erhalten (n =n-Beziehung)
//Du kannst Tags hinzufügen, abrufen und zuweisen


import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class TagService {
  static final TagService _instance = TagService._internal();
  factory TagService() => _instance;
  TagService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, 'artikel.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE artikel_tags (
            artikel_id INTEGER,
            tag_id INTEGER,
            FOREIGN KEY (artikel_id) REFERENCES artikel(id),
            FOREIGN KEY (tag_id) REFERENCES tags(id)
          )
        ''');
      },
    );
  }

  Future<int> addTag(String name) async {
    final db = await database;
    return await db.insert('tags', {'name': name});
  }

  Future<List<String>> getTagsForArtikel(int artikelId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT tags.name FROM tags
      JOIN artikel_tags ON tags.id = artikel_tags.tag_id
      WHERE artikel_tags.artikel_id = ?
    ''', [artikelId]);

    return result.map((row) => row['name'] as String).toList();
  }

  Future<void> assignTagToArtikel(int artikelId, int tagId) async {
    final db = await database;
    await db.insert('artikel_tags', {
      'artikel_id': artikelId,
      'tag_id': tagId,
    });
  }
}
