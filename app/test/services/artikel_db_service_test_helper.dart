// test/services/artikel_db_service_test_helper.dart
//
// Überschreibt die plattformspezifische DB-Initialisierung für Tests.
// Nutzt sqflite_common_ffi mit inMemoryDatabasePath statt einer Datei-DB.
//
// Verwendung:
//   setUpAll(() async {
//     await ArtikelDbServiceTestHelper.setupInMemory(service);
//   });

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lager_app/services/artikel_db_service.dart';

abstract final class ArtikelDbServiceTestHelper {
  /// Initialisiert eine In-Memory-SQLite-DB und injiziert sie in [service].
  ///
  /// Nutzt sqflite_common_ffi direkt — umgeht openArtikelDatabase()
  /// und damit den plattformspezifischen Dateipfad.
  static Future<void> setupInMemory(ArtikelDbService service) async {
    // ✅ FFI einmalig initialisieren
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // ✅ In-Memory-DB öffnen mit demselben Schema wie der Produktionscode
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE artikel (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              artikelnummer INTEGER,
              menge INTEGER,
              ort TEXT,
              fach TEXT,
              beschreibung TEXT,
              bildPfad TEXT,
              thumbnailPfad TEXT,
              thumbnailEtag TEXT,
              erstelltAm TEXT,
              aktualisiertAm TEXT,
              remoteBildPfad TEXT,
              uuid TEXT UNIQUE NOT NULL,
              updated_at INTEGER NOT NULL DEFAULT 0,
              deleted INTEGER NOT NULL DEFAULT 0,
              etag TEXT,
              remote_path TEXT,
              device_id TEXT,
              kategorie TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sync_meta (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          // ✅ Indizes — identisch mit _createIndices()
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_artikel_updated_at '
            'ON artikel(updated_at)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_artikel_uuid ON artikel(uuid)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_artikel_deleted ON artikel(deleted)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_artikel_name ON artikel(name)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_artikel_name_ort_fach '
            'ON artikel(name, ort, fach)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_artikel_artikelnummer '
            'ON artikel(artikelnummer)',
          );
        },
      ),
    );

    // ✅ In-Memory-DB in den Service injizieren
    // ArtikelDbService exponiert database als Future<Database> —
    // wir setzen _db direkt via injectDatabase()
    service.injectDatabase(db);
  }
}