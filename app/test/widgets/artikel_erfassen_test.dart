// test/widgets/artikel_erfassen_test.dart
//
// O-006: Widget-Tests für ArtikelErfassenScreen
// v0.7.8: Bild-Buttons sind jetzt IconButton (Punkt 6) — Tests angepasst

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lager_app/screens/artikel_erfassen_screen.dart';
import 'package:lager_app/services/image_picker.dart';

// ---------------------------------------------------------------------------
// Wrapper
// ---------------------------------------------------------------------------
Widget _wrap(Widget child) => MaterialApp(home: child);

// ---------------------------------------------------------------------------
// Screen pumpen — große Fenstergröße damit ListView-Inhalt sichtbar ist
// ---------------------------------------------------------------------------
Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_wrap(const ArtikelErfassenScreen()));
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

// ---------------------------------------------------------------------------
// Hilfsfunktion: Finder durch ListView scrollen bis sichtbar
// ---------------------------------------------------------------------------
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Speichern-Button finden + tippen
// ---------------------------------------------------------------------------
Future<void> _tapSpeichern(WidgetTester tester) async {
  final speichern = find.widgetWithText(FilledButton, 'Speichern');
  await _scrollTo(tester, speichern);
  await tester.tap(speichern);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Abbrechen-Button finden + tippen
// ---------------------------------------------------------------------------
Future<void> _tapAbbrechen(WidgetTester tester) async {
  final abbrechen = find.widgetWithText(OutlinedButton, 'Abbrechen');
  await _scrollTo(tester, abbrechen);
  await tester.tap(abbrechen);
  await tester.pumpAndSettle();
}

void main() {
  // -------------------------------------------------------------------------
  // Render-Tests
  // -------------------------------------------------------------------------
  group('ArtikelErfassenScreen – Render', () {
    testWidgets('Pflichtfeld-Labels sind sichtbar', (tester) async {
      await _pumpScreen(tester);

      expect(find.text('Name *'), findsOneWidget);
      expect(find.text('Ort *'), findsOneWidget);
      expect(find.text('Fach *'), findsOneWidget);
    });

    // v0.7.8 Punkt 6: Bild-Button ist jetzt IconButton mit Icons.image
    testWidgets('Bilddatei-Button ist sichtbar', (tester) async {
      await _pumpScreen(tester);

      final btn = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.tooltip == 'Bilddatei wählen',
      );
      await _scrollTo(tester, btn);
      expect(btn, findsOneWidget);
    });

    // v0.7.8 Punkt 6: Kamera-Button ist jetzt IconButton mit Icons.camera_alt
    testWidgets(
        'Kamera-Button Sichtbarkeit entspricht isCameraAvailable',
        (tester) async {
      await _pumpScreen(tester);

      final btn = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.tooltip == 'Kamera',
      );

      if (ImagePickerService.isCameraAvailable) {
        await _scrollTo(tester, btn);
        expect(btn, findsOneWidget);
      } else {
        expect(btn, findsNothing);
      }
    });

    testWidgets('Speichern- und Abbrechen-Button sind vorhanden',
        (tester) async {
      await _pumpScreen(tester);

      await _scrollTo(tester, find.widgetWithText(FilledButton, 'Speichern'));
      expect(find.widgetWithText(FilledButton, 'Speichern'), findsOneWidget);

      expect(
        find.widgetWithText(OutlinedButton, 'Abbrechen'),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Validierungs-Tests
  // -------------------------------------------------------------------------
  group('ArtikelErfassenScreen – Validierung', () {
    testWidgets('Leere Pflichtfelder zeigen Fehlermeldungen', (tester) async {
      await _pumpScreen(tester);

      // Menge + Artikelnummer leeren
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Menge'),
        '',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Artikelnummer'),
        '',
      );

      await _tapSpeichern(tester);

      expect(find.text('Bitte einen Namen eingeben'), findsOneWidget);
      expect(find.text('Bitte einen Ort eingeben'), findsOneWidget);
      expect(find.text('Bitte ein Fach eingeben'), findsOneWidget);
      expect(find.text('Bitte eine Menge eingeben'), findsOneWidget);
      expect(find.text('Bitte eine Artikelnummer eingeben'), findsOneWidget);
    });

    testWidgets('Name < 2 Zeichen zeigt Fehler', (tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name *'),
        'A',
      );

      await _tapSpeichern(tester);

      expect(
        find.text('Name muss mindestens 2 Zeichen lang sein'),
        findsOneWidget,
      );
    });

    testWidgets('Artikelnummer < 1000 zeigt Fehler', (tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Artikelnummer'),
        '999',
      );

      await _tapSpeichern(tester);

      expect(
        find.text('Artikelnummer muss mindestens 1000 sein'),
        findsOneWidget,
      );
    });

    testWidgets('Gültige Menge 0 zeigt keinen Fehler', (tester) async {
      await _pumpScreen(tester);

      // Menge ist bereits '0'
      await _tapSpeichern(tester);

      expect(find.text('Bitte eine Menge eingeben'), findsNothing);
      expect(find.text('Bitte eine gültige Zahl eingeben'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Abbrechen-Tests
  // -------------------------------------------------------------------------
  group('ArtikelErfassenScreen – Abbrechen', () {
    testWidgets(
        'Abbrechen ohne Änderungen → kein Bestätigungsdialog',
        (tester) async {
      await _pumpScreen(tester);

      await _tapAbbrechen(tester);

      expect(find.text('Änderungen verwerfen?'), findsNothing);
    });

    testWidgets(
        'Abbrechen nach Eingabe → Bestätigungsdialog erscheint',
        (tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name *'),
        'Testartikel',
      );
      await tester.pumpAndSettle();

      await _tapAbbrechen(tester);

      expect(find.text('Änderungen verwerfen?'), findsOneWidget);
      expect(find.text('Weiter bearbeiten'), findsOneWidget);
      expect(find.text('Verwerfen'), findsOneWidget);
    });

    testWidgets(
        'Bestätigungsdialog — Weiter bearbeiten schließt Dialog',
        (tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name *'),
        'Testartikel',
      );
      await tester.pumpAndSettle();

      await _tapAbbrechen(tester);

      await tester.tap(find.text('Weiter bearbeiten'));
      await tester.pumpAndSettle();

      expect(find.text('Änderungen verwerfen?'), findsNothing);
      expect(find.text('Neuen Artikel erfassen'), findsOneWidget);
    });
  });
}