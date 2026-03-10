// lib/services/artikel_db_platform_stub.dart
//
// Web-Stub – wird im Web importiert, aber nie aufgerufen.
// ArtikelDbService wirft im Web einen UnsupportedError bevor
// diese Funktionen erreicht werden.

import 'package:sqflite/sqflite.dart';

bool isDesktopPlatform() {
  throw UnsupportedError('isDesktopPlatform() ist im Web nicht verfügbar');
}

Future<Database> openArtikelDatabase({
  required int version,
  required Future<void> Function(Database, int) onCreate,
  required Future<void> Function(Database, int, int) onUpgrade,
}) {
  throw UnsupportedError('openArtikelDatabase() ist im Web nicht verfügbar');
}
