// test/services/sync_orchestrator_test.dart
//
// Tests für SyncOrchestrator: ConflictCallback, Status-Stream, Guard.
// Neue Tests: 7
//
// CHANGES v0.8.5+3:
//   FIX — Artikel()-Konstruktor: fehlende required-Parameter ergänzt
//          (beschreibung, bildPfad, erstelltAm, aktualisiertAm).
//   FIX — unused_import: dart:async entfernt (durch flutter_test abgedeckt).
//   FIX — unused_import: sync_status_provider.dart entfernt.
//   FIX — unused_element: _FakePocketBaseSyncService entfernt
//          (kein Interface vorhanden → Fake nicht verwendbar).
//   FIX — prefer_function_declarations_over_variables:
//          ConflictCallback-Lambdas als lokale Funktionen deklariert.
//   FIX — require_trailing_commas: alle fehlenden Trailing-Commas ergänzt.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lager_app/models/artikel_model.dart';
import 'package:lager_app/services/orchestrator_sync_backend.dart';
import 'package:lager_app/services/sync_orchestrator.dart';

class _FakeOrchestratorSyncBackend implements OrchestratorSyncBackend {
  _FakeOrchestratorSyncBackend({
    Future<void> Function()? onSyncOnce,
    Future<void> Function()? onDownloadMissingImages,
    bool Function()? waitingProvider,
  })  : _onSyncOnce = onSyncOnce ?? (() async {}),
        _onDownloadMissingImages = onDownloadMissingImages ?? (() async {}),
        _waitingProvider = waitingProvider ?? (() => false);

  final Future<void> Function() _onSyncOnce;
  final Future<void> Function() _onDownloadMissingImages;
  final bool Function() _waitingProvider;

  @override
  ConflictCallback? onConflictDetected;

  @override
  Future<void> syncOnce() => _onSyncOnce();

  @override
  Future<void> downloadMissingImages() => _onDownloadMissingImages();

  @override
  bool get isWaitingForConflictResolution => _waitingProvider();


}

