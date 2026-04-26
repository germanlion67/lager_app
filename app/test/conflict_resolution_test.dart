// test/conflict_resolution_test.dart
//
// T-001: Tests für Konfliktdaten und Konfliktauflösungs-UI.
//
// Strategie:
// - ConflictData und ConflictResolution werden direkt getestet.
// - ConflictResolutionScreen wird per Widget-Tests mit gemocktem SyncService geprüft.
// - Fokus: Auswahl von useLocal/useRemote/merge/skip,
//   Fortschrittsanzeige bei mehreren Konflikten und Ergebnisübergabe beim Merge.
//
// Hinweis:
// - Die eigentliche Konflikterkennung im Sync-Layer wird in den spezifischen
//   Sync-/Konflikttests separat geprüft und gehört nicht in diese Datei.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:lager_app/models/artikel_model.dart';
import 'package:lager_app/screens/conflict_resolution_screen.dart';


import 'mocks/sync_service_mocks.mocks.dart';

// ============================================================
// HILFSFUNKTIONEN
// ============================================================

/// Erzeugt einen Test-Artikel mit sinnvollen Defaults.
Artikel _makeArtikel({
  String name = 'Widerstand 10kΩ',
  int? artikelnummer = 1042,
  int menge = 100,
  String ort = 'Regal A',
  String fach = '3',
  String beschreibung = 'Metallschicht 1%',
  String bildPfad = '',
  String? remoteBildPfad,
  String uuid = 'test-uuid-001',
  int? updatedAt,
  bool deleted = false,
  String? deviceId,
  String? etag,
}) {
  return Artikel(
    name: name,
    artikelnummer: artikelnummer,
    menge: menge,
    ort: ort,
    fach: fach,
    beschreibung: beschreibung,
    bildPfad: bildPfad,
    remoteBildPfad: remoteBildPfad,
    erstelltAm: DateTime(2026, 1, 1),
    aktualisiertAm: DateTime(2026, 4, 1),
    uuid: uuid,
    updatedAt: updatedAt ?? DateTime(2026, 4, 1).millisecondsSinceEpoch,
    deleted: deleted,
    deviceId: deviceId,
    etag: etag,
  );
}

/// Erzeugt ein ConflictData-Paar aus lokaler und Server-Version.
ConflictData _makeConflict({
  Artikel? local,
  Artikel? remote,
  String reason = 'Gleichzeitige Bearbeitung',
}) {
  return ConflictData(
    localVersion: local ?? _makeArtikel(menge: 150, fach: '3'),
    remoteVersion: remote ?? _makeArtikel(menge: 120, fach: '5'),
    conflictReason: reason,
    detectedAt: DateTime(2026, 4, 2, 14, 30),
  );
}

// ============================================================
// TESTS
// ============================================================

