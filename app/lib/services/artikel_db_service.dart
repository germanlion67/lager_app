//lib/services/artikel_db_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'database_provider.dart';
import 'dart:developer' as developer;

class ArtikelDbService {
  static ArtikelDbService? _instance;
  DatabaseProvider? _provider;

  factory ArtikelDbService() => _instance ??= ArtikelDbService._internal();

  ArtikelDbService._internal();

  Future<DatabaseProvider> get database async {
    if (_provider != null) return _provider!;
    // DB-Name kann angepasst werden
    _provider = await DatabaseProvider.open('artikel.db');
    developer.log('ArtikelDbService: provider web=${_provider!.web} file=${_provider!.filePath}', name: 'db');
    return _provider!;
  }

  Future<int> debugCountArtikel() async {
    final dbp = await database;
    if (dbp.web) {
      final rows = await dbp.query('artikel');
      return rows.length;
    } else {
      final rows = await dbp.rawQuery('SELECT COUNT(*) as c FROM artikel');
      if (rows.isNotEmpty) return (rows.first['c'] as int?) ?? 0;
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> debugDumpArtikel({int limit = 50}) async {
    final dbp = await database;
    if (dbp.web) {
      return await dbp.query('artikel', ); // web adapter returns all if no filter
    } else {
      return await dbp.rawQuery('SELECT * FROM artikel LIMIT ?', [limit]);
    }
  }

  Future<void> debugPrintArtikel() async {
    final count = await debugCountArtikel();
    developer.log('ARTIKEL count=$count', name: 'db');
    final rows = await debugDumpArtikel(limit: 100);
    for (var r in rows) {
      developer.log('A: $r', name: 'db');
    }
  }

  Future<void> close() async {
    await _provider?.close();
    _provider = null;
  }
}