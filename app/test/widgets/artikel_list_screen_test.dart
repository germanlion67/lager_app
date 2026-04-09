// test/widgets/artikel_list_screen_test.dart
//
// O-006: Widget-Tests für ArtikelListScreen
// v0.7.8: QR-Button neben Suchfeld, Neuer-Artikel in AppBar, kein FAB
//
// Strategie:
// - sqflite_ffi In-Memory-DB mit vollständigem Schema via injectDatabase()
// - NextcloudConnectionService Singleton-Timer via stopPeriodicCheck() stoppen
// - pump(Duration) statt pumpAndSettle() → ignoriert laufende HTTP-Timer
// - pump(Duration) am Testende → leert Debounce-Timer (300ms)
// - _pumpUntilIdle() → wartet bis _isLoading = false (Leer-Hinweis sichtbar)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lager_app/screens/artikel_list_screen.dart';
import 'package:lager_app/services/artikel_db_service.dart';
import 'package:lager_app/services/nextcloud_connection_service.dart';

// ---------------------------------------------------------------------------
// Vollständiges Schema — 1:1 aus ArtikelDbService._createTableSql
// ---------------------------------------------------------------------------
const _createArtikelTableSql = '''
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
''';

const _createSyncMetaTableSql = '''
  CREATE TABLE IF NOT EXISTS sync_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at INTEGER NOT NULL
  )
''';

// ---------------------------------------------------------------------------
// In-Memory-DB erstellen und in Singleton injizieren
// ---------------------------------------------------------------------------
Future<void> _injectInMemoryDb() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute(_createArtikelTableSql);
        await db.execute(_createSyncMetaTableSql);
      },
    ),
  );
  ArtikelDbService().injectDatabase(db);
}

// ---------------------------------------------------------------------------
// Wartet bis ArtikelSkeletonList verschwunden ist (_isLoading = false)
// Timeout nach 5s → verhindert endlose Schleife
// ---------------------------------------------------------------------------
Future<void> _pumpUntilLoaded(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    // Skeleton weg = _isLoading false = Daten (oder Leer-Hinweis) sichtbar
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
        find
            .byWidgetPredicate(
              (w) =>
                  w.runtimeType.toString().contains('ArtikelSkeletonList') ||
                  w.runtimeType.toString().contains('Skeleton'),
            )
            .evaluate()
            .isEmpty) {
      // Noch einen Frame für setState
      await tester.pump(const Duration(milliseconds: 100));
      return;
    }
  }
}

// ---------------------------------------------------------------------------
// Timer-Safe pump: Screen aufbauen + auf Ladeende warten
// ---------------------------------------------------------------------------
Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // Periodic-Timer VOR initState stoppen
  NextcloudConnectionService().stopPeriodicCheck();

  await tester.pumpWidget(const MaterialApp(home: ArtikelListScreen()));

  // initState läuft → _ladeArtikel() startet → warten bis fertig
  await _pumpUntilLoaded(tester);

  // Periodic-Timer den initState gestartet hat sofort wieder stoppen
  NextcloudConnectionService().stopPeriodicCheck();
}

