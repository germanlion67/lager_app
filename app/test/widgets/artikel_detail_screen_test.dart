// test/widgets/artikel_detail_screen_test.dart
//
// O-006: Widget-Tests für ArtikelDetailScreen
// v0.7.8: Name editierbar, Crop-Button, AppBar-Aktionen

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lager_app/models/artikel_model.dart';
import 'package:lager_app/screens/artikel_detail_screen.dart';

// ---------------------------------------------------------------------------
// Test-Artikel
// ---------------------------------------------------------------------------
Artikel _testArtikel({
  String name = 'Testartikel',
  int menge = 5,
  String ort = 'Lager A',
  String fach = 'Regal 1',
  String beschreibung = 'Eine Beschreibung',
  int artikelnummer = 1001,
}) {
  return Artikel(
    id: 1,
    name: name,
    artikelnummer: artikelnummer,
    menge: menge,
    ort: ort,
    fach: fach,
    beschreibung: beschreibung,
    bildPfad: '',
    erstelltAm: DateTime(2024, 1, 1).toUtc(),
    aktualisiertAm: DateTime(2024, 1, 2).toUtc(),
  );
}

// ---------------------------------------------------------------------------
// Wrapper
// ---------------------------------------------------------------------------
Widget _wrap(Widget child) => MaterialApp(home: child);

// ---------------------------------------------------------------------------
// Screen pumpen
// ---------------------------------------------------------------------------
Future<void> _pumpScreen(WidgetTester tester, {Artikel? artikel}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    _wrap(ArtikelDetailScreen(artikel: artikel ?? _testArtikel())),
  );
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

// ---------------------------------------------------------------------------
// Edit-Modus aktivieren
// ---------------------------------------------------------------------------
Future<void> _aktiviereEditModus(WidgetTester tester) async {
  final editBtn = find.byWidgetPredicate(
    (w) => w is IconButton && w.tooltip == 'Ändern',
  );
  expect(editBtn, findsOneWidget);
  await tester.tap(editBtn);
  await tester.pumpAndSettle();
}

