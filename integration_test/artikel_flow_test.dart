//.../integration_test/artikel_flow_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lager_app/main.dart' as app;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Artikel-Flow: List, Erfassen und Detailansicht', () {
    testWidgets('Artikel erfassen, anzeigen, bearbeiten und löschen', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 1. Artikelliste muss sichtbar sein
      expect(find.text('Artikelliste'), findsOneWidget);

      // 2. Artikel erfassen starten (Floating Action Button)
      final fab = find.byIcon(Icons.add);
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // 3. Felder ausfüllen und speichern
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'IntegrationTestArtikel');
      await tester.enterText(find.widgetWithText(TextFormField, 'Beschreibung'), 'Beschreibung');
      await tester.enterText(find.widgetWithText(TextFormField, 'Ort'), 'Lager');
      await tester.enterText(find.widgetWithText(TextFormField, 'Fach'), 'B2');
      await tester.enterText(find.widgetWithText(TextFormField, 'Menge'), '7');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      // 4. Artikel erscheint in der Liste
      expect(find.text('IntegrationTestArtikel'), findsOneWidget);

      // 5. Artikel Detailansicht öffnen
      await tester.tap(find.text('IntegrationTestArtikel'));
      await tester.pumpAndSettle();
      expect(find.text('Beschreibung'), findsOneWidget);

      // 6. Artikel bearbeiten (Beschreibung ändern)
      final editButton = find.byIcon(Icons.edit);
      if (editButton.evaluate().isNotEmpty) {
        await tester.tap(editButton);
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextFormField, 'Beschreibung'), 'Neue Beschreibung');
        await tester.tap(find.text('Speichern'));
        await tester.pumpAndSettle();
      }

      // 7. Zurück in der Liste: Änderung sichtbar?
      expect(find.text('IntegrationTestArtikel'), findsOneWidget);
      expect(find.text('Neue Beschreibung'), findsOneWidget);

      // 8. Artikel löschen
      final deleteButton = find.byIcon(Icons.delete);
      if (deleteButton.evaluate().isNotEmpty) {
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();
        final confirmDelete = find.text('Bestätigen');
        if (confirmDelete.evaluate().isNotEmpty) {
          await tester.tap(confirmDelete);
          await tester.pumpAndSettle();
        }
      }

      // 9. Artikel verschwunden?
      expect(find.text('IntegrationTestArtikel'), findsNothing);
    });
  });
}