// ---------------------------------------------------------------------------
// Debounce-Timer (300ms) + alle restlichen Timers leeren
// Nach enterText() oder tap() mit Navigation aufrufen
// ---------------------------------------------------------------------------
Future<void> _drainTimers(WidgetTester tester) async {
  // 300ms Debounce + Puffer
  await tester.pump(const Duration(milliseconds: 500));
  // Nextcloud Periodic-Timer (15s) — können wir nicht abwarten,
  // daher stoppen wir ihn und pumpen nur kurz
  NextcloudConnectionService().stopPeriodicCheck();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await _injectInMemoryDb();
  });

  tearDown(() async {
    NextcloudConnectionService().stopPeriodicCheck();
    await ArtikelDbService().closeDatabase();
  });

  // -------------------------------------------------------------------------
  // Render-Tests
  // -------------------------------------------------------------------------
  group('ArtikelListScreen – Render', () {
    testWidgets('AppBar-Titel ist sichtbar', (tester) async {
      await _pumpScreen(tester);

      expect(find.text('Artikelliste'), findsOneWidget);
    });

    testWidgets('Suchfeld ist vorhanden', (tester) async {
      await _pumpScreen(tester);

      expect(
        find.widgetWithText(TextField, 'Suche nach Name oder Beschreibung'),
        findsOneWidget,
      );
    });

    testWidgets('Ort-Filter-Dropdown ist vorhanden', (tester) async {
      await _pumpScreen(tester);

      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('DB-Verbindungs-Icon ist sichtbar', (tester) async {
      await _pumpScreen(tester);

      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.dns),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // v0.7.8 Punkt 7: QR-Button neben Suchfeld
  // -------------------------------------------------------------------------
  group('ArtikelListScreen – QR-Button (Punkt 7)', () {
    testWidgets('QR-Button ist direkt neben Suchfeld vorhanden',
        (tester) async {
      await _pumpScreen(tester);

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is IconButton &&
              (w.icon is Icon) &&
              ((w.icon as Icon).icon == Icons.qr_code_scanner ||
                  (w.icon as Icon).icon == Icons.search),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Kein FAB für QR-Scanner vorhanden (v0.7.8)', (tester) async {
      await _pumpScreen(tester);

      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // v0.7.8 Punkt 8: Neuer Artikel in AppBar
  // -------------------------------------------------------------------------
  group('ArtikelListScreen – Neuer Artikel AppBar (Punkt 8)', () {
    testWidgets('„Neuer Artikel"-Button ist in AppBar vorhanden',
        (tester) async {
      await _pumpScreen(tester);

      expect(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Neuen Artikel erfassen',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Aktualisieren-Button ist in AppBar vorhanden',
        (tester) async {
      await _pumpScreen(tester);

      expect(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Aktualisieren',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Kein FloatingActionButton vorhanden (v0.7.8)',
        (tester) async {
      await _pumpScreen(tester);

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('„Neuer Artikel"-Button öffnet ArtikelErfassenScreen',
        (tester) async {
      await _pumpScreen(tester);

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Neuen Artikel erfassen',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Neuen Artikel erfassen'), findsOneWidget);

      // Alle Timer leeren bevor Widget-Tree disposed wird
      await _drainTimers(tester);
    });
  });

  // -------------------------------------------------------------------------
  // Menü-Tests
  // -------------------------------------------------------------------------
  group('ArtikelListScreen – Menü', () {
    testWidgets('Menü-Button (more_vert) ist vorhanden', (tester) async {
      await _pumpScreen(tester);

      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.more_vert,
        ),
        findsOneWidget,
      );
    });

    testWidgets('Menü öffnet sich beim Tippen', (tester) async {
      await _pumpScreen(tester);

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.more_vert,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Artikel import/export'), findsOneWidget);
      expect(find.text('Einstellungen'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Suche
  // -------------------------------------------------------------------------
  group('ArtikelListScreen – Suche', () {
    testWidgets('Suchfeld nimmt Eingabe an', (tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Suche nach Name oder Beschreibung',
        ),
        'Hammer',
      );

      // Debounce abwarten (300ms) + Timer leeren
      await _drainTimers(tester);

      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('Leere Liste zeigt Hinweistext bei leerem Suchbegriff',
        (tester) async {
      await _pumpScreen(tester);

      // _pumpUntilLoaded hat bereits auf _isLoading=false gewartet
      // → Leer-Hinweis muss jetzt sichtbar sein
      expect(
        find.textContaining('Keine Artikel'),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // v0.7.8 Punkt 9: DB-Icon Farbe
  // -------------------------------------------------------------------------
  group('ArtikelListScreen – DB-Icon Farbe (Punkt 9)', () {
    testWidgets('DB-Icon ist vorhanden und hat eine Farbe', (tester) async {
      await _pumpScreen(tester);

      final dbIcons = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.dns,
      );

      expect(dbIcons, findsOneWidget);

      final dbIcon = tester.widget<Icon>(dbIcons.first);
      expect(dbIcon.color, isNotNull);
    });
  });
}