void main() {
  // -------------------------------------------------------------------------
  // Render-Tests
  // -------------------------------------------------------------------------
  group('ArtikelDetailScreen – Render', () {
    testWidgets('AppBar zeigt Artikelname', (tester) async {
      await _pumpScreen(tester);

      expect(find.text('Testartikel'), findsWidgets);
    });

    testWidgets('Name-Feld ist sichtbar', (tester) async {
      await _pumpScreen(tester);

      expect(find.widgetWithText(TextField, 'Testartikel'), findsOneWidget);
    });

    testWidgets('Ort- und Fach-Felder sind sichtbar', (tester) async {
      await _pumpScreen(tester);

      expect(find.widgetWithText(TextField, 'Lager A'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Regal 1'), findsOneWidget);
    });

    testWidgets('Menge wird angezeigt', (tester) async {
      await _pumpScreen(tester);

      expect(find.textContaining('Menge: 5'), findsOneWidget);
    });

    testWidgets('Artikelnummer wird angezeigt', (tester) async {
      await _pumpScreen(tester);

      expect(find.textContaining('Art.-Nr.: 1001'), findsOneWidget);
    });

    testWidgets('Beschreibung-Feld ist sichtbar', (tester) async {
      await _pumpScreen(tester);

      expect(
        find.widgetWithText(TextField, 'Eine Beschreibung'),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // AppBar-Aktionen
  // -------------------------------------------------------------------------
  group('ArtikelDetailScreen – AppBar-Aktionen', () {
    testWidgets('Ändern-Button ist in AppBar vorhanden', (tester) async {
      await _pumpScreen(tester);

      expect(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Ändern',
        ),
        findsOneWidget,
      );
    });

    testWidgets('PDF-Button ist in AppBar vorhanden', (tester) async {
      await _pumpScreen(tester);

      expect(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Als PDF exportieren',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Löschen-Button ist in AppBar vorhanden', (tester) async {
      await _pumpScreen(tester);

      expect(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Artikel löschen',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Anhänge-Button ist in AppBar vorhanden', (tester) async {
      await _pumpScreen(tester);

      expect(
        find.byWidgetPredicate(
          (w) => w is IconButton && (w.tooltip ?? '').contains('Anhänge'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'Bild-Buttons sind im View-Modus NICHT sichtbar', (tester) async {
      await _pumpScreen(tester);

      expect(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Bild wählen',
        ),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Kamera',
        ),
        findsNothing,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Edit-Modus
  // -------------------------------------------------------------------------
  group('ArtikelDetailScreen – Edit-Modus', () {
    testWidgets('Edit-Button wechselt zu Speichern-Icon', (tester) async {
      await _pumpScreen(tester);
      await _aktiviereEditModus(tester);

      expect(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Keine Änderungen',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Bild-Button erscheint im Edit-Modus', (tester) async {
      await _pumpScreen(tester);
      await _aktiviereEditModus(tester);

      expect(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Bild wählen',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Löschen-Button ist im Edit-Modus deaktiviert',
        (tester) async {
      await _pumpScreen(tester);
      await _aktiviereEditModus(tester);

      final loeschenBtn = find.byWidgetPredicate(
        (w) =>
            w is IconButton &&
            w.tooltip == 'Erst speichern oder Bearbeitung abbrechen',
      );
      expect(loeschenBtn, findsOneWidget);
    });

    testWidgets('Name-Feld ist im Edit-Modus beschreibbar', (tester) async {
      await _pumpScreen(tester);
      await _aktiviereEditModus(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Testartikel'),
        'Geänderter Name',
      );
      await tester.pumpAndSettle();

      expect(find.text('Geänderter Name'), findsWidgets);
    });

    testWidgets('AppBar-Titel aktualisiert sich beim Tippen', (tester) async {
      await _pumpScreen(tester);
      await _aktiviereEditModus(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Testartikel'),
        'Neuer Name',
      );
      await tester.pumpAndSettle();

      // AppBar-Titel soll den neuen Namen zeigen
      expect(find.text('Neuer Name'), findsWidgets);
    });

    testWidgets(
        'Speichern-Button aktiv nach Änderung', (tester) async {
      await _pumpScreen(tester);
      await _aktiviereEditModus(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Testartikel'),
        'Geänderter Name',
      );
      await tester.pumpAndSettle();

      // Tooltip wechselt von 'Keine Änderungen' zu 'Speichern'
      expect(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Speichern',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Crop-Button ist ohne Bild NICHT sichtbar', (tester) async {
      await _pumpScreen(tester);
      await _aktiviereEditModus(tester);

      // Kein _pendingBytes → kein Crop-Button
      expect(
        find.widgetWithText(OutlinedButton, 'Zuschneiden'),
        findsNothing,
      );
    });

    testWidgets('Menge erhöhen/verringern nur im Edit-Modus aktiv',
        (tester) async {
      await _pumpScreen(tester);

      // View-Modus: Buttons inaktiv
      final addBtn = find.byWidgetPredicate(
        (w) => w is IconButton && (w.icon as Icon).icon == Icons.add,
      );
      final removeBtn = find.byWidgetPredicate(
        (w) => w is IconButton && (w.icon as Icon).icon == Icons.remove,
      );

      // Im View-Modus existieren die Buttons, sind aber disabled
      final addWidget = tester.widget<IconButton>(addBtn.first);
      expect(addWidget.onPressed, isNull);

      await _aktiviereEditModus(tester);

      // Im Edit-Modus sind sie aktiv
      final addWidgetEdit = tester.widget<IconButton>(addBtn.first);
      expect(addWidgetEdit.onPressed, isNotNull);

      final removeWidgetEdit = tester.widget<IconButton>(removeBtn.first);
      expect(removeWidgetEdit.onPressed, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // Verwerfen-Dialog
  // -------------------------------------------------------------------------
  group('ArtikelDetailScreen – Verwerfen-Dialog', () {
    testWidgets(
        'Zurück ohne Änderungen → kein Dialog', (tester) async {
      await _pumpScreen(tester);

      // Kein Edit-Modus → PopScope lässt direkt durch
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.text('Änderungen verwerfen?'), findsNothing);
    });

    testWidgets(
        'Zurück mit Änderungen im Edit-Modus → Dialog erscheint',
        (tester) async {
      await _pumpScreen(tester);
      await _aktiviereEditModus(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Testartikel'),
        'Geänderter Name',
      );
      await tester.pumpAndSettle();

      // System-Back simulieren
      final dynamic widgetsAppState =
          tester.state(find.byType(WidgetsApp));
      widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Änderungen verwerfen?'), findsOneWidget);
      expect(find.text('Weiter bearbeiten'), findsOneWidget);
      expect(find.text('Verwerfen'), findsOneWidget);
    });

    testWidgets(
        'Verwerfen-Dialog — Weiter bearbeiten schließt Dialog',
        (tester) async {
      await _pumpScreen(tester);
      await _aktiviereEditModus(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Testartikel'),
        'Geänderter Name',
      );
      await tester.pumpAndSettle();

      final dynamic widgetsAppState =
          tester.state(find.byType(WidgetsApp));
      widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Weiter bearbeiten'));
      await tester.pumpAndSettle();

      expect(find.text('Änderungen verwerfen?'), findsNothing);
      // Screen noch sichtbar
      expect(find.text('Geänderter Name'), findsWidgets);
    });
  });

  // -------------------------------------------------------------------------
  // Löschen-Dialog
  // -------------------------------------------------------------------------
  group('ArtikelDetailScreen – Löschen-Dialog', () {
    testWidgets('Löschen-Button öffnet Bestätigungsdialog', (tester) async {
      await _pumpScreen(tester);

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Artikel löschen',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Artikel löschen?'), findsOneWidget);
      expect(find.text('Abbrechen'), findsOneWidget);
      expect(find.text('Löschen'), findsOneWidget);
    });

    testWidgets('Löschen-Dialog — Abbrechen schließt Dialog', (tester) async {
      await _pumpScreen(tester);

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Artikel löschen',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(find.text('Artikel löschen?'), findsNothing);
      // Screen noch sichtbar
      expect(find.text('Testartikel'), findsWidgets);
    });
  });
}