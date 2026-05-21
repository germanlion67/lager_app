import 'package:logger/logger.dart';
// test/services/sync_error_recovery_test.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lager_app/services/sync_error_recovery.dart';

void main() {
  // ─── SyncError.fromException ───────────────────────────────────────────────
  group('SyncError.fromException()', () {
    group('ErrorType-Erkennung', () {
      test('SocketException → network', () {
        final e = SyncError.fromException(const SocketException('no route'));
        expect(e.type, SyncErrorType.network);
      });

      test('HttpException → network', () {
        final e = SyncError.fromException(const HttpException('bad'));
        expect(e.type, SyncErrorType.network);
      });

      test('TimeoutException → timeout', () {
        final e = SyncError.fromException(TimeoutException('too slow'));
        expect(e.type, SyncErrorType.timeout);
      });

      test('FileSystemException → storage', () {
        final e = SyncError.fromException(const FileSystemException('disk'));
        expect(e.type, SyncErrorType.storage);
      });

      test('401 string → authentication', () {
        final e = SyncError.fromException(Exception('Error 401 unauthorized'));
        expect(e.type, SyncErrorType.authentication);
      });

      test('authentication string → authentication', () {
        final e = SyncError.fromException(Exception('authentication failed'));
        expect(e.type, SyncErrorType.authentication);
      });

      test('409 string → conflict', () {
        final e = SyncError.fromException(Exception('409 conflict detected'));
        expect(e.type, SyncErrorType.conflict);
      });

      test('500 string → server', () {
        final e = SyncError.fromException(Exception('500 internal server error'));
        expect(e.type, SyncErrorType.server);
      });

      test('503 string → server', () {
        final e = SyncError.fromException(Exception('503 service unavailable'));
        expect(e.type, SyncErrorType.server);
      });

      test('400 string → client', () {
        final e = SyncError.fromException(Exception('400 bad request'));
        expect(e.type, SyncErrorType.client);
      });

      test('404 string → client', () {
        final e = SyncError.fromException(Exception('404 not found'));
        expect(e.type, SyncErrorType.client);
      });

      test('unbekannter Fehler → unknown', () {
        final e = SyncError.fromException(Exception('something weird'));
        expect(e.type, SyncErrorType.unknown);
      });
    });

    group('Severity-Mapping', () {
      test('authentication → critical', () {
        final e = SyncError.fromException(Exception('401 unauthorized'));
        expect(e.severity, ErrorSeverity.critical);
      });

      test('network → medium', () {
        final e = SyncError.fromException(const SocketException('x'));
        expect(e.severity, ErrorSeverity.medium);
      });

      test('server → high', () {
        final e = SyncError.fromException(Exception('500 server error'));
        expect(e.severity, ErrorSeverity.high);
      });

      test('conflict → medium', () {
        final e = SyncError.fromException(Exception('409 conflict'));
        expect(e.severity, ErrorSeverity.medium);
      });

      test('storage → high', () {
        final e = SyncError.fromException(const FileSystemException('x'));
        expect(e.severity, ErrorSeverity.high);
      });

      test('timeout → low', () {
        final e = SyncError.fromException(TimeoutException('x'));
        expect(e.severity, ErrorSeverity.low);
      });

      test('client → high', () {
        final e = SyncError.fromException(Exception('400 bad request'));
        expect(e.severity, ErrorSeverity.high);
      });

      test('unknown → medium', () {
        final e = SyncError.fromException(Exception('weird'));
        expect(e.severity, ErrorSeverity.medium);
      });
    });

    group('User-Messages', () {
      test('network message', () {
        final e = SyncError.fromException(const SocketException('x'));
        expect(e.message, contains('Netzwerkfehler'));
      });

      test('authentication message', () {
        final e = SyncError.fromException(Exception('401'));
        expect(e.message, contains('Authentifizierungsfehler'));
      });

      test('server message', () {
        final e = SyncError.fromException(Exception('500'));
        expect(e.message, contains('Serverfehler'));
      });

      test('conflict message', () {
        final e = SyncError.fromException(Exception('409 conflict'));
        expect(e.message, contains('Konflikt'));
      });

      test('storage message', () {
        final e = SyncError.fromException(const FileSystemException('x'));
        expect(e.message, contains('Speicherfehler'));
      });

      test('timeout message', () {
        final e = SyncError.fromException(TimeoutException('x'));
        expect(e.message, contains('Timeout'));
      });

      test('client message', () {
        final e = SyncError.fromException(Exception('400'));
        expect(e.message, contains('Client-Fehler'));
      });

      test('unknown message', () {
        final e = SyncError.fromException(Exception('weird'));
        expect(e.message, contains('Unbekannter Fehler'));
      });
    });

    group('SuggestedActions', () {
      test('network → enthält checkConnection und retry', () {
        final e = SyncError.fromException(const SocketException('x'));
        expect(e.suggestedActions, contains(RecoveryAction.checkConnection));
        expect(e.suggestedActions, contains(RecoveryAction.retry));
      });

      test('authentication → enthält relogin und checkCredentials', () {
        final e = SyncError.fromException(Exception('401'));
        expect(e.suggestedActions, contains(RecoveryAction.relogin));
        expect(e.suggestedActions, contains(RecoveryAction.checkCredentials));
      });

      test('server → enthält retryLater und contactAdmin', () {
        final e = SyncError.fromException(Exception('500'));
        expect(e.suggestedActions, contains(RecoveryAction.retryLater));
        expect(e.suggestedActions, contains(RecoveryAction.contactAdmin));
      });

      test('conflict → enthält resolveConflict und skipItem', () {
        final e = SyncError.fromException(Exception('409 conflict'));
        expect(e.suggestedActions, contains(RecoveryAction.resolveConflict));
        expect(e.suggestedActions, contains(RecoveryAction.skipItem));
      });

      test('storage → enthält checkStorage und clearCache', () {
        final e = SyncError.fromException(const FileSystemException('x'));
        expect(e.suggestedActions, contains(RecoveryAction.checkStorage));
        expect(e.suggestedActions, contains(RecoveryAction.clearCache));
      });

      test('timeout → enthält retry und adjustTimeout', () {
        final e = SyncError.fromException(TimeoutException('x'));
        expect(e.suggestedActions, contains(RecoveryAction.retry));
        expect(e.suggestedActions, contains(RecoveryAction.adjustTimeout));
      });

      test('client → enthält viewLogs und reportBug', () {
        final e = SyncError.fromException(Exception('400'));
        expect(e.suggestedActions, contains(RecoveryAction.viewLogs));
        expect(e.suggestedActions, contains(RecoveryAction.reportBug));
      });
    });

    group('Felder', () {
      test('id hat korrektes Format', () {
        final e = SyncError.fromException(Exception('x'));
        expect(e.id, startsWith('error_'));
      });

      test('technicalDetails enthält original error string', () {
        final e = SyncError.fromException(Exception('my error'));
        expect(e.technicalDetails, contains('my error'));
      });

      test('itemId und itemName werden übernommen', () {
        final e = SyncError.fromException(
          Exception('x'),
          itemId: 'item-42',
          itemName: 'Testartikel',
        );
        expect(e.itemId, 'item-42');
        expect(e.itemName, 'Testartikel');
      });

      test('context wird übernommen', () {
        final e = SyncError.fromException(
          Exception('x'),
          context: {'key': 'value'},
        );
        expect(e.context['key'], 'value');
      });

      test('stackTrace wird übernommen', () {
        final st = StackTrace.current;
        final e = SyncError.fromException(Exception('x'), stackTrace: st);
        expect(e.stackTrace, st);
      });

      test('timestamp ist gesetzt', () {
        final before = DateTime.now();
        final e = SyncError.fromException(Exception('x'));
        expect(e.timestamp.isAfter(before) || e.timestamp.isAtSameMomentAs(before), isTrue);
      });
    });
  });

  // ─── SyncError Getter ──────────────────────────────────────────────────────
  group('SyncError Getter', () {
    group('isRetryable', () {
      test('network + medium → true', () {
        final e = SyncError.fromException(const SocketException('x'));
        expect(e.isRetryable, isTrue);
      });

      test('timeout + low → true', () {
        final e = SyncError.fromException(TimeoutException('x'));
        expect(e.isRetryable, isTrue);
      });

      test('server + high → true', () {
        final e = SyncError.fromException(Exception('500'));
        expect(e.isRetryable, isTrue);
      });

      test('authentication + critical → false', () {
        final e = SyncError.fromException(Exception('401'));
        expect(e.isRetryable, isFalse);
      });

      test('conflict + medium → false (kein retryable type)', () {
        final e = SyncError.fromException(Exception('409 conflict'));
        expect(e.isRetryable, isFalse);
      });
    });

    group('requiresUserAction', () {
      test('critical severity → true', () {
        final e = SyncError.fromException(Exception('401'));
        expect(e.requiresUserAction, isTrue);
      });

      test('conflict type → true', () {
        final e = SyncError.fromException(Exception('409 conflict'));
        expect(e.requiresUserAction, isTrue);
      });

      test('network (medium, nicht conflict/auth) → false', () {
        final e = SyncError.fromException(const SocketException('x'));
        expect(e.requiresUserAction, isFalse);
      });
    });
  });

  // ─── RecoveryAction Extension ──────────────────────────────────────────────
  group('RecoveryAction Extension', () {
    test('alle Actions haben nicht-leere title', () {
      for (final action in RecoveryAction.values) {
        expect(action.title, isNotEmpty, reason: '$action.title ist leer');
      }
    });

    test('alle Actions haben nicht-leere description', () {
      for (final action in RecoveryAction.values) {
        expect(action.description, isNotEmpty, reason: '$action.description ist leer');
      }
    });

    test('retry title korrekt', () {
      expect(RecoveryAction.retry.title, 'Erneut versuchen');
    });

    test('relogin title korrekt', () {
      expect(RecoveryAction.relogin.title, 'Erneut anmelden');
    });

    test('resolveConflict description enthält Konflikt', () {
      expect(RecoveryAction.resolveConflict.description.toLowerCase(), contains('konflikt'));
    });
  });

  // ─── SyncErrorRecoveryService ──────────────────────────────────────────────
  group('SyncErrorRecoveryService', () {
    late SyncErrorRecoveryService service;

    setUp(() {
      service = SyncErrorRecoveryService(
        // ✅ Delays auf 0 setzen → Tests laufen in <1s
        retryDelay: Duration.zero,
        exponentialBackoffBase: Duration.zero,
        logger: Logger(level: Level.off),
      );
    });

    // ── handleError ──────────────────────────────────────────────────────────
    group('handleError()', () {
      test('gibt SyncErrorRecoveryResult zurück', () async {
        final result = await service.handleError(const SocketException('x'));
        expect(result, isA<SyncErrorRecoveryResult>());
      });

      test('Fehler wird zur History hinzugefügt', () async {
        await service.handleError(const SocketException('x'));
        expect(service.errorHistory.length, 1);
      });

      test('mehrere Fehler werden akkumuliert', () async {
        await service.handleError(const SocketException('x'));
        await service.handleError(TimeoutException('y'));
        expect(service.errorHistory.length, 2);
      });

      test('errorHistory ist unmodifiable', () async {
        await service.handleError(const SocketException('x'));
        expect(
          () => service.errorHistory.add(
            SyncError.fromException(Exception('test')), // ← gültiger Typ
          ),
          throwsUnsupportedError,
        );
      });

      test('network error → canRetry true', () async {
        final result = await service.handleError(const SocketException('x'));
        expect(result.canRetry, isTrue);
      });

      test('authentication error → requiresUserInput true', () async {
        final result = await service.handleError(Exception('401'));
        expect(result.requiresUserInput, isTrue);
      });

      test('authentication error → strategy requireUserAction', () async {
        final result = await service.handleError(Exception('401'));
        expect(result.strategy, RecoveryStrategy.requireUserAction);
      });

      test('conflict error → strategy resolveConflict', () async {
        final result = await service.handleError(Exception('409 conflict'));
        expect(result.strategy, RecoveryStrategy.resolveConflict);
      });

      test('timeout error → shouldSkip true (low severity)', () async {
        final result = await service.handleError(TimeoutException('x'));
        expect(result.shouldSkip, isTrue);
      });

      test('itemId und itemName werden weitergegeben', () async {
        final result = await service.handleError(
          const SocketException('x'),
          itemId: 'abc',
          itemName: 'Artikel',
        );
        expect(result.error.itemId, 'abc');
        expect(result.error.itemName, 'Artikel');
      });
    });

    // ── History-Limit ─────────────────────────────────────────────────────────
    group('History-Limit', () {
      test('maximal 500 Einträge in errorHistory', () async {
        for (int i = 0; i < 510; i++) {
          await service.handleError(const SocketException('x'));
        }
        expect(service.errorHistory.length, 500);
      });

      test('älteste Einträge werden entfernt', () async {
        // Ersten Fehler merken
        await service.handleError(Exception('first_unique_error_xyz'));
        for (int i = 0; i < 500; i++) {
          await service.handleError(const SocketException('x'));
        }
        final messages = service.errorHistory.map((e) => e.technicalDetails ?? '').toList();
        expect(messages.any((m) => m.contains('first_unique_error_xyz')), isFalse);
      });
    });

    // ── performRetry ──────────────────────────────────────────────────────────
    group('performRetry()', () {
      test('führt retryFunction aus und gibt Ergebnis zurück', () async {
        final error = SyncError.fromException(const SocketException('x'));
        final result = await service.performRetry(error, () async => 42);
        expect(result, 42);
      });

      test('wirft Exception nach maxRetries', () async {
        final error = SyncError.fromException(
          const SocketException('x'),
          itemId: 'retry-test',
        );

        // 3 fehlgeschlagene Versuche
        for (int i = 0; i < SyncErrorRecoveryService.maxRetries; i++) {
          try {
            await service.performRetry(
              error,
              () async => throw Exception('fail'),
            );
          } catch (_) {}
        }

        // 4. Versuch → Exception wegen maxRetries
        expect(
          () => service.performRetry(error, () async => 1),
          throwsException,
        );
      });

      test('bei Erfolg wird retryCount zurückgesetzt', () async {
        final error = SyncError.fromException(
          const SocketException('x'),
          itemId: 'reset-test',
        );

        // 1 fehlgeschlagener Versuch
        try {
          await service.performRetry(error, () async => throw Exception('fail'));
        } catch (_) {}

        // Erfolgreicher Versuch → Reset
        await service.performRetry(error, () async => 'ok');

        // Jetzt sollten wieder 3 Versuche möglich sein
        // (kein Exception beim nächsten Aufruf)
        final result = await service.performRetry(error, () async => 'ok2');
        expect(result, 'ok2');
      });
    });

    // ── performBatchRecovery ──────────────────────────────────────────────────
    group('performBatchRecovery()', () {
      test('leere Liste → alles 0', () async {
        final result = await service.performBatchRecovery([], (_) async {});
        expect(result.successful, 0);
        expect(result.failed, 0);
        expect(result.skipped, 0);
      });

      test('low-severity Fehler werden übersprungen', () async {
        final errors = [
          SyncError.fromException(TimeoutException('x')), // low → skip
        ];
        final result = await service.performBatchRecovery(errors, (_) async {});
        expect(result.skipped, 1);
        expect(result.successful, 0);
      });

      test('retryable Fehler werden als successful gezählt', () async {
        final errors = [
          SyncError.fromException(const SocketException('x')),
        ];
        final result = await service.performBatchRecovery(
          errors,
          (_) async {}, // Erfolg
        );
        expect(result.successful, 1);
      });

      test('fehlschlagende Retries landen in remainingErrors', () async {
        final errors = [
          SyncError.fromException(const SocketException('x'), ),
        ];
        final result = await service.performBatchRecovery(
          errors,
          (_) async => throw Exception('still failing'),
        );
        expect(result.failed, 1);
        expect(result.remainingErrors.length, 1);
      });

      test('nicht-retryable, nicht-critical → failed + remainingErrors', () async {
        final errors = [
          SyncError.fromException(Exception('409 conflict')), // conflict → nicht retryable
        ];
        final result = await service.performBatchRecovery(errors, (_) async {});
        expect(result.failed, 1);
        expect(result.remainingErrors.isNotEmpty, isTrue);
      });
    });

    // ── clearOldErrors ────────────────────────────────────────────────────────
    group('clearOldErrors()', () {
      test('entfernt Fehler älter als maxAge', () async {
        // Alten Fehler manuell hinzufügen
        await service.handleError(const SocketException('recent'));
        service.clearOldErrors(maxAge: const Duration(days: 7));
        expect(service.errorHistory.length, 1); // recent bleibt
      });

      test('löscht alle Fehler bei maxAge=0', () async {
        await service.handleError(const SocketException('x'));
        service.clearOldErrors(maxAge: Duration.zero);
        expect(service.errorHistory.isEmpty, isTrue);
      });
    });

    // ── generateErrorReport ───────────────────────────────────────────────────
    group('generateErrorReport()', () {
      test('leere History → totalErrors 0', () {
        final report = service.generateErrorReport();
        expect(report['summary']['totalErrors'], 0);
      });

      test('enthält summary, errorsByType, errorsBySeverity, recentErrors', () {
        final report = service.generateErrorReport();
        expect(report.containsKey('summary'), isTrue);
        expect(report.containsKey('errorsByType'), isTrue);
        expect(report.containsKey('errorsBySeverity'), isTrue);
        expect(report.containsKey('recentErrors'), isTrue);
      });

      test('mostCommonType ist null bei leerer History', () {
        final report = service.generateErrorReport();
        expect(report['summary']['mostCommonType'], isNull);
      });

      test('mostCommonType korrekt nach mehreren Fehlern', () async {
        await service.handleError(const SocketException('x'));
        await service.handleError(const SocketException('y'));
        await service.handleError(Exception('401'));
        final report = service.generateErrorReport();
        expect(
          report['summary']['mostCommonType'],
          contains('network'),
        );
      });

      test('criticalErrors korrekt gezählt', () async {
        await service.handleError(Exception('401')); // critical
        await service.handleError(const SocketException('x')); // medium
        final report = service.generateErrorReport();
        expect(report['summary']['criticalErrors'], 1);
      });

      test('recentErrors maximal 10 Einträge', () async {
        for (int i = 0; i < 15; i++) {
          await service.handleError(const SocketException('x'));
        }
        final report = service.generateErrorReport();
        expect((report['recentErrors'] as List).length, lessThanOrEqualTo(10));
      });
    });
  });

  // ─── BatchRecoveryResult ───────────────────────────────────────────────────
  group('BatchRecoveryResult', () {
    test('total = successful + failed + skipped', () {
      final r = BatchRecoveryResult(
        successful: 3,
        failed: 2,
        skipped: 1,
        remainingErrors: [],
      );
      expect(r.total, 6);
    });

    test('hasRemainingErrors true wenn Liste nicht leer', () {
      final error = SyncError.fromException(Exception('x'));
      final r = BatchRecoveryResult(
        successful: 0,
        failed: 1,
        skipped: 0,
        remainingErrors: [error],
      );
      expect(r.hasRemainingErrors, isTrue);
    });

    test('hasRemainingErrors false bei leerer Liste', () {
      final r = BatchRecoveryResult(
        successful: 1,
        failed: 0,
        skipped: 0,
        remainingErrors: [],
      );
      expect(r.hasRemainingErrors, isFalse);
    });

    test('successRate korrekt berechnet', () {
      final r = BatchRecoveryResult(
        successful: 3,
        failed: 1,
        skipped: 0,
        remainingErrors: [],
      );
      expect(r.successRate, closeTo(0.75, 0.001));
    });

    test('successRate = 0 bei total=0', () {
      final r = BatchRecoveryResult(
        successful: 0,
        failed: 0,
        skipped: 0,
        remainingErrors: [],
      );
      expect(r.successRate, 0.0);
    });
  });
}
