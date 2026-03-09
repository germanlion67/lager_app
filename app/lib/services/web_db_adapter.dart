// .../lib/services/web_db_adapter.dart

import 'package:sembast_web/sembast_web.dart';
import 'dart:async';

class WebDbAdapter {
  static Database? _db;
  static final Map<String, StoreRef<int, Map<String, dynamic>>> _stores = {};

  static Future<Database> open(String dbName) async {
    if (_db != null) return _db!;
    final dbFactory = databaseFactoryWeb;
    _db = await dbFactory.openDatabase(dbName);
    return _db!;
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
    _stores.clear();
  }

  static StoreRef<int, Map<String, dynamic>> _storeFor(String table) {
    return _stores.putIfAbsent(table, () => intMapStoreFactory.store(table));
  }

  static Future<int> insert(String table, Map<String, dynamic> values) async {
    final db = await open('app_db');
    final store = _storeFor(table);
    final key = await store.add(db, Map<String, dynamic>.from(values));
    return key;
  }

  static Future<int> update(String table, Map<String, dynamic> values,
      {Finder? finder}) async {
    final db = await open('app_db');
    final store = _storeFor(table);
    final records = await store.update(db, Map<String, dynamic>.from(values),
        finder: finder);
    return records; // number of updated records
  }

  static Future<int> delete(String table, {Finder? finder}) async {
    final db = await open('app_db');
    final store = _storeFor(table);
    final removed = await store.delete(db, finder: finder);
    return removed;
  }

  static Future<List<Map<String, dynamic>>> query(String table,
      {Finder? finder}) async {
    final db = await open('app_db');
    final store = _storeFor(table);
    final records = await store.find(db, finder: finder);
    return records.map((r) {
      final map = Map<String, dynamic>.from(r.value);
      map['_id'] = r.key;
      return map;
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> rawQuery(String sql) async {
    // Simple rawQuery unsupported: return empty and caller must avoid raw SQL on web.
    // TODO: implement a SQL parser/mapping if needed.
    throw UnsupportedError('rawQuery not supported on WebDbAdapter');
  }

  static Future<void> execute(String sql) async {
    // No-op for SQL on web; schema is implicit in stores.
    return;
  }

  static Future<T> transaction<T>(Future<T> Function() action) async {
    // Sembast has transaction support, but for simplicity run action directly.
    return await action();
  }
}