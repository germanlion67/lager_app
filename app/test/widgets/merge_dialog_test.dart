// test/widgets/merge_dialog_test.dart
//
// T-004: Widget-Tests für den _MergeDialog in ConflictResolutionScreen.
//
// Strategie:
// - _MergeDialog ist private → wird über den "Manuell zusammenführen"-Button
//   im ConflictResolutionScreen geöffnet (identisch zum echten Nutzerfluss).
// - MockSyncService aus test/mocks/sync_service_mocks.mocks.dart.
// - setSurfaceSize(1024×900) für Side-by-Side-Karten (wie T-001.5).
// - Alle Felder (Name, Menge, Ort, Fach, Beschreibung, Bild) getestet.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:lager_app/models/artikel_model.dart';
import 'package:lager_app/screens/conflict_resolution_screen.dart';

import '../mocks/sync_service_mocks.mocks.dart';

// ============================================================
// HILFSFUNKTIONEN
// ============================================================

Artikel _makeArtikel({
  String name = 'Widerstand 10kΩ',
  int menge = 100,
  String ort = 'Regal A',
  String fach = '3',
  String beschreibung = 'Metallschicht 1%',
  String bildPfad = '',
  String uuid = 'merge-test-uuid',
  int? updatedAt,
}) {
  return Artikel(
    name: name,
    artikelnummer: 1042,
    menge: menge,
    ort: ort,
    fach: fach,
    beschreibung: beschreibung,
    bildPfad: bildPfad,
    erstelltAm: DateTime(2026, 1, 1),
    aktualisiertAm: DateTime(2026, 4, 1),
    uuid: uuid,
    updatedAt: updatedAt ?? DateTime(2026, 4, 1).millisecondsSinceEpoch,
  );
}

ConflictData _makeConflict({
  Artikel? local,
  Artikel? remote,
}) {
  return ConflictData(
    localVersion: local ??
        _makeArtikel(
          name: 'Lokal-Name',
          menge: 150,
          ort: 'Lager A',
          fach: '3',
          beschreibung: 'Lokale Beschreibung',
        ),
    remoteVersion: remote ??
        _makeArtikel(
          name: 'Remote-Name',
          menge: 80,
          ort: 'Lager B',
          fach: '7',
          beschreibung: 'Remote Beschreibung',
        ),
    conflictReason: 'Gleichzeitige Bearbeitung',
    detectedAt: DateTime(2026, 4, 2, 14, 30),
  );
}

// ============================================================
// TESTS
// ============================================================

