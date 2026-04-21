// test/widgets/artikel_list_screen_test.dart
//
// O-006: Widget-Tests für ArtikelListScreen
// v0.7.8: QR-Button neben Suchfeld, Neuer-Artikel in AppBar, kein FAB
//
// Strategie (nach Refactoring):
// - NoOpNextcloudService → kein Periodic-Timer → kein Timer-pending
// - initialArtikel: [] → kein DB-Zugriff → kein _pumpUntilLoaded nötig
// - Einfaches pump() reicht für alle Tests
// - sqflite_ffi nur noch für Tests die tatsächlich DB brauchen

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lager_app/screens/artikel_list_screen.dart';
import 'package:lager_app/services/artikel_db_service.dart';

import '../helpers/no_op_nextcloud_service.dart';

// ---------------------------------------------------------------------------
// Vollständiges Schema — 1:1 aus ArtikelDbService
// (Wird nur noch für DB-Tests gebraucht, nicht für die 3 Fix-Tests)
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
// In-Memory-DB — nur für Tests die tatsächlich DB-Zugriff brauchen
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
// Screen pumpen — sauber, schnell, ohne Timer-Workarounds
// ---------------------------------------------------------------------------
Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: ArtikelListScreen(
        nextcloudService: NoOpNextcloudService(),
        initialArtikel: const [],  // Leere Liste → _isLoading sofort false
      ),
    ),
  );

  // Wichtig: pumpAndSettle, um sicherzustellen, dass alle Widgets initial gerendert sind
  // und keine ausstehenden Animationen oder Microtasks den Test stören.
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // DB wird weiterhin injiziert, falls der Screen intern doch
    // auf die DB zugreift (z.B. bei _onSuchbegriffChanged → _ladeArtikel)
    await _injectInMemoryDb();
  });

  tearDown(() async {
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
      // Angepasst: Suche nach dem Key, den wir im TextField hinzugefügt haben
      expect(find.byKey(const Key('articleSearchField')), findsOneWidget);
      // Optional: Überprüfen, ob der labelText korrekt ist
      expect(find.text('Suche...'), findsOneWidget);
    });

    testWidgets('Ort-Filter-Dropdown ist vorhanden', (tester) async {
      await _pumpScreen(tester);
      // Angepasst: Suche nach dem Key, den wir im DropdownButton hinzugefügt haben
      expect(find.byKey(const Key('locationFilterDropdown')), findsOneWidget);
      // Optional: Überprüfen, ob der Hint-Text korrekt ist
      expect(find.text('Alle Orte'), findsOneWidget);
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
      // Angepasst: Suche nach dem Key, den wir im IconButton hinzugefügt haben
      expect(find.byKey(const Key('qrScannerButton')), findsOneWidget);
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
      // Angepasst: Suche nach dem Tooltip, den wir im IconButton hinzugefügt haben
      expect(
        find.byTooltip('Neuen Artikel erfassen'),
        findsOneWidget,
      );
    });

    testWidgets('Aktualisieren-Button ist in AppBar vorhanden',
        (tester) async {
      await _pumpScreen(tester);
      // Angepasst: Suche nach dem Tooltip, den wir im IconButton hinzugefügt haben
      expect(
        find.byTooltip('Aktualisieren'),
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

      // Angepasst: Suche nach dem Tooltip, den wir im IconButton hinzugefügt haben
      await tester.tap(
        find.byTooltip('Neuen Artikel erfassen'),
      );
      // Wichtig: pumpAndSettle nach einer Navigation
      await tester.pumpAndSettle();

      expect(find.text('Neuen Artikel erfassen'), findsOneWidget);
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

      // Tippe auf den Menü-Button
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.more_vert,
        ),
      );
      // Wichtig: pumpAndSettle, damit das PopupMenu gerendert wird
      await tester.pumpAndSettle();

      // Angepasst: Der Text im PopupMenuItem ist 'Import/Export', nicht 'Artikel import/export'
      expect(find.text('Import/Export'), findsOneWidget);
      expect(find.text('Einstellungen'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Suche
  // -------------------------------------------------------------------------
  group('ArtikelListScreen – Suche', () {
    testWidgets('Suchfeld nimmt Eingabe an', (tester) async {
      await _pumpScreen(tester);

      // Angepasst: Suche nach dem Key, den wir im TextField hinzugefügt haben
      await tester.enterText(
        find.byKey(const Key('articleSearchField')),
        'Hammer',
      );

      // Debounce-Timer abwarten (500ms im _onSuchbegriffChanged) + etwas Puffer
      await tester.pump(const Duration(milliseconds: 550));
      // Optional: pumpAndSettle, falls weitere asynchrone Operationen ausgelöst werden
      // await tester.pumpAndSettle();

      // Überprüfe, ob der eingegebene Text im TextField sichtbar ist
      expect(find.text('Hammer'), findsOneWidget);
    });

    testWidgets('Leere Liste zeigt Hinweistext bei leerem Suchbegriff',
        (tester) async {
      await _pumpScreen(tester);

      // initialArtikel: [] → _isLoading = false → Leer-Hinweis sofort da
      expect(
        find.textContaining('Keine Artikel gefunden.'), // Angepasst an den exakten Text
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