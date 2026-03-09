//lib/services/database_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart' as p;
import 'package:sembast/sembast.dart';
import 'web_db_adapter.dart';
import 'dart:developer' as developer;

class DatabaseProvider {
  final bool isWeb;
  final sqflite.Database? _sqlDb;
  final String dbName;
  final String? _dbFilePath;

  DatabaseProvider._(this.dbName, this.isWeb, this._sqlDb, [this._dbFilePath]);

  static Future<DatabaseProvider> open(String dbName) async {
    if (kIsWeb) {
      await WebDbAdapter.open(dbName);
      developer.log('DatabaseProvider: opened web DB "$dbName"', name: 'db');
      return DatabaseProvider._(dbName, true, null, null);
    } else {
      final dbPath = await sqflite.getDatabasesPath();
      final full = p.join(dbPath, dbName);
      developer.log('DatabaseProvider: opening sqlite DB at: $full', name: 'db');
      final db = await sqflite.openDatabase(full);
      return DatabaseProvider._(dbName, false, db, full);
    }
  }

  bool get web => isWeb;
  String? get filePath => _dbFilePath;

  Future<int> insert(String table, Map<String, dynamic> values) async {
    if (isWeb) return await WebDbAdapter.insert(table, values);
    return await _sqlDb!.insert(table, values);
  }

  Future<int> update(String table, Map<String, dynamic> values,
      {String? where, List<dynamic>? whereArgs}) async {
    if (isWeb) {
      Finder? f;
      if (where != null && where.startsWith('id = ?')) {
        final id = whereArgs != null && whereArgs.isNotEmpty ? whereArgs[0] : null;
        if (id != null) f = Finder(filter: Filter.equals('id', id));
      }
      return await WebDbAdapter.update(table, values, finder: f);
    }
    return await _sqlDb!.update(table, values, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    if (isWeb) {
      Finder? f;
      if (where != null && where.startsWith('id = ?')) {
        final id = whereArgs != null && whereArgs.isNotEmpty ? whereArgs[0] : null;
        if (id != null) f = Finder(filter: Filter.equals('id', id));
      }
      return await WebDbAdapter.delete(table, finder: f);
    }
    return await _sqlDb!.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> query(String table,
      {String? where, List<dynamic>? whereArgs, String? orderBy, int? limit, int? offset}) async {
    if (isWeb) {
      Finder? f;
      if (where != null && where.startsWith('id = ?')) {
        final id = whereArgs != null && whereArgs.isNotEmpty ? whereArgs[0] : null;
        if (id != null) f = Finder(filter: Filter.equals('id', id));
      }
      final res = await WebDbAdapter.query(table, finder: f);
      return res;
    }
    return await _sqlDb!.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit, offset: offset);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    if (isWeb) {
      return await WebDbAdapter.rawQuery(sql);
    }
    return await _sqlDb!.rawQuery(sql, arguments);
  }

  Future<void> execute(String sql) async {
    if (isWeb) return await WebDbAdapter.execute(sql);
    await _sqlDb!.execute(sql);
  }

  Future<void> close() async {
    if (isWeb) return await WebDbAdapter.close();
    await _sqlDb?.close();
  }
}