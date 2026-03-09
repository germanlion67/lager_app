//lib/services/tag_service.dart

//🏷️ Funktionalität:
//Tags werden in einer eigenen Tabelle gespeichert
//Artikel können mehrere Tags erhalten (n =n-Beziehung)
//Du kannst Tags hinzufügen, abrufen und zuweisen

import 'dart:async';
import 'artikel_db_service.dart';
import 'database_provider.dart';

class TagService {
  static final TagService _instance = TagService._internal();
  factory TagService() => _instance;
  TagService._internal();

  Future<DatabaseProvider> _dbProvider() async {
    return await ArtikelDbService().database;
  }

  Future<int> createTag(Map<String, dynamic> values) async {
    final dbp = await _dbProvider();
    return await dbp.insert('tags', values);
  }

  Future<int> addTag(String name) async {
    final dbp = await _dbProvider();
    return await dbp.insert('tags', {'name': name});
  }

  Future<List<Map<String, dynamic>>> listTags() async {
    final dbp = await _dbProvider();
    return await dbp.query('tags');
  }

  Future<int> updateTag(int id, Map<String, dynamic> values) async {
    final dbp = await _dbProvider();
    return await dbp.update('tags', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTag(int id) async {
    final dbp = await _dbProvider();
    return await dbp.delete('tags', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<String>> getTagsForArtikel(int artikelId) async {
    final dbp = await _dbProvider();
    final linkRows = await dbp.query('artikel_tags', where: 'artikel_id = ?', whereArgs: [artikelId]);
    final names = <String>[];
    for (final lr in linkRows) {
      final tagId = lr['tag_id'] ?? lr['_id'] ?? lr['id'];
      if (tagId == null) continue;
      final tagRows = await dbp.query('tags', where: 'id = ?', whereArgs: [tagId]);
      if (tagRows.isNotEmpty) {
        final name = tagRows.first['name'] as String?;
        if (name != null) names.add(name);
      }
    }
    return names;
  }

  Future<void> assignTagToArtikel(int artikelId, int tagId) async {
    final dbp = await _dbProvider();
    await dbp.insert('artikel_tags', {
      'artikel_id': artikelId,
      'tag_id': tagId,
    });
  }
}