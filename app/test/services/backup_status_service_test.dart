// test/services/backup_status_service_test.dart
//
// T-006: Unit-Tests für BackupStatusService.fetchStatus()
//
// Strategie:
// - MockClient aus package:http/testing.dart — kein Netzwerk nötig
// - pbUrlOverride injiziert Test-URL ohne PocketBaseService-Singleton
// - client-Parameter injiziert MockClient statt globalem http.get()
//
// Abgedeckt:
// - Leere URL → sofort unknown, kein HTTP-Call
// - Versuch 1 (/last_backup.json) erfolgreich: success + error-Status
// - Versuch 1 schlägt fehl → Fallback auf Versuch 2: 404, 500, Exception, ungültiges JSON
// - Beide Versuche schlagen fehl → unknown
// - JSON-Parsing: String-Zahlen, fehlende Felder
// - Farblogik: fresh / aging / critical (End-to-End HTTP → ageCategory)

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lager_app/services/backup_status_service.dart';

void main() {
  // ── Test-Konstanten & Fixtures ─────────────────────────────────────────────

  const kTestUrl = 'http://localhost:8080';

  /// Erzeugt einen gültigen JSON-Body für last_backup.json.
  String validJson({
    String status = 'success',
    int timestampUnix = 1700000000,
    String file = 'backup_2024.tar.gz',
    String size = '12.5 MB',
    int backupCount = 7,
    int keepDays = 7,
    String error = '',
  }) =>
      jsonEncode({
        'status': status,
        'timestamp': '2024-11-14 22:13:20',
        'timestamp_unix': timestampUnix,
        'file': file,
        'size': size,
        'backup_count': backupCount,
        'keep_days': keepDays,
        'error': error,
      });

  // ── Tests ──────────────────────────────────────────────────────────────────

  group('BackupStatusService.fetchStatus()', () {
    // ── Leere URL ────────────────────────────────────────────────────────────

    group('Leere URL', () {
      test('gibt BackupStatus.unknown zurück ohne HTTP-Call', () async {
        var called = false;
        final client = MockClient(
          (_) async {
            called = true;
            return http.Response('', 200);
          },
        );

        final result = await BackupStatusService.fetchStatus(
          client: client,
          pbUrlOverride: '',
        );

        expect(result.status, equals('unknown'));
        expect(result.timestampUnix, equals(0));
        expect(
          called,
          isFalse,
          reason: 'Kein HTTP-Call bei leerer URL',
        );
      });
    });

    // ── Versuch 1 erfolgreich ─────────────────────────────────────────────────

    group('Versuch 1: /last_backup.json → 200', () {
      test('gibt korrekten BackupStatus zurück und fragt primären Pfad an', () async {
        final client = MockClient(
          (request) async {
            expect(
              request.url.toString(),
              equals('$kTestUrl/last_backup.json'),
              reason: 'Versuch 1 muss den primären Pfad anfragen',
            );
            return http.Response(validJson(), 200);
          },
        );

        final result = await BackupStatusService.fetchStatus(
          client: client,
          pbUrlOverride: kTestUrl,
        );

        expect(result.isSuccess, isTrue);
        expect(result.file, equals('backup_2024.tar.gz'));
        expect(result.backupCount, equals(7));
        expect(result.keepDays, equals(7));
      });

      test('gibt BackupStatus mit error-Status zurück', () async {
        final client = MockClient(
          (_) async => http.Response(
            validJson(status: 'error', error: 'Disk full'),
            200,
          ),
        );

        final result = await BackupStatusService.fetchStatus(
          client: client,
          pbUrlOverride: kTestUrl,
        );

        expect(result.isError, isTrue);
        expect(result.isSuccess, isFalse);
        expect(result.error, equals('Disk full'));
      });
    });

    // ── Versuch 1 schlägt fehl → Fallback auf Versuch 2 ──────────────────────

    group('Versuch 1 schlägt fehl → Fallback auf /backups/last_backup.json', () {
      test('nutzt Fallback-Pfad bei HTTP 404 — beide Pfade werden versucht', () async {
        var callCount = 0;
        final client = MockClient(
          (request) async {
            callCount++;
            if (request.url.path == '/last_backup.json') {
              return http.Response('Not Found', 404);
            }
            if (request.url.path == '/backups/last_backup.json') {
              return http.Response(validJson(), 200);
            }
            return http.Response('Not Found', 404);
          },
        );

        final result = await BackupStatusService.fetchStatus(
          client: client,
          pbUrlOverride: kTestUrl,
        );

        expect(
          callCount,
          equals(2),
          reason: 'Beide Pfade müssen versucht werden',
        );
        expect(result.isSuccess, isTrue);
      });

      test('nutzt Fallback-Pfad bei HTTP 500', () async {
        final client = MockClient(
          (request) async {
            if (request.url.path == '/last_backup.json') {
              return http.Response('Internal Server Error', 500);
            }
            return http.Response(validJson(), 200);
          },
        );

        final result = await BackupStatusService.fetchStatus(
          client: client,
          pbUrlOverride: kTestUrl,
        );

        expect(result.isSuccess, isTrue);
      });

      test('nutzt Fallback-Pfad bei Netzwerk-Exception', () async {
        final client = MockClient(
          (request) async {
            if (request.url.path == '/last_backup.json') {
              throw http.ClientException('Connection refused', request.url);
            }
            return http.Response(validJson(), 200);
          },
        );

        final result = await BackupStatusService.fetchStatus(
          client: client,
          pbUrlOverride: kTestUrl,
        );

        expect(result.isSuccess, isTrue);
      });

      test('nutzt Fallback-Pfad bei ungültigem JSON (Liste statt Map)', () async {
        final client = MockClient(
          (request) async {
            if (request.url.path == '/last_backup.json') {
              return http.Response('[1, 2, 3]', 200);
            }
            return http.Response(validJson(), 200);
          },
        );

        final result = await BackupStatusService.fetchStatus(
          client: client,
          pbUrlOverride: kTestUrl,
        );

        expect(result.isSuccess, isTrue);
      });
    });

    // ── Beide Versuche schlagen fehl ─────────────────────────────────────────

    group('Beide Versuche schlagen fehl → unknown', () {
      test('gibt unknown zurück wenn beide Pfade 404 liefern', () async {
        var callCount = 0;
        final client = MockClient(
          (_) async {
            callCount++;
            return http.Response('Not Found', 404);
          },
        );

        final result = await BackupStatusService.fetchStatus(
          client: client,
          pbUrlOverride: kTestUrl,
        );

        expect(callCount, equals(2));
        expect(result.status, equals('unknown'));
        expect(result.timestampUnix, equals(0));
      });

      test('gibt unknown zurück wenn beide Pfade eine Exception werfen', () async {
        final client = MockClient(
          (request) async {
            throw http.ClientException('Network unreachable', request.url);
          },
        );

        final result = await BackupStatusService.fetchStatus(
          client: client,
          pbUrlOverride: kTestUrl,
        );

        expect(result.status, equals('unknown'));
      });
    });

    // ── JSON-Parsing ─────────────────────────────────────────────────────────

    group('JSON-Parsing', () {
      test('parst timestamp_unix und backup_count als String korrekt', () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status': 'success',
              'timestamp': '',
              'timestamp_unix': '1700000000',
              'file': '',
              'size': '',
              'backup_count': '5',
              'keep_days': '14',
              'error': '',
            }),
            200,
          ),
        );

        final result = await BackupStatusService.fetchStatus(
          client: client,
          pbUrlOverride: kTestUrl,
        );

        expect(result.timestampUnix, equals(1700000000));
        expect(result.backupCount, equals(5));
        expect(result.keepDays, equals(14));
      });

      test('nutzt Defaults bei fehlenden optionalen Feldern', () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({'status': 'success'}),
            200,
          ),
        );

        final result = await BackupStatusService.fetchStatus(
          client: client,
          pbUrlOverride: kTestUrl,
        );

        expect(result.status, equals('success'));
        expect(result.timestampUnix, equals(0));
        expect(result.keepDays, equals(7));
        expect(result.file, equals(''));
        expect(result.error, equals(''));
      });
    });

    // ── Farblogik: ageCategory End-to-End ────────────────────────────────────
    // Validiert HTTP → fromJson → ageCategory als integrierten Pfad.
    // Ergänzt die reinen Modell-Tests in backup_status_test.dart.

    group('Farblogik: ageCategory nach fetchStatus()', () {
      int unixSecondsAgo(int hours) =>
          DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 - hours * 3600;

      test('fresh: Backup < 24h → BackupAge.fresh (Grün)', () async {
        final client = MockClient(
          (_) async => http.Response(
            validJson(timestampUnix: unixSecondsAgo(1)),
            200,
          ),
        );

        final result = await BackupStatusService.fetchStatus(
          client: client,
          pbUrlOverride: kTestUrl,
        );

        expect(result.ageCategory, equals(BackupAge.fresh));
      });

      test('aging: Backup 24–72h → BackupAge.aging (Gelb)', () async {
        final client = MockClient(
          (_) async => http.Response(
            validJson(timestampUnix: unixSecondsAgo(48)),
            200,
          ),
        );

        final result = await BackupStatusService.fetchStatus(
          client: client,
          pbUrlOverride: kTestUrl,
        );

        expect(result.ageCategory, equals(BackupAge.aging));
      });

      test('critical: Backup > 72h → BackupAge.critical (Rot)', () async {
        final client = MockClient(
          (_) async => http.Response(
            validJson(timestampUnix: unixSecondsAgo(96)),
            200,
          ),
        );

        final result = await BackupStatusService.fetchStatus(
          client: client,
          pbUrlOverride: kTestUrl,
        );

        expect(result.ageCategory, equals(BackupAge.critical));
      });

      test('critical: error-Status → immer BackupAge.critical (unabhängig vom Alter)',
          () async {
        // Frisches Backup (1h) mit error-Status → trotzdem critical
        final client = MockClient(
          (_) async => http.Response(
            validJson(status: 'error', timestampUnix: unixSecondsAgo(1)),
            200,
          ),
        );

        final result = await BackupStatusService.fetchStatus(
          client: client,
          pbUrlOverride: kTestUrl,
        );

        expect(
          result.ageCategory,
          equals(BackupAge.critical),
          reason: 'error-Status ist immer critical, unabhängig vom Backup-Alter',
        );
      });
    });
  });
}