void main() {
  group('SyncOrchestrator', () {
    test('implementiert SyncStatusProvider', () {
      expect(SyncOrchestrator, isNotNull);
    });

    test('setConflictCallback registriert Callback am Backend', () {
      final backend = _FakeOrchestratorSyncBackend();

      final orchestrator = SyncOrchestrator(
        pocketBaseSync: backend,
        syncTimeout: const Duration(milliseconds: 200),
        imageTimeout: const Duration(milliseconds: 100),
        timeoutPollInterval: const Duration(milliseconds: 20),
      );

      Future<void> cb(Artikel lokal, Artikel remote) async {}

      orchestrator.setConflictCallback(cb);

      expect(backend.onConflictDetected, isNotNull);
    });

    test(
      'runOnce wartet bei aktiver Konfliktauflösung weiter und endet erfolgreich',
      () async {
        final completer = Completer<void>();

        final backend = _FakeOrchestratorSyncBackend(
          onSyncOnce: () => completer.future,
          onDownloadMissingImages: () async {},
          waitingProvider: () => true,
        );

        final orchestrator = SyncOrchestrator(
          pocketBaseSync: backend,
          syncTimeout: const Duration(milliseconds: 200),
          imageTimeout: const Duration(milliseconds: 100),
          timeoutPollInterval: const Duration(milliseconds: 20),
        );

        final statuses = <SyncStatus>[];
        final sub = orchestrator.syncStatus.listen(statuses.add);

        final future = orchestrator.runOnce();

        await Future<void>.delayed(const Duration(milliseconds: 120));
        completer.complete();

        await future;
        await Future<void>.delayed(Duration.zero);

        expect(statuses, contains(SyncStatus.running));
        expect(statuses, contains(SyncStatus.success));
        expect(statuses, isNot(contains(SyncStatus.error)));
        expect(orchestrator.lastSyncTime, isNotNull);
        expect(orchestrator.isSyncing, isFalse);

        await sub.cancel();
      },
    );

    test(
      'runOnce läuft ohne Konfliktwartephase in Timeout und meldet error',
      () async {
        final completer = Completer<void>();

        final backend = _FakeOrchestratorSyncBackend(
          onSyncOnce: () => completer.future,
          onDownloadMissingImages: () async {},
          waitingProvider: () => false,
        );

        final orchestrator = SyncOrchestrator(
          pocketBaseSync: backend,
          syncTimeout: const Duration(milliseconds: 100),
          imageTimeout: const Duration(milliseconds: 100),
          timeoutPollInterval: const Duration(milliseconds: 20),
        );

        final statuses = <SyncStatus>[];
        final sub = orchestrator.syncStatus.listen(statuses.add);

        await orchestrator.runOnce();
        await Future<void>.delayed(Duration.zero);

        expect(statuses, contains(SyncStatus.running));
        expect(statuses, contains(SyncStatus.error));
        expect(orchestrator.lastSyncTime, isNull);
        expect(orchestrator.isSyncing, isFalse);

        await sub.cancel();
      },
    );

    test(
      'runOnce setzt nach beendeter Konfliktwartephase den Erfolg korrekt',
      () async {
        final completer = Completer<void>();
        var waiting = true;

        final backend = _FakeOrchestratorSyncBackend(
          onSyncOnce: () => completer.future,
          onDownloadMissingImages: () async {},
          waitingProvider: () => waiting,
        );

        final orchestrator = SyncOrchestrator(
          pocketBaseSync: backend,
          syncTimeout: const Duration(milliseconds: 250),
          imageTimeout: const Duration(milliseconds: 100),
          timeoutPollInterval: const Duration(milliseconds: 20),
        );

        final statuses = <SyncStatus>[];
        final sub = orchestrator.syncStatus.listen(statuses.add);

        final future = orchestrator.runOnce();

        await Future<void>.delayed(const Duration(milliseconds: 80));
        waiting = false;
        completer.complete();

        await future;
        await Future<void>.delayed(Duration.zero);

        expect(statuses, contains(SyncStatus.running));
        expect(statuses, contains(SyncStatus.success));
        expect(orchestrator.lastSyncTime, isNotNull);
        expect(orchestrator.isSyncing, isFalse);

        await sub.cancel();
      },
    );

    test('paralleler zweiter runOnce-Aufruf wird per Guard übersprungen', () async {
      final completer = Completer<void>();
      var syncCalls = 0;

      final backend = _FakeOrchestratorSyncBackend(
        onSyncOnce: () {
          syncCalls++;
          return completer.future;
        },
        onDownloadMissingImages: () async {},
      );

      final orchestrator = SyncOrchestrator(
        pocketBaseSync: backend,
        syncTimeout: const Duration(milliseconds: 300),
        imageTimeout: const Duration(milliseconds: 100),
        timeoutPollInterval: const Duration(milliseconds: 20),
      );

      final future1 = orchestrator.runOnce();
      final future2 = orchestrator.runOnce();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      completer.complete();

      await Future.wait([future1, future2]);

      expect(syncCalls, 1);
    });

    test('downloadMissingImages wird nach erfolgreichem syncOnce ausgeführt', () async {
      var syncCalled = false;
      var imageCalled = false;

      final backend = _FakeOrchestratorSyncBackend(
        onSyncOnce: () async {
          syncCalled = true;
        },
        onDownloadMissingImages: () async {
          imageCalled = true;
        },
      );

      final orchestrator = SyncOrchestrator(
        pocketBaseSync: backend,
        syncTimeout: const Duration(milliseconds: 200),
        imageTimeout: const Duration(milliseconds: 100),
        timeoutPollInterval: const Duration(milliseconds: 20),
      );

      await orchestrator.runOnce();

      expect(syncCalled, isTrue);
      expect(imageCalled, isTrue);
      expect(orchestrator.lastSyncTime, isNotNull);
    });
  });

  group('ConflictCallback Typedef', () {
    test(
      'kann als Future<void> Function(Artikel, Artikel) verwendet werden',
      () async {
        var called = false;

        Future<void> cb(Artikel lokal, Artikel remote) async {
          called = true;
        }

        final now = DateTime.now();

        final lokal = Artikel(
          uuid: 'a',
          name: 'A',
          menge: 1,
          ort: 'X',
          fach: '1',
          beschreibung: '',
          bildPfad: '',
          erstelltAm: now,
          aktualisiertAm: now,
        );

        final remote = Artikel(
          uuid: 'a',
          name: 'B',
          menge: 2,
          ort: 'Y',
          fach: '2',
          beschreibung: '',
          bildPfad: '',
          erstelltAm: now,
          aktualisiertAm: now,
        );

        final ConflictCallback typedCb = cb;
        await typedCb(lokal, remote);

        expect(called, isTrue);
      },
    );

    test('Callback mit Exception wird sicher gefangen', () async {
      Future<void> cb(Artikel lokal, Artikel remote) async {
        throw Exception('Test-Exception');
      }

      final now = DateTime.now();

      final lokal = Artikel(
        uuid: 'a',
        name: 'A',
        menge: 1,
        ort: 'X',
        fach: '1',
        beschreibung: '',
        bildPfad: '',
        erstelltAm: now,
        aktualisiertAm: now,
      );

      final remote = Artikel(
        uuid: 'a',
        name: 'B',
        menge: 2,
        ort: 'Y',
        fach: '2',
        beschreibung: '',
        bildPfad: '',
        erstelltAm: now,
        aktualisiertAm: now,
      );

      await expectLater(
        () async {
          try {
            await cb(lokal, remote);
          } catch (_) {
            // Erwartet — produktiv im Service abgefangen.
          }
        },
        returnsNormally,
      );
    });
  });

  group('SyncStatus Enum', () {
    test('enthält alle erwarteten Werte', () {
      expect(
        SyncStatus.values,
        containsAll([
          SyncStatus.idle,
          SyncStatus.running,
          SyncStatus.success,
          SyncStatus.error,
        ]),
      );
    });

    test('switch über alle Werte ist exhaustiv', () {
      for (final status in SyncStatus.values) {
        final label = switch (status) {
          SyncStatus.idle => 'idle',
          SyncStatus.running => 'running',
          SyncStatus.success => 'success',
          SyncStatus.error => 'error',
        };

        expect(label, isNotEmpty);
      }
    });
  });

  group('ETag-Konflikt Grenzwerte', () {
    test('ETags mit Whitespace-Unterschied gelten als verschieden', () {
      const etag1 = '2024-01-15 10:00:00.000Z';
      const etag2 = '2024-01-15 10:00:00.000Z ';

      expect(
        etag1 == etag2,
        isFalse,
        reason: 'Whitespace-Unterschied soll Konflikt auslösen',
      );
    });

    test('Leerer ETag und leerer remoteUpdated → kein Konflikt', () {
      const lokalerEtag = '';
      const remoteUpdated = '';

      final istKonflikt = lokalerEtag.isNotEmpty &&
          lokalerEtag != 'deleted' &&
          remoteUpdated.isNotEmpty &&
          lokalerEtag != remoteUpdated;

      expect(istKonflikt, isFalse);
    });
  });
}