void main() {
  // ============================================================
  // T-001.1: ConflictData Tests
  // ============================================================

  group('T-001.1: ConflictData', () {
    test('Konstruktor setzt alle Felder korrekt', () {
      final local = _makeArtikel(name: 'Lokal');
      final remote = _makeArtikel(name: 'Remote');
      final now = DateTime(2026, 4, 2, 14, 30);

      final conflict = ConflictData(
        localVersion: local,
        remoteVersion: remote,
        conflictReason: 'Testgrund',
        detectedAt: now,
      );

      expect(conflict.localVersion.name, 'Lokal');
      expect(conflict.remoteVersion.name, 'Remote');
      expect(conflict.conflictReason, 'Testgrund');
      expect(conflict.detectedAt, now);
    });

    test('localVersion und remoteVersion sind unabhängig', () {
      final local = _makeArtikel(name: 'Lokal', menge: 100);
      final remote = _makeArtikel(name: 'Remote', menge: 200);
      final conflict = _makeConflict(local: local, remote: remote);

      expect(conflict.localVersion.name, 'Lokal');
      expect(conflict.remoteVersion.name, 'Remote');
      expect(conflict.localVersion.menge, 100);
      expect(conflict.remoteVersion.menge, 200);
      expect(conflict.localVersion.uuid, conflict.remoteVersion.uuid);
    });

    test('conflictReason wird korrekt gespeichert', () {
      final conflict = _makeConflict(reason: 'Lokale Version neuer (5m)');
      expect(conflict.conflictReason, 'Lokale Version neuer (5m)');
    });

    test('detectedAt wird korrekt gespeichert', () {
      final timestamp = DateTime(2026, 3, 15, 10, 30, 45);
      final conflict = ConflictData(
        localVersion: _makeArtikel(),
        remoteVersion: _makeArtikel(),
        conflictReason: 'Test',
        detectedAt: timestamp,
      );

      expect(conflict.detectedAt, timestamp);
      expect(conflict.detectedAt.year, 2026);
      expect(conflict.detectedAt.month, 3);
      expect(conflict.detectedAt.day, 15);
    });

    test('kann mit identischen Artikeln erstellt werden', () {
      final artikel = _makeArtikel();
      final conflict = _makeConflict(local: artikel, remote: artikel);
      expect(conflict.localVersion, conflict.remoteVersion);
    });

    test('kann mit null-Artikelnummer erstellt werden', () {
      final conflict = _makeConflict(
        local: _makeArtikel(artikelnummer: null),
        remote: _makeArtikel(artikelnummer: 1042),
      );
      expect(conflict.localVersion.artikelnummer, isNull);
      expect(conflict.remoteVersion.artikelnummer, 1042);
    });

    test('kann mit leerem Bildpfad erstellt werden', () {
      final conflict = _makeConflict(
        local: _makeArtikel(bildPfad: ''),
        remote: _makeArtikel(bildPfad: '', remoteBildPfad: null),
      );
      expect(conflict.localVersion.bildPfad, isEmpty);
      expect(conflict.remoteVersion.remoteBildPfad, isNull);
    });

    test('kann mit Bildpfaden erstellt werden', () {
      final conflict = _makeConflict(
        local: _makeArtikel(bildPfad: '/path/to/local.jpg'),
        remote: _makeArtikel(remoteBildPfad: 'attachments/uuid/remote.jpg'),
      );
      expect(conflict.localVersion.bildPfad, '/path/to/local.jpg');
      expect(
        conflict.remoteVersion.remoteBildPfad,
        'attachments/uuid/remote.jpg',
      );
    });

    test('kann mit deleted-Flag erstellt werden', () {
      final conflict = _makeConflict(
        local: _makeArtikel(deleted: true),
        remote: _makeArtikel(deleted: false),
      );
      expect(conflict.localVersion.deleted, true);
      expect(conflict.remoteVersion.deleted, false);
    });

    test('kann mit verschiedenen deviceIds erstellt werden', () {
      final conflict = _makeConflict(
        local: _makeArtikel(deviceId: 'device-A'),
        remote: _makeArtikel(deviceId: 'device-B'),
      );
      expect(conflict.localVersion.deviceId, 'device-A');
      expect(conflict.remoteVersion.deviceId, 'device-B');
    });

    test('kann mit verschiedenen updatedAt-Werten erstellt werden', () {
      final earlier = DateTime(2026, 4, 1, 10, 0).millisecondsSinceEpoch;
      final later = DateTime(2026, 4, 1, 14, 0).millisecondsSinceEpoch;
      final conflict = _makeConflict(
        local: _makeArtikel(updatedAt: later),
        remote: _makeArtikel(updatedAt: earlier),
      );
      expect(
        conflict.localVersion.updatedAt,
        greaterThan(conflict.remoteVersion.updatedAt),
      );
    });
  });

  // ============================================================
  // T-001.2: ConflictResolution Enum
  // ============================================================

  group('T-001.2: ConflictResolution Enum', () {
    test('hat alle erwarteten Werte', () {
      expect(
        ConflictResolution.values,
        containsAll([
          ConflictResolution.useLocal,
          ConflictResolution.useRemote,
          ConflictResolution.merge,
          ConflictResolution.skip,
        ]),
      );
    });

    test('hat genau 4 Werte', () {
      expect(ConflictResolution.values.length, 4);
    });

    test('name-Property gibt korrekten String zurück', () {
      expect(ConflictResolution.useLocal.name, 'useLocal');
      expect(ConflictResolution.useRemote.name, 'useRemote');
      expect(ConflictResolution.merge.name, 'merge');
      expect(ConflictResolution.skip.name, 'skip');
    });

    test('index-Property ist korrekt', () {
      expect(ConflictResolution.useLocal.index, 0);
      expect(ConflictResolution.useRemote.index, 1);
      expect(ConflictResolution.merge.index, 2);
      expect(ConflictResolution.skip.index, 3);
    });

    test('kann per name aufgelöst werden', () {
      expect(
        ConflictResolution.values.byName('useLocal'),
        ConflictResolution.useLocal,
      );
      expect(
        ConflictResolution.values.byName('useRemote'),
        ConflictResolution.useRemote,
      );
      expect(
        ConflictResolution.values.byName('merge'),
        ConflictResolution.merge,
      );
      expect(
        ConflictResolution.values.byName('skip'),
        ConflictResolution.skip,
      );
    });

    test('wirft bei ungültigem name', () {
      expect(
        () => ConflictResolution.values.byName('invalid'),
        throwsArgumentError,
      );
    });
  });

  // ============================================================
  // T-001.4: Konflikt-Grund-Szenarien (Daten-Ebene, kein Mock)
  // ============================================================

  group('T-001.4: Konflikt-Grund-Szenarien', () {
    test('conflictReason für gleichzeitige Bearbeitung', () {
      final conflict = _makeConflict(reason: 'Gleichzeitige Bearbeitung');
      expect(conflict.conflictReason, contains('Gleichzeitig'));
    });

    test('conflictReason für zeitnahe Bearbeitung', () {
      final conflict = _makeConflict(
        reason: 'Zeitnahe Bearbeitung (30s Unterschied)',
      );
      expect(conflict.conflictReason, contains('Zeitnahe'));
      expect(conflict.conflictReason, contains('30s'));
    });

    test('conflictReason für lokale Version neuer', () {
      final conflict = _makeConflict(reason: 'Lokale Version neuer (5m)');
      expect(conflict.conflictReason, contains('Lokale'));
      expect(conflict.conflictReason, contains('neuer'));
    });

    test('conflictReason für remote Version neuer', () {
      final conflict = _makeConflict(reason: 'Remote Version neuer (2h)');
      expect(conflict.conflictReason, contains('Remote'));
      expect(conflict.conflictReason, contains('neuer'));
    });

    test('conflictReason kann beliebiger String sein', () {
      final conflict = _makeConflict(reason: 'Benutzerdefinierter Grund');
      expect(conflict.conflictReason, 'Benutzerdefinierter Grund');
    });
  });

  // ============================================================
  // T-001.5: ConflictResolutionScreen Widget-Tests
  // ============================================================

  group('T-001.5: ConflictResolutionScreen Widget-Tests', () {
    late MockSyncService mockSyncService;

    Future<void> pumpConflictScreen(
      WidgetTester tester,
      List<ConflictData> conflicts,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1024, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: ConflictResolutionScreen(
            conflicts: conflicts,
            syncService: mockSyncService,
          ),
        ),
      );
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

    testWidgets('zeigt "Keine Konflikte" bei leerer Liste', (tester) async {
      await pumpConflictScreen(tester, []);

      expect(find.text('Keine Konflikte gefunden!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('zeigt AppBar mit Titel "Konflikte" bei leerer Liste',
        (tester) async {
      await pumpConflictScreen(tester, []);

      expect(find.text('Konflikte'), findsOneWidget);
    });

    testWidgets('zeigt Konflikt-Titel mit Artikelname', (tester) async {
      final conflict = _makeConflict(
        local: _makeArtikel(name: 'Kondensator 100µF'),
        remote: _makeArtikel(name: 'Kondensator 100µF', menge: 50),
      );
      await pumpConflictScreen(tester, [conflict]);

      expect(find.textContaining('Kondensator 100µF'), findsWidgets);
    });

    testWidgets('zeigt Fortschrittsanzeige "(1/1)"', (tester) async {
      await pumpConflictScreen(tester, [_makeConflict()]);

      expect(find.textContaining('1/1'), findsOneWidget);
    });

    testWidgets('zeigt LinearProgressIndicator', (tester) async {
      await pumpConflictScreen(tester, [_makeConflict()]);

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('zeigt conflictReason im UI', (tester) async {
      final conflict = _makeConflict(reason: 'Gleichzeitige Bearbeitung');
      await pumpConflictScreen(tester, [conflict]);

      expect(find.textContaining('Gleichzeitige Bearbeitung'), findsOneWidget);
    });

    testWidgets('zeigt "Lokale Version" und "Remote Version" Karten',
        (tester) async {
      await pumpConflictScreen(tester, [_makeConflict()]);

      expect(find.text('Lokale Version'), findsOneWidget);
      expect(find.text('Remote Version'), findsOneWidget);
    });

    testWidgets('"Auflösen"-Button ist initial deaktiviert', (tester) async {
      await pumpConflictScreen(tester, [_makeConflict()]);

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Auflösen'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('"Überspringen" aktiviert den "Auflösen"-Button',
        (tester) async {
      await pumpConflictScreen(tester, [_makeConflict()]);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Überspringen'));
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Auflösen'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Tap auf "Lokale Version"-Karte aktiviert "Auflösen"-Button',
        (tester) async {
      await pumpConflictScreen(tester, [_makeConflict()]);

      await tester.tap(find.text('Lokale Version'));
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Auflösen'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Tap auf "Remote Version"-Karte aktiviert "Auflösen"-Button',
        (tester) async {
      await pumpConflictScreen(tester, [_makeConflict()]);

      await tester.tap(find.text('Remote Version'));
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Auflösen'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('"Auflösen" mit useLocal ruft applyConflictResolution auf',
        (tester) async {
      final conflict = _makeConflict(
        local: _makeArtikel(uuid: 'uuid-widget-test'),
        remote: _makeArtikel(uuid: 'uuid-widget-test', menge: 50),
      );
      await pumpConflictScreen(tester, [conflict]);

      await tester.tap(find.text('Lokale Version'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Auflösen'));
      await tester.pumpAndSettle();

      verify(
        mockSyncService.applyConflictResolution(
          any,
          ConflictResolution.useLocal,
          mergedVersion: anyNamed('mergedVersion'),
        ),
      ).called(1);
    });

    testWidgets('"Auflösen" mit useRemote ruft applyConflictResolution auf',
        (tester) async {
      final conflict = _makeConflict(
        local: _makeArtikel(uuid: 'uuid-widget-test'),
        remote: _makeArtikel(uuid: 'uuid-widget-test', menge: 50),
      );
      await pumpConflictScreen(tester, [conflict]);

      await tester.tap(find.text('Remote Version'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Auflösen'));
      await tester.pumpAndSettle();

      verify(
        mockSyncService.applyConflictResolution(
          any,
          ConflictResolution.useRemote,
          mergedVersion: anyNamed('mergedVersion'),
        ),
      ).called(1);
    });

    testWidgets('"Auflösen" mit skip ruft applyConflictResolution NICHT auf',
        (tester) async {
      await pumpConflictScreen(tester, [_makeConflict()]);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Überspringen'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Auflösen'));
      await tester.pumpAndSettle();

      verifyNever(mockSyncService.applyConflictResolution(any, any));
    });

    testWidgets(
      'Merge übergibt bearbeitete mergedVersion an applyConflictResolution',
      (tester) async {
        final conflict = _makeConflict(
          local: _makeArtikel(
            uuid: 'uuid-merge-test',
            name: 'Lokaler Name',
            menge: 10,
          ),
          remote: _makeArtikel(
            uuid: 'uuid-merge-test',
            name: 'Remote Name',
            menge: 20,
          ),
        );

        await pumpConflictScreen(tester, [conflict]);

        await tester.tap(find.text('Manuell zusammenführen'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField).first,
          'Gemergter Name',
        );
        await tester.enterText(
          find.byType(TextField).at(1),
          '42',
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Zusammenführen'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Auflösen'));
        await tester.pumpAndSettle();

        final verification = verify(
          mockSyncService.applyConflictResolution(
            any,
            ConflictResolution.merge,
            mergedVersion: captureAnyNamed('mergedVersion'),
          ),
        )..called(1);

        final mergedArtikel = verification.captured.single as Artikel;
        expect(mergedArtikel.uuid, equals('uuid-merge-test'));
        expect(mergedArtikel.name, equals('Gemergter Name'));
        expect(mergedArtikel.menge, equals(42));
      },
    );

    testWidgets('Screen popt nach Auflösen mit resolved/skipped Map',
        (tester) async {
      final conflict = _makeConflict(
        local: _makeArtikel(uuid: 'uuid-pop-test'),
        remote: _makeArtikel(uuid: 'uuid-pop-test', menge: 50),
      );

      await tester.binding.setSurfaceSize(const Size(1024, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Object? poppedResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                poppedResult = await Navigator.of(ctx).push(
                  MaterialPageRoute<Object>(
                    builder: (_) => ConflictResolutionScreen(
                      conflicts: [conflict],
                      syncService: mockSyncService,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lokale Version'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Auflösen'));
      await tester.pumpAndSettle();

      expect(poppedResult, isA<Map<String, dynamic>>());
      final resultMap = poppedResult! as Map<String, dynamic>;
      expect(resultMap['resolved'], 1);
      expect(resultMap['skipped'], 0);
    });

    testWidgets('zeigt "(1/2)" bei zwei Konflikten', (tester) async {
      final conflicts = [
        _makeConflict(
          local: _makeArtikel(uuid: 'uuid-1', name: 'Artikel 1'),
          remote: _makeArtikel(uuid: 'uuid-1', menge: 50),
        ),
        _makeConflict(
          local: _makeArtikel(uuid: 'uuid-2', name: 'Artikel 2'),
          remote: _makeArtikel(uuid: 'uuid-2', menge: 75),
        ),
      ];
      await pumpConflictScreen(tester, conflicts);

      expect(find.textContaining('1/2'), findsOneWidget);
    });

    testWidgets('"Weiter"-Button erscheint bei mehreren Konflikten',
        (tester) async {
      final conflicts = [
        _makeConflict(
          local: _makeArtikel(uuid: 'uuid-1'),
          remote: _makeArtikel(uuid: 'uuid-1', menge: 50),
        ),
        _makeConflict(
          local: _makeArtikel(uuid: 'uuid-2'),
          remote: _makeArtikel(uuid: 'uuid-2', menge: 75),
        ),
      ];
      await pumpConflictScreen(tester, conflicts);

      expect(find.text('Weiter'), findsOneWidget);
      expect(find.text('Auflösen'), findsNothing);
    });

    testWidgets('Navigation zu Konflikt 2 nach "Weiter"', (tester) async {
      final conflicts = [
        _makeConflict(
          local: _makeArtikel(uuid: 'uuid-1', name: 'Erster Artikel'),
          remote: _makeArtikel(uuid: 'uuid-1', menge: 50),
        ),
        _makeConflict(
          local: _makeArtikel(uuid: 'uuid-2', name: 'Zweiter Artikel'),
          remote: _makeArtikel(uuid: 'uuid-2', menge: 75),
        ),
      ];
      await pumpConflictScreen(tester, conflicts);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Überspringen'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Weiter'));
      await tester.pump();

      expect(find.textContaining('2/2'), findsOneWidget);
      expect(find.textContaining('Zweiter Artikel'), findsWidgets);
    });

    testWidgets('Hilfe-Dialog öffnet sich bei Help-Icon-Tap', (tester) async {
      await pumpConflictScreen(tester, [_makeConflict()]);

      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pumpAndSettle();

      expect(find.text('Konfliktauflösung Hilfe'), findsOneWidget);
      expect(find.text('Verstanden'), findsOneWidget);
    });

    testWidgets('Hilfe-Dialog schließt sich nach "Verstanden"', (tester) async {
      await pumpConflictScreen(tester, [_makeConflict()]);

      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verstanden'));
      await tester.pumpAndSettle();

      expect(find.text('Konfliktauflösung Hilfe'), findsNothing);
    });

    testWidgets('"Manuell zusammenführen"-Button öffnet MergeDialog',
        (tester) async {
      await pumpConflictScreen(tester, [_makeConflict()]);

      await tester.tap(find.text('Manuell zusammenführen'));
      await tester.pumpAndSettle();

      expect(find.text('Versionen zusammenführen'), findsOneWidget);
    });
  });

  // ============================================================
  // T-001.extra: Feld-Vergleiche über Artikel-Properties
  // ============================================================

  group('T-001.extra: Feld-Vergleiche über Artikel-Properties', () {
    test('erkennt Menge-Unterschied', () {
      final conflict = _makeConflict(
        local: _makeArtikel(menge: 150),
        remote: _makeArtikel(menge: 120),
      );
      expect(conflict.localVersion.menge, isNot(conflict.remoteVersion.menge));
      expect(conflict.localVersion.menge, 150);
      expect(conflict.remoteVersion.menge, 120);
    });

    test('erkennt Name-Unterschied', () {
      final conflict = _makeConflict(
        local: _makeArtikel(name: 'Widerstand 10kΩ'),
        remote: _makeArtikel(name: 'Widerstand 22kΩ'),
      );
      expect(conflict.localVersion.name, isNot(conflict.remoteVersion.name));
    });

    test('erkennt Ort-Unterschied', () {
      final conflict = _makeConflict(
        local: _makeArtikel(ort: 'Regal A'),
        remote: _makeArtikel(ort: 'Regal B'),
      );
      expect(conflict.localVersion.ort, 'Regal A');
      expect(conflict.remoteVersion.ort, 'Regal B');
    });

    test('erkennt Fach-Unterschied', () {
      final conflict = _makeConflict(
        local: _makeArtikel(fach: '3'),
        remote: _makeArtikel(fach: '5'),
      );
      expect(conflict.localVersion.fach, '3');
      expect(conflict.remoteVersion.fach, '5');
    });

    test('erkennt Beschreibung-Unterschied', () {
      final conflict = _makeConflict(
        local: _makeArtikel(beschreibung: 'Alt'),
        remote: _makeArtikel(beschreibung: 'Neu'),
      );
      expect(
        conflict.localVersion.beschreibung,
        isNot(conflict.remoteVersion.beschreibung),
      );
    });

    test('erkennt keine Unterschiede bei identischen Artikeln', () {
      final artikel = _makeArtikel();
      final conflict = _makeConflict(local: artikel, remote: artikel);
      expect(conflict.localVersion.name, conflict.remoteVersion.name);
      expect(conflict.localVersion.menge, conflict.remoteVersion.menge);
      expect(conflict.localVersion.ort, conflict.remoteVersion.ort);
      expect(conflict.localVersion.fach, conflict.remoteVersion.fach);
      expect(
        conflict.localVersion.beschreibung,
        conflict.remoteVersion.beschreibung,
      );
    });

    test('erkennt mehrere Unterschiede gleichzeitig', () {
      final conflict = _makeConflict(
        local: _makeArtikel(name: 'A', menge: 10, fach: '1'),
        remote: _makeArtikel(name: 'B', menge: 20, fach: '2'),
      );
      int diffCount = 0;
      if (conflict.localVersion.name != conflict.remoteVersion.name) diffCount++;
      if (conflict.localVersion.menge != conflict.remoteVersion.menge) {
        diffCount++;
      }
      if (conflict.localVersion.fach != conflict.remoteVersion.fach) diffCount++;
      expect(diffCount, 3);
    });

    test('Bild-Konflikt: lokal vorhanden, remote nicht', () {
      final conflict = _makeConflict(
        local: _makeArtikel(bildPfad: '/path/to/image.jpg'),
        remote: _makeArtikel(bildPfad: '', remoteBildPfad: null),
      );
      final localHasImage = conflict.localVersion.bildPfad.isNotEmpty;
      final remoteHasImage =
          (conflict.remoteVersion.remoteBildPfad ?? '').isNotEmpty;
      expect(localHasImage, true);
      expect(remoteHasImage, false);
      expect(localHasImage != remoteHasImage, true);
    });

    test('Bild-Konflikt: remote vorhanden, lokal nicht', () {
      final conflict = _makeConflict(
        local: _makeArtikel(bildPfad: ''),
        remote: _makeArtikel(remoteBildPfad: 'attachments/uuid/bild.jpg'),
      );
      final localHasImage = conflict.localVersion.bildPfad.isNotEmpty;
      final remoteHasImage =
          (conflict.remoteVersion.remoteBildPfad ?? '').isNotEmpty;
      expect(localHasImage, false);
      expect(remoteHasImage, true);
    });

    test('Kein Bild-Konflikt: beide haben Bild', () {
      final conflict = _makeConflict(
        local: _makeArtikel(bildPfad: '/path/to/image.jpg'),
        remote: _makeArtikel(remoteBildPfad: 'attachments/uuid/bild.jpg'),
      );
      final localHasImage = conflict.localVersion.bildPfad.isNotEmpty;
      final remoteHasImage =
          (conflict.remoteVersion.remoteBildPfad ?? '').isNotEmpty;
      expect(localHasImage, true);
      expect(remoteHasImage, true);
      expect(localHasImage != remoteHasImage, false);
    });

    test('Kein Bild-Konflikt: beide haben kein Bild', () {
      final conflict = _makeConflict(
        local: _makeArtikel(bildPfad: ''),
        remote: _makeArtikel(bildPfad: '', remoteBildPfad: null),
      );
      final localHasImage = conflict.localVersion.bildPfad.isNotEmpty;
      final remoteHasImage =
          (conflict.remoteVersion.remoteBildPfad ?? '').isNotEmpty;
      expect(localHasImage, false);
      expect(remoteHasImage, false);
      expect(localHasImage != remoteHasImage, false);
    });
  });

  // ============================================================
  // T-001.extra: ConflictData in Collections
  // ============================================================

  group('T-001.extra: ConflictData in Collections', () {
    test('kann in einer Liste gesammelt werden', () {
      final conflicts = <ConflictData>[
        _makeConflict(
          local: _makeArtikel(uuid: 'uuid-1', name: 'Artikel 1'),
          remote: _makeArtikel(uuid: 'uuid-1', name: 'Artikel 1', menge: 50),
        ),
        _makeConflict(
          local: _makeArtikel(uuid: 'uuid-2', name: 'Artikel 2'),
          remote: _makeArtikel(uuid: 'uuid-2', name: 'Artikel 2', menge: 75),
        ),
        _makeConflict(
          local: _makeArtikel(uuid: 'uuid-3', name: 'Artikel 3'),
          remote: _makeArtikel(uuid: 'uuid-3', name: 'Artikel 3', menge: 25),
        ),
      ];
      expect(conflicts.length, 3);
      expect(conflicts[0].localVersion.uuid, 'uuid-1');
      expect(conflicts[1].localVersion.uuid, 'uuid-2');
      expect(conflicts[2].localVersion.uuid, 'uuid-3');
    });

    test('leere Konflikt-Liste ist valide', () {
      final conflicts = <ConflictData>[];
      expect(conflicts, isEmpty);
    });

    test('Resolutions können pro UUID getracked werden', () {
      final resolutions = <String, ConflictResolution>{};
      final conflicts = [
        _makeConflict(
          local: _makeArtikel(uuid: 'uuid-1'),
          remote: _makeArtikel(uuid: 'uuid-1', menge: 50),
        ),
        _makeConflict(
          local: _makeArtikel(uuid: 'uuid-2'),
          remote: _makeArtikel(uuid: 'uuid-2', menge: 75),
        ),
      ];
      resolutions[conflicts[0].localVersion.uuid] = ConflictResolution.useLocal;
      resolutions[conflicts[1].localVersion.uuid] =
          ConflictResolution.useRemote;
      expect(resolutions['uuid-1'], ConflictResolution.useLocal);
      expect(resolutions['uuid-2'], ConflictResolution.useRemote);
      expect(resolutions.length, 2);
    });

    test('resolved/skipped Zählung funktioniert', () {
      final resolutions = <String, ConflictResolution>{
        'uuid-1': ConflictResolution.useLocal,
        'uuid-2': ConflictResolution.useRemote,
        'uuid-3': ConflictResolution.skip,
        'uuid-4': ConflictResolution.merge,
        'uuid-5': ConflictResolution.skip,
      };
      final resolved = resolutions.values
          .where((ConflictResolution c) => c != ConflictResolution.skip)
          .length;
      final skipped = resolutions.values
          .where((ConflictResolution c) => c == ConflictResolution.skip)
          .length;
      expect(resolved, 3);
      expect(skipped, 2);
      expect(resolved + skipped, resolutions.length);
    });
  });
}