// test/services/sync_progress_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:lager_app/services/sync_progress_service.dart';

void main() {
  late SyncProgressService service;

  setUp(() {
    service = SyncProgressService();
  });

  tearDown(() {
    service.dispose();
  });

  // ─────────────────────────────────────────────
  // startOperation()
  // ─────────────────────────────────────────────
  group('startOperation()', () {
    test('gibt eine ID im Format sync_<timestamp> zurück', () {
      final id = service.startOperation('Test-Sync');
      expect(id, startsWith('sync_'));
      expect(int.tryParse(id.replaceFirst('sync_', '')), isNotNull);
    });

    test('setzt currentOperation mit Status initializing', () {
      service.startOperation('Test-Sync');
      expect(service.currentOperation, isNotNull);
      expect(service.currentOperation!.status, SyncStatus.initializing);
      expect(service.currentOperation!.name, 'Test-Sync');
    });

    test('setzt isSyncing auf true', () {
      service.startOperation('Test-Sync');
      expect(service.isSyncing, isTrue);
    });

    test('resettet Stats auf Null-Werte', () {
      // Erst Stats befüllen
      service.startOperation('Erster Sync');
      service.setTotalItems(10);
      service.incrementStat('processed');
      // Neuer Start
      service.startOperation('Zweiter Sync');
      expect(service.stats.totalItems, 0);
      expect(service.stats.processedItems, 0);
    });

    test('emittiert Operation auf operationStream', () async {
      final events = <SyncOperation>[];
      final sub = service.operationStream.listen(events.add);

      service.startOperation('Stream-Test');
      await Future.microtask(() {});

      expect(events.length, 1);
      expect(events.first.status, SyncStatus.initializing);
      await sub.cancel();
    });

    test('emittiert Stats auf statsStream', () async {
      final events = <SyncStats>[];
      final sub = service.statsStream.listen(events.add);

      service.startOperation('Stats-Stream-Test');
      await Future.microtask(() {});

      expect(events.length, 1);
      expect(events.first.totalItems, 0);
      await sub.cancel();
    });
  });

  // ─────────────────────────────────────────────
  // updateOperation()
  // ─────────────────────────────────────────────
  group('updateOperation()', () {
    test('aktualisiert Status und Progress', () {
      service.startOperation('Update-Test');
      service.updateOperation(
        status: SyncStatus.downloading,
        progress: 0.5,
        message: 'Lade Artikel...',
      );
      expect(service.currentOperation!.status, SyncStatus.downloading);
      expect(service.currentOperation!.progress, 0.5);
      expect(service.currentOperation!.message, 'Lade Artikel...');
    });

    test('tut nichts wenn keine aktive Operation', () {
      // Kein startOperation() → kein Crash
      expect(
        () => service.updateOperation(status: SyncStatus.downloading),
        returnsNormally,
      );
      expect(service.currentOperation, isNull);
    });

    test('emittiert Event auf operationStream', () async {
      service.startOperation('Stream-Update-Test');
      final events = <SyncOperation>[];
      final sub = service.operationStream.listen(events.add);

      service.updateOperation(status: SyncStatus.uploading);
      await Future.microtask(() {});

      expect(events.any((e) => e.status == SyncStatus.uploading), isTrue);
      await sub.cancel();
    });
  });

  // ─────────────────────────────────────────────
  // completeOperation()
  // ─────────────────────────────────────────────
  group('completeOperation()', () {
    test('setzt Status auf completed und progress auf 1.0', () async {
      service.startOperation('Complete-Test');
      // Kurze Pause damit duration > 0
      await Future<void>.delayed(const Duration(milliseconds: 10));
      service.completeOperation();

      // currentOperation ist null nach complete
      expect(service.currentOperation, isNull);
      expect(service.isSyncing, isFalse);
    });

    test('fügt Operation zur History hinzu', () {
      service.startOperation('History-Test');
      service.completeOperation();
      expect(service.operationHistory.length, 1);
      expect(service.operationHistory.first.status, SyncStatus.completed);
      expect(service.operationHistory.first.progress, 1.0);
    });

    test('verwendet Standard-Nachricht wenn keine angegeben', () {
      service.startOperation('Msg-Test');
      service.completeOperation();
      expect(
        service.operationHistory.first.message,
        contains('erfolgreich'),
      );
    });

    test('verwendet benutzerdefinierte Nachricht', () {
      service.startOperation('Custom-Msg-Test');
      service.completeOperation(message: 'Alles super!');
      expect(service.operationHistory.first.message, 'Alles super!');
    });

    test('tut nichts wenn keine aktive Operation', () {
      expect(() => service.completeOperation(), returnsNormally);
      expect(service.operationHistory, isEmpty);
    });

    test('setzt totalDuration in Stats', () async {
      service.startOperation('Duration-Test');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      service.completeOperation();
      expect(service.stats.totalDuration.inMilliseconds, greaterThan(0));
    });
  });

  // ─────────────────────────────────────────────
  // failOperation()
  // ─────────────────────────────────────────────
  group('failOperation()', () {
    test('setzt Status auf error', () {
      service.startOperation('Fail-Test');
      service.failOperation(Exception('Netzwerkfehler'));

      expect(service.currentOperation, isNull);
      expect(service.operationHistory.first.status, SyncStatus.error);
    });

    test('speichert Error-Objekt in der Operation', () {
      final error = Exception('DB-Fehler');
      service.startOperation('Error-Object-Test');
      service.failOperation(error);

      expect(service.operationHistory.first.error, error);
    });

    test('fügt Fehlermeldung zu Stats.errors hinzu', () {
      service.startOperation('Stats-Error-Test');
      service.failOperation(Exception('Timeout'));

      expect(service.stats.errors, isNotEmpty);
      expect(service.stats.errors.first, contains('Timeout'));
    });

    test('speichert StackTrace wenn übergeben', () {
      final st = StackTrace.current;
      service.startOperation('StackTrace-Test');
      service.failOperation(Exception('Fehler'), stackTrace: st);

      expect(service.operationHistory.first.stackTrace, st);
    });

    test('tut nichts wenn keine aktive Operation', () {
      expect(
        () => service.failOperation(Exception('Kein Op')),
        returnsNormally,
      );
    });
  });

  // ─────────────────────────────────────────────
  // cancelOperation()
  // ─────────────────────────────────────────────
  group('cancelOperation()', () {
    test('setzt Status auf cancelled', () {
      service.startOperation('Cancel-Test');
      service.cancelOperation();

      expect(service.currentOperation, isNull);
      expect(service.operationHistory.first.status, SyncStatus.cancelled);
    });

    test('verwendet Standard-Nachricht', () {
      service.startOperation('Cancel-Msg-Test');
      service.cancelOperation();
      expect(
        service.operationHistory.first.message,
        contains('abgebrochen'),
      );
    });

    test('tut nichts wenn keine aktive Operation', () {
      expect(() => service.cancelOperation(), returnsNormally);
    });
  });

  // ─────────────────────────────────────────────
  // setTotalItems()
  // ─────────────────────────────────────────────
  group('setTotalItems()', () {
    test('setzt totalItems korrekt', () {
      service.startOperation('Items-Test');
      service.setTotalItems(50);
      expect(service.stats.totalItems, 50);
    });

    test('ignoriert negative Werte', () {
      service.startOperation('Negative-Test');
      service.setTotalItems(10);
      service.setTotalItems(-5);
      expect(service.stats.totalItems, 10);
    });

    test('akzeptiert 0', () {
      service.startOperation('Zero-Test');
      service.setTotalItems(0);
      expect(service.stats.totalItems, 0);
    });
  });

  // ─────────────────────────────────────────────
  // incrementStat() / decrementStat()
  // ─────────────────────────────────────────────
  group('incrementStat()', () {
    setUp(() => service.startOperation('Stat-Test'));

    test('processed', () {
      service.incrementStat('processed');
      expect(service.stats.processedItems, 1);
    });

    test('uploaded', () {
      service.incrementStat('uploaded');
      expect(service.stats.uploadedItems, 1);
    });

    test('downloaded', () {
      service.incrementStat('downloaded');
      expect(service.stats.downloadedItems, 1);
    });

    test('conflict', () {
      service.incrementStat('conflict');
      expect(service.stats.conflictItems, 1);
    });

    test('error', () {
      service.incrementStat('error');
      expect(service.stats.errorItems, 1);
    });

    test('skipped', () {
      service.incrementStat('skipped');
      expect(service.stats.skippedItems, 1);
    });

    test('unbekannter Typ wirft assertion in debug mode', () {
      expect(
        () => service.incrementStat('ungültig'),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('decrementStat()', () {
    setUp(() => service.startOperation('Decrement-Test'));

    test('dekrementiert processed', () {
      service.incrementStat('processed');
      service.decrementStat('processed');
      expect(service.stats.processedItems, 0);
    });

    test('Underflow-Schutz: bleibt bei 0', () {
      service.decrementStat('processed');
      expect(service.stats.processedItems, 0);
    });

    test('Underflow-Schutz für alle Typen', () {
      for (final type in [
        'uploaded',
        'downloaded',
        'conflict',
        'error',
        'skipped',
      ]) {
        service.decrementStat(type);
      }
      expect(service.stats.uploadedItems, 0);
      expect(service.stats.downloadedItems, 0);
      expect(service.stats.conflictItems, 0);
      expect(service.stats.errorItems, 0);
      expect(service.stats.skippedItems, 0);
    });
  });

  // ─────────────────────────────────────────────
  // updateStats() — Progress-Berechnung
  // ─────────────────────────────────────────────
  group('updateStats() Progress-Berechnung', () {
    test('berechnet Operation-Progress aus Stats', () {
      service.startOperation('Progress-Calc-Test');
      service.setTotalItems(10);
      service.updateStats(processedItems: 5);
      expect(service.currentOperation!.progress, 0.5);
    });

    test('clamp: Progress überschreitet nicht 1.0', () {
      service.startOperation('Clamp-Test');
      service.setTotalItems(10);
      service.updateStats(processedItems: 15);
      expect(service.currentOperation!.progress, 1.0);
    });

    test('kein Progress-Update wenn totalItems = 0', () {
      service.startOperation('No-Total-Test');
      service.updateStats(processedItems: 5);
      expect(service.currentOperation!.progress, 0.0);
    });

    test('fügt error-String zu Stats.errors hinzu', () {
      service.startOperation('Error-String-Test');
      service.updateStats(error: 'Artikel 42 fehlgeschlagen');
      expect(service.stats.errors, contains('Artikel 42 fehlgeschlagen'));
    });
  });

  // ─────────────────────────────────────────────
  // History-Limit
  // ─────────────────────────────────────────────
  group('History-Limit (_maxHistorySize = 100)', () {
    test('History wächst nicht über 100 Einträge', () {
      for (int i = 0; i < 105; i++) {
        service.startOperation('Op $i');
        service.completeOperation();
      }
      expect(service.operationHistory.length, 100);
    });

    test('älteste Einträge werden entfernt', () {
      for (int i = 0; i < 105; i++) {
        service.startOperation('Op $i');
        service.completeOperation();
      }
      // Op 0–4 sollten weg sein, Op 5 ist jetzt der erste
      expect(service.operationHistory.first.name, 'Op 5');
    });
  });

  // ─────────────────────────────────────────────
  // clearHistory()
  // ─────────────────────────────────────────────
  group('clearHistory()', () {
    test('leert die History', () {
      service.startOperation('Clear-Test');
      service.completeOperation();
      expect(service.operationHistory, isNotEmpty);

      service.clearHistory();
      expect(service.operationHistory, isEmpty);
    });
  });

  // ─────────────────────────────────────────────
  // getLastOperationReport()
  // ─────────────────────────────────────────────
  group('getLastOperationReport()', () {
    test('gibt leere Map zurück wenn keine History', () {
      expect(service.getLastOperationReport(), isEmpty);
    });

    test('enthält operation, statistics, performance Keys', () {
      service.startOperation('Report-Test');
      service.completeOperation();
      final report = service.getLastOperationReport();

      expect(report.containsKey('operation'), isTrue);
      expect(report.containsKey('statistics'), isTrue);
      expect(report.containsKey('performance'), isTrue);
    });

    test('successRate ist 0 wenn totalItems = 0 (kein Division-by-zero)', () {
      service.startOperation('Division-Zero-Test');
      service.completeOperation();
      final report = service.getLastOperationReport();

      expect(report['statistics']['successRate'], '0%');
    });

    test('itemsPerSecond ist 0 wenn duration = 0 (kein Division-by-zero)', () {
      service.startOperation('Speed-Zero-Test');
      service.completeOperation();
      final report = service.getLastOperationReport();

      expect(report['performance']['itemsPerSecond'], '0');
    });

    test('successRate korrekt berechnet', () {
      service.startOperation('Success-Rate-Test');
      service.setTotalItems(10);
      service.updateStats(processedItems: 8, errorItems: 2);
      service.completeOperation();
      final report = service.getLastOperationReport();

      // (8 - 2) / 10 * 100 = 60.0%
      expect(report['statistics']['successRate'], '60.0%');
    });
  });

  // ─────────────────────────────────────────────
  // SyncOperation — Getter
  // ─────────────────────────────────────────────
  group('SyncOperation Getter', () {
    test('isActive ist true für laufende Operationen', () {
      service.startOperation('Active-Test');
      expect(service.currentOperation!.isActive, isTrue);
    });

    test('isCompleted ist true nach complete', () {
      service.startOperation('Completed-Getter-Test');
      service.completeOperation();
      expect(service.operationHistory.first.isCompleted, isTrue);
    });

    test('isError ist true nach fail', () {
      service.startOperation('Error-Getter-Test');
      service.failOperation(Exception('X'));
      expect(service.operationHistory.first.isError, isTrue);
    });

    test('statusText gibt deutschen Text zurück', () {
      service.startOperation('StatusText-Test');
      expect(
        service.currentOperation!.statusText,
        'Initialisiere...',
      );
    });
  });

  // ─────────────────────────────────────────────
  // SyncStats — Getter
  // ─────────────────────────────────────────────
  group('SyncStats Getter', () {
    test('progressPercentage = 0 wenn totalItems = 0', () {
      expect(service.stats.progressPercentage, 0.0);
    });

    test('progressPercentage korrekt berechnet', () {
      service.startOperation('Percentage-Test');
      service.setTotalItems(4);
      service.updateStats(processedItems: 1);
      expect(service.stats.progressPercentage, 0.25);
    });

    test('hasErrors true wenn errorItems > 0', () {
      service.startOperation('HasErrors-Test');
      service.incrementStat('error');
      expect(service.stats.hasErrors, isTrue);
    });

    test('hasConflicts true wenn conflictItems > 0', () {
      service.startOperation('HasConflicts-Test');
      service.incrementStat('conflict');
      expect(service.stats.hasConflicts, isTrue);
    });

    test('isCompleted true wenn processedItems >= totalItems', () {
      service.startOperation('StatsCompleted-Test');
      service.setTotalItems(3);
      service.updateStats(processedItems: 3);
      expect(service.stats.isCompleted, isTrue);
    });
  });

  // ─────────────────────────────────────────────
  // ChangeNotifier
  // ─────────────────────────────────────────────
  group('ChangeNotifier', () {
    test('notifyListeners wird bei startOperation aufgerufen', () {
      int callCount = 0;
      service.addListener(() => callCount++);
      service.startOperation('Notify-Test');
      expect(callCount, greaterThan(0));
    });

    test('notifyListeners wird bei completeOperation aufgerufen', () {
      service.startOperation('Notify-Complete-Test');
      int callCount = 0;
      service.addListener(() => callCount++);
      service.completeOperation();
      expect(callCount, greaterThan(0));
    });
  });

  // ─────────────────────────────────────────────
  // dispose()
  // ─────────────────────────────────────────────
  group('dispose()', () {
    test('schließt StreamController ohne Fehler', () {
      final localService = SyncProgressService();
      expect(() => localService.dispose(), returnsNormally);
    });

    test('Streams sind nach dispose geschlossen', () async {
      final localService = SyncProgressService();
      final opStream = localService.operationStream;
      final statsStream = localService.statsStream;
      localService.dispose();

      expect(await opStream.isEmpty, isTrue);
      expect(await statsStream.isEmpty, isTrue);
    });
  });
}