void main() {
  late MockSyncService mockSyncService;

  /// Pumpt den ConflictResolutionScreen und öffnet den MergeDialog.
  Future<void> pumpAndOpenMergeDialog(
    WidgetTester tester,
    ConflictData conflict,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ConflictResolutionScreen(
          conflicts: [conflict],
          syncService: mockSyncService,
        ),
      ),
    );

    // MergeDialog öffnen
    await tester.tap(find.text('Manuell zusammenführen'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    mockSyncService = MockSyncService();
    when(
      mockSyncService.applyConflictResolution(
        any,
        any,
        mergedVersion: anyNamed('mergedVersion'),
      ),
    ).thenAnswer((_) async {});
  });

  // ============================================================
  // T-004.1: Dialog-Grundstruktur
  // ============================================================

  group('T-004.1: MergeDialog Grundstruktur', () {
    testWidgets('zeigt Dialog-Titel "Versionen zusammenführen"',
        (tester) async {
      await pumpAndOpenMergeDialog(tester, _makeConflict());

      expect(find.text('Versionen zusammenführen'), findsOneWidget);
    });

    testWidgets('zeigt merge_type Icon im Header', (tester) async {
      await pumpAndOpenMergeDialog(tester, _makeConflict());

      expect(find.byIcon(Icons.merge_type), findsWidgets);
    });

    testWidgets('zeigt Close-Button im Header', (tester) async {
      await pumpAndOpenMergeDialog(tester, _makeConflict());

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('zeigt "Abbrechen"- und "Zusammenführen"-Buttons',
        (tester) async {
      await pumpAndOpenMergeDialog(tester, _makeConflict());

      expect(find.text('Abbrechen'), findsOneWidget);
      expect(find.text('Zusammenführen'), findsOneWidget);
    });

    testWidgets('zeigt alle 5 Feld-Labels', (tester) async {
      await pumpAndOpenMergeDialog(tester, _makeConflict());

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Menge'), findsOneWidget);
      expect(find.text('Ort'), findsOneWidget);
      expect(find.text('Fach'), findsOneWidget);
      expect(find.text('Beschreibung'), findsOneWidget);
    });

    testWidgets('zeigt "Bild wählen:" Label', (tester) async {
      await pumpAndOpenMergeDialog(tester, _makeConflict());

      expect(find.text('Bild wählen:'), findsOneWidget);
    });
  });

  // ============================================================
  // T-004.2: Konflikt-Anzeige (Lokal vs Remote Karten)
  // ============================================================

  group('T-004.2: Konflikt-Anzeige', () {
    testWidgets('zeigt Lokal/Remote-Karten bei unterschiedlichen Werten',
        (tester) async {
      await pumpAndOpenMergeDialog(tester, _makeConflict());

      // Jedes Feld mit Unterschied zeigt "Lokal:" und "Remote:" Labels
      expect(find.text('Lokal:'), findsWidgets);
      expect(find.text('Remote:'), findsWidgets);
    });

    testWidgets('zeigt Warning-Icon bei Feldern mit Unterschied',
        (tester) async {
      await pumpAndOpenMergeDialog(tester, _makeConflict());

      // Alle 5 Felder haben Unterschiede → 5 Warning-Icons im MergeDialog
      // (plus das Warning-Icon im ConflictResolutionScreen Header)
      expect(find.byIcon(Icons.warning), findsWidgets);
    });

    testWidgets('zeigt keine Lokal/Remote-Karten bei identischen Werten',
        (tester) async {
      final conflict = _makeConflict(
        local: _makeArtikel(name: 'Gleich', menge: 100, ort: 'A', fach: '1',
            beschreibung: 'Gleich',),
        remote: _makeArtikel(name: 'Gleich', menge: 100, ort: 'A', fach: '1',
            beschreibung: 'Gleich',),
      );
      await pumpAndOpenMergeDialog(tester, conflict);

      // Keine "Lokal:"/"Remote:"-Labels im MergeDialog (nur im Hauptscreen)
      // MergeDialog zeigt nur TextFields ohne Vergleichskarten
      final mergeDialogFinder = find.byType(Dialog);
      expect(mergeDialogFinder, findsOneWidget);

      // In der Dialog-Subtree sollte kein "Lokal:" Text sein
      expect(
        find.descendant(
          of: mergeDialogFinder,
          matching: find.text('Lokal:'),
        ),
        findsNothing,
      );
    });

    testWidgets('zeigt lokale Werte in den TextFields (Initialwerte)',
        (tester) async {
      final conflict = _makeConflict(
        local: _makeArtikel(
          name: 'Lokaler Artikel',
          menge: 42,
          ort: 'Werkstatt',
          fach: 'Schublade 5',
          beschreibung: 'Meine Beschreibung',
        ),
      );
      await pumpAndOpenMergeDialog(tester, conflict);

      // TextFields werden mit lokalen Werten initialisiert
      expect(find.text('Lokaler Artikel'), findsWidgets);
      expect(find.text('42'), findsWidgets);
      expect(find.text('Werkstatt'), findsWidgets);
      expect(find.text('Schublade 5'), findsWidgets);
      expect(find.text('Meine Beschreibung'), findsWidgets);
    });
  });

  // ============================================================
  // T-004.3: Feld-Auswahl (Lokal/Remote Buttons)
  // ============================================================

    testWidgets('Tap auf "Remote"-Button setzt Remote-Wert ins TextField',
        (tester) async {
      // Nur Ort unterschiedlich → genau 1 "Remote"-Button
      final conflict = _makeConflict(
        local: _makeArtikel(
          name: 'Gleich', menge: 100, ort: 'Lager A',
          fach: '1', beschreibung: 'Gleich',
        ),
        remote: _makeArtikel(
          name: 'Gleich', menge: 100, ort: 'Lager B',
          fach: '1', beschreibung: 'Gleich',
        ),
      );
      await pumpAndOpenMergeDialog(tester, conflict);

      final remoteButton = find.widgetWithText(TextButton, 'Remote');
      expect(remoteButton, findsOneWidget);
      await tester.tap(remoteButton);
      await tester.pump();

      expect(find.text('Lager B'), findsWidgets);
    });

  // ============================================================
  // T-004.4: Bild-Auswahl
  // ============================================================

  group('T-004.4: Bild-Auswahl', () {
    testWidgets('zeigt "Lokal" und "Remote" Radio-Optionen für Bild',
        (tester) async {
      final conflict = _makeConflict(
        local: _makeArtikel(bildPfad: '/local/bild.jpg'),
        remote: _makeArtikel(bildPfad: '/remote/bild.jpg'),
      );
      await pumpAndOpenMergeDialog(tester, conflict);

      // Scroll zum Bild-Bereich
      await tester.ensureVisible(find.text('Bild wählen:'));

      // Lokal und Remote als Bild-Optionen
      // Die _buildImageRadioOption zeigt "Lokal" und "Remote" als title
      // Diese sind innerhalb des Dialogs
      final dialogFinder = find.byType(Dialog);
      final lokalBild = find.descendant(
        of: dialogFinder,
        matching: find.text('Vorhanden'),
      );
      expect(lokalBild, findsWidgets); // Beide haben Bild → 2x "Vorhanden"
    });

    testWidgets('zeigt "Kein Bild" wenn Bildpfad leer', (tester) async {
      final conflict = _makeConflict(
        local: _makeArtikel(bildPfad: ''),
        remote: _makeArtikel(bildPfad: '/remote/bild.jpg'),
      );
      await pumpAndOpenMergeDialog(tester, conflict);

      await tester.ensureVisible(find.text('Bild wählen:'));

      expect(find.text('Kein Bild'), findsOneWidget);
      expect(find.text('Vorhanden'), findsOneWidget);
    });

    testWidgets('Lokal-Bild ist initial ausgewählt', (tester) async {
      final conflict = _makeConflict(
        local: _makeArtikel(bildPfad: '/local/bild.jpg'),
        remote: _makeArtikel(bildPfad: '/remote/bild.jpg'),
      );
      await pumpAndOpenMergeDialog(tester, conflict);

      await tester.ensureVisible(find.text('Bild wählen:'));

      // Der ausgewählte Radio-Button hat ein check_circle Icon
      // oder einen gefüllten Container — prüfen wir über den
      // Border-Stil (selected hat strokeWidthMedium)
      // Einfacher: Prüfe ob Icons.circle (der innere Punkt) vorhanden ist
      final dialogFinder = find.byType(Dialog);
      expect(
        find.descendant(
          of: dialogFinder,
          matching: find.byIcon(Icons.circle),
        ),
        findsOneWidget, // Nur eine Option ist selected
      );
    });
  });

  // ============================================================
  // T-004.5: Zusammenführen-Aktion
  // ============================================================

    testWidgets('leerer Name wird beim Zusammenführen akzeptiert',
        (tester) async {
      // Nur Name unterschiedlich → 1 "Remote"-Button, Name-TextField klar identifizierbar
      final conflict = _makeConflict(
        local: _makeArtikel(
          uuid: 'empty-name-uuid', name: 'Lokal-Name',
          menge: 100, ort: 'A', fach: '1', beschreibung: 'Gleich',
        ),
        remote: _makeArtikel(
          uuid: 'empty-name-uuid', name: 'Remote-Name',
          menge: 100, ort: 'A', fach: '1', beschreibung: 'Gleich',
        ),
      );
      await pumpAndOpenMergeDialog(tester, conflict);

      // Erstes TextField im Dialog = Name
      final textFields = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(textFields.first, '');
      await tester.pump();

      await tester.tap(find.text('Zusammenführen'));
      await tester.pumpAndSettle();

      expect(find.text('Versionen zusammenführen'), findsNothing);
    });

  // ============================================================
  // T-004.6: Dialog schließen
  // ============================================================

  group('T-004.6: Dialog schließen', () {
    testWidgets('"Abbrechen" schließt Dialog ohne Resolution zu setzen',
        (tester) async {
      await pumpAndOpenMergeDialog(tester, _makeConflict());

      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      // Dialog geschlossen
      expect(find.text('Versionen zusammenführen'), findsNothing);

      // "Auflösen"-Button sollte weiterhin deaktiviert sein
      // (keine Resolution wurde gesetzt)
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Auflösen'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Close-Icon schließt Dialog ohne Resolution zu setzen',
        (tester) async {
      await pumpAndOpenMergeDialog(tester, _makeConflict());

      // Close-Button im Dialog-Header
      final dialogFinder = find.byType(Dialog);
      final closeButton = find.descendant(
        of: dialogFinder,
        matching: find.byIcon(Icons.close),
      );
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.text('Versionen zusammenführen'), findsNothing);

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Auflösen'),
      );
      expect(button.onPressed, isNull);
    });
  });

  // ============================================================
  // T-004.7: Menge-Feld Sonderfälle
  // ============================================================

    testWidgets('Remote-Menge kann per Button übernommen werden',
        (tester) async {
      // Nur Menge unterschiedlich → genau 1 "Remote"-Button
      final conflict = _makeConflict(
        local: _makeArtikel(
          uuid: 'menge-remote', name: 'Gleich', menge: 10,
          ort: 'A', fach: '1', beschreibung: 'Gleich',
        ),
        remote: _makeArtikel(
          uuid: 'menge-remote', name: 'Gleich', menge: 999,
          ort: 'A', fach: '1', beschreibung: 'Gleich',
        ),
      );
      await pumpAndOpenMergeDialog(tester, conflict);

      final remoteButton = find.widgetWithText(TextButton, 'Remote');
      expect(remoteButton, findsOneWidget);
      await tester.tap(remoteButton);
      await tester.pump();

      await tester.tap(find.text('Zusammenführen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Auflösen'));
      await tester.pumpAndSettle();

      final captured = verify(
        mockSyncService.applyConflictResolution(
          any,
          ConflictResolution.merge,
          mergedVersion: captureAnyNamed('mergedVersion'),
        ),
      ).captured;

      final merged = captured.first as Artikel;
      expect(merged.menge, 999);
    });
}