// lib/services/artikel_db_platform_io.dart
//
// Platform-spezifische DB-Initialisierung für Mobile & Desktop.
// Wird im Web NICHT importiert.

import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

// FIX: Init-Guard verhindert mehrfaches Aufrufen von sqfliteFfiInit()
// und mehrfaches Überschreiben der globalen databaseFactory.
bool _ffiInitialized = false;

/// Gibt true zurück, wenn wir auf Desktop laufen (FFI nötig).
bool isDesktopPlatform() {
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

/// Initialisiert und öffnet die SQLite-Datenbank.
/// Verwendet FFI auf Desktop, normales sqflite auf Mobile.
Future<Database> openArtikelDatabase({
  required int version,
  required Future<void> Function(Database, int) onCreate,
  required Future<void> Function(Database, int, int) onUpgrade,
}) async {
  if (isDesktopPlatform()) {
    // FIX: sqfliteFfiInit() und databaseFactory nur einmal setzen.
    // Mehrfache Aufrufe können bei Tests oder Hot-Restart zu
    // unerwartetem Verhalten führen.
    if (!_ffiInitialized) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _ffiInitialized = true;
    }

    final dbPath = await databaseFactoryFfi.getDatabasesPath();
    final path = join(dbPath, 'artikel.db');

    try {
      return await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: version,
          onCreate: onCreate,
          onUpgrade: onUpgrade,
        ),
      );
    } catch (e, stack) {
      // Fehler wird nach oben weitergegeben — Logging erfolgt im
      // aufrufenden ArtikelDbService._initDb()
      Error.throwWithStackTrace(e, stack);
    }
  } else {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'artikel.db');

    try {
      return await openDatabase(
        path,
        version: version,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
      );
    } catch (e, stack) {
      // Fehler wird nach oben weitergegeben — Logging erfolgt im
      // aufrufenden ArtikelDbService._initDb()
      Error.throwWithStackTrace(e, stack);
    }
  }
}