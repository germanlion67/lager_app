// lib/services/tag_service.dart

// 🏷️ Funktionalität:
// Tags werden in einer eigenen Tabelle gespeichert
// Artikel können mehrere Tags erhalten (n:n-Beziehung)
// Tags können hinzugefügt, abgerufen und zugewiesen werden

import 'dart:async';
import 'artikel_db_service.dart';
import 'package:sqflite/sqflite.dart';

class TagService {
  static final TagService _instance = TagService._internal();
  factory TagService() => _instance;
  TagService._internal();

  Future<Database> _dbProvider() async {
    return await ArtikelDbService().database;
  }

  // Fix: createTag entfernt — doppelte Funktionalität von addTag
  // Aufrufer sollen addTag(name) verwenden

  Future<int> addTag(String name) async {
    // Fix: Leerzeichen trimmen und Leerstring abfangen
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Tag-Name darf nicht leer sein.');
    }

    final dbp = await _dbProvider();

    // Fix: Duplikat-Prüfung — keinen zweiten Tag mit gleichem Namen anlegen
    final existing = await dbp.query(
      'tags',
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [trimmed],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return existing.first['id'] as int;
    }

    return await dbp.insert('tags', {'name': trimmed});
  }

  Future<List<Map<String, dynamic>>> listTags() async {
    final dbp = await _dbProvider();
    // Fix: Sortierung nach Name für konsistente Reihenfolge
    return await dbp.query('tags', orderBy: 'name ASC');
  }

  Future<int> updateTag(int id, Map<String, dynamic> values) async {
    // Fix: Name trimmen und Leerstring abfangen
    if (values.containsKey('name')) {
      final trimmed = (values['name'] as String?)?.trim() ?? '';
      if (trimmed.isEmpty) {
        throw ArgumentError('Tag-Name darf nicht leer sein.');
      }
      values = {...values, 'name': trimmed};
    }

    final dbp = await _dbProvider();
    return await dbp.update(
      'tags',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTag(int id) async {
    final dbp = await _dbProvider();

    // Fix: Cascade — verwaiste artikel_tags-Einträge mitlöschen
    await dbp.delete(
      'artikel_tags',
      where: 'tag_id = ?',
      whereArgs: [id],
    );

    return await dbp.delete(
      'tags',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<String>> getTagsForArtikel(int artikelId) async {
    final dbp = await _dbProvider();

    // Fix: JOIN statt N+1 Queries (eine Query statt einer pro Tag)
    final rows = await dbp.rawQuery('''
      SELECT t.name
      FROM tags t
      INNER JOIN artikel_tags at ON at.tag_id = t.id
      WHERE at.artikel_id = ?
      ORDER BY t.name ASC
    ''', [artikelId],);

    return rows
        .map((r) => r['name'] as String?)
        .whereType<String>()
        .toList();
  }

  Future<void> assignTagToArtikel(int artikelId, int tagId) async {
    final dbp = await _dbProvider();

    // Fix: Doppelte Zuweisung verhindern via conflictAlgorithm
    await dbp.insert(
      'artikel_tags',
      {
        'artikel_id': artikelId,
        'tag_id': tagId,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // Fix: Neue Hilfsmethode — Tag von Artikel entfernen
  Future<void> removeTagFromArtikel(int artikelId, int tagId) async {
    final dbp = await _dbProvider();
    await dbp.delete(
      'artikel_tags',
      where: 'artikel_id = ? AND tag_id = ?',
      whereArgs: [artikelId, tagId],
    );
  }

  // Fix: Neue Hilfsmethode — alle Tags eines Artikels als Map (id + name)
  Future<List<Map<String, dynamic>>> getTagMapsForArtikel(int artikelId) async {
    final dbp = await _dbProvider();
    return await dbp.rawQuery('''
      SELECT t.id, t.name
      FROM tags t
      INNER JOIN artikel_tags at ON at.tag_id = t.id
      WHERE at.artikel_id = ?
      ORDER BY t.name ASC
    ''', [artikelId],);
  }
}