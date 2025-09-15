//.../integration_test/consistency_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lager_app/main.dart' as app;

// Hinweis: Für reale Nextcloud-Tests empfiehlt sich ein Mock der HTTP-Requests.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Konsistenz-Check: UI-Flows und Nextcloud', () {
    testWidgets('Artikel-Erfassung, Anzeige, Bearbeitung, Löschung', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Erfassungs-Flow starten (Floating Action Button)
      final fab = find.byIcon(Icons.add);
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Felder ausfüllen
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Testartikel');
      await tester.enterText(find.widgetWithText(TextFormField, 'Beschreibung'), 'Testbeschreibung');
      await tester.enterText(find.widgetWithText(TextFormField, 'Ort'), 'Keller');
      await tester.enterText(find.widgetWithText(TextFormField, 'Fach'), 'A1');
      await tester.enterText(find.widgetWithText(TextFormField, 'Menge'), '5');

      // Speichern
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      // Artikel erscheint in Liste
      expect(find.text('Testartikel'), findsOneWidget);

      // Artikel-Detail aufrufen
      await tester.tap(find.text('Testartikel'));
      await tester.pumpAndSettle();

      // Beschreibung bearbeiten
      final editButton = find.byIcon(Icons.edit);
      if (editButton.evaluate().isNotEmpty) {
        await tester.tap(editButton);
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextFormField, 'Beschreibung'), 'Bearbeitet');
        await tester.tap(find.text('Speichern'));
        await tester.pumpAndSettle();
      }

      // Löschen testen
      final deleteButton = find.byIcon(Icons.delete);
      if (deleteButton.evaluate().isNotEmpty) {
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();
        // Eventuell Bestätigungsdialog
        final confirmDelete = find.text('Bestätigen');
        if (confirmDelete.evaluate().isNotEmpty) {
          await tester.tap(confirmDelete);
          await tester.pumpAndSettle();
        }
      }

      // Artikel sollte aus Liste entfernt sein
      expect(find.text('Testartikel'), findsNothing);
    });

    testWidgets('Nextcloud Settings und Verbindungstest', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Einstellungen öffnen (über AppBar-Icon oder Menü)
      final settingsButton = find.byIcon(Icons.settings);
      if (settingsButton.evaluate().isNotEmpty) {
        await tester.tap(settingsButton);
        await tester.pumpAndSettle();
      } else {
        // Fallback: Menü öffnen
        final popupMenu = find.byType(PopupMenuButton);
        await tester.tap(popupMenu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
      }

      // Felder für Nextcloud ausfüllen
      await tester.enterText(find.widgetWithText(TextFormField, 'Server-URL'), 'https://nextcloud.example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Benutzername'), 'testuser');
      await tester.enterText(find.widgetWithText(TextFormField, 'App-Passwort'), 'app-pass');

      // Verbindung testen
      await tester.tap(find.text('Verbindung testen'));
      await tester.pumpAndSettle();

      // Erwartung: Erfolgsmeldung (Snackbar)
      expect(find.text('Verbindung erfolgreich!'), findsWidgets);
    });
  });
}
