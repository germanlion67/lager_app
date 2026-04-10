// test/services/backup_status_test.dart
//
// Unit-Tests für BackupStatus (Modell-Logik).
//
// Testet:
//   - fromJson(): Normalfall, Null-Handling, Typ-Koercion
//   - Getter: isSuccess, isError, lastBackupTime, ageCategory, ageText
//   - BackupStatus.unknown
//   - BackupAge Enum

import 'package:flutter_test/flutter_test.dart';
import 'package:lager_app/services/backup_status_service.dart';

void main() {
  group('BackupStatus', () {
    int hoursAgo(int hours) {
      return DateTime.now()
              .toUtc()
              .subtract(Duration(hours: hours))
              .millisecondsSinceEpoch ~/
          1000;
    }

    Map<String, dynamic> createJson({
      String status = 'success',
      String timestamp = '2025-03-15T14:30:00Z',
      int? timestampUnix,
      String file = 'backup_20250315.zip',
      String size = '45.2 MB',
      int backupCount = 5,
      int keepDays = 7,
      String error = '',
    }) {
      return {
        'status': status,
        'timestamp': timestamp,
        'timestamp_unix': timestampUnix ?? hoursAgo(2),
        'file': file,
        'size': size,
        'backup_count': backupCount,
        'keep_days': keepDays,
        'error': error,
      };
    }

    group('fromJson()', () {
      test('parst vollständiges JSON korrekt', () {
        final json = createJson();
        final status = BackupStatus.fromJson(json);

        expect(status.status, 'success');
        expect(status.timestamp, '2025-03-15T14:30:00Z');
        expect(status.file, 'backup_20250315.zip');
        expect(status.size, '45.2 MB');
        expect(status.backupCount, 5);
        expect(status.keepDays, 7);
        expect(status.error, '');
      });

      test('behandelt null-Werte graceful', () {
        final status = BackupStatus.fromJson({});

        expect(status.status, 'unknown');
        expect(status.timestamp, '');
        expect(status.timestampUnix, 0);
        expect(status.file, '');
        expect(status.size, '');
        expect(status.backupCount, 0);
        expect(status.keepDays, 7);
        expect(status.error, '');
      });

      test('konvertiert String-Zahlen zu int', () {
        final json = {
          'status': 'success',
          'timestamp_unix': '1710510600',
          'backup_count': '3',
          'keep_days': '14',
        };

        final status = BackupStatus.fromJson(json);

        expect(status.timestampUnix, 1710510600);
        expect(status.backupCount, 3);
        expect(status.keepDays, 14);
      });

      test('parst Fehler-Status', () {
        final json = createJson(status: 'error', error: 'Disk full');
        final status = BackupStatus.fromJson(json);

        expect(status.status, 'error');
        expect(status.error, 'Disk full');
      });
    });

    group('isSuccess / isError', () {
      test('isSuccess bei status "success"', () {
        final status = BackupStatus.fromJson(createJson(status: 'success'));
        expect(status.isSuccess, isTrue);
        expect(status.isError, isFalse);
      });

      test('isError bei status "error"', () {
        final status = BackupStatus.fromJson(createJson(status: 'error'));
        expect(status.isError, isTrue);
        expect(status.isSuccess, isFalse);
      });

      test('weder success noch error bei "unknown"', () {
        final status = BackupStatus.fromJson(createJson(status: 'unknown'));
        expect(status.isSuccess, isFalse);
        expect(status.isError, isFalse);
      });
    });

    group('lastBackupTime', () {
      test('konvertiert Unix-Timestamp zu DateTime UTC', () {
        final json = createJson(timestampUnix: 1710510600);
        final status = BackupStatus.fromJson(json);

        expect(status.lastBackupTime.isUtc, isTrue);
        expect(status.lastBackupTime.year, 2024);
      });

      test('gibt Epoch bei timestampUnix 0', () {
        final json = createJson(timestampUnix: 0);
        final status = BackupStatus.fromJson(json);

        expect(status.lastBackupTime, DateTime.utc(1970));
      });
    });

    group('ageCategory', () {
      test('fresh bei < 24h', () {
        final json = createJson(timestampUnix: hoursAgo(1));
        final status = BackupStatus.fromJson(json);

        expect(status.ageCategory, BackupAge.fresh);
      });

      test('aging bei 24h–72h', () {
        final json = createJson(timestampUnix: hoursAgo(48));
        final status = BackupStatus.fromJson(json);

        expect(status.ageCategory, BackupAge.aging);
      });

      test('critical bei > 72h', () {
        final json = createJson(timestampUnix: hoursAgo(100));
        final status = BackupStatus.fromJson(json);

        expect(status.ageCategory, BackupAge.critical);
      });

      test('critical bei Error unabhängig vom Alter', () {
        final json = createJson(
          status: 'error',
          timestampUnix: hoursAgo(1),
        );
        final status = BackupStatus.fromJson(json);

        expect(status.ageCategory, BackupAge.critical);
      });
    });

    group('ageText', () {
      test('"Nie" bei timestampUnix 0', () {
        final json = createJson(timestampUnix: 0);
        final status = BackupStatus.fromJson(json);

        expect(status.ageText, 'Nie');
      });

      test('zeigt Stunden bei < 24h', () {
        final json = createJson(timestampUnix: hoursAgo(5));
        final status = BackupStatus.fromJson(json);

        expect(status.ageText, matches(RegExp(r'Vor \d+h')));
      });

      test('zeigt Tage bei >= 24h und < 7 Tage', () {
        final json = createJson(timestampUnix: hoursAgo(48));
        final status = BackupStatus.fromJson(json);

        expect(status.ageText, contains('Tag'));
      });

      test('zeigt Warnung bei >= 7 Tage', () {
        final json = createJson(timestampUnix: hoursAgo(200));
        final status = BackupStatus.fromJson(json);

        expect(status.ageText, contains('⚠️'));
      });

      test('Singular "Tag" bei genau 1 Tag', () {
        final json = createJson(timestampUnix: hoursAgo(24));
        final status = BackupStatus.fromJson(json);

        expect(status.ageText, 'Vor 1 Tag');
      });

      test('Plural "Tagen" bei > 1 Tag', () {
        final json = createJson(timestampUnix: hoursAgo(72));
        final status = BackupStatus.fromJson(json);

        expect(status.ageText, contains('Tagen'));
      });
    });

    group('BackupStatus.unknown', () {
      test('hat erwartete Defaults', () {
        const status = BackupStatus.unknown;

        expect(status.status, 'unknown');
        expect(status.timestamp, '');
        expect(status.timestampUnix, 0);
        expect(status.file, '');
        expect(status.size, '');
        expect(status.backupCount, 0);
        expect(status.keepDays, 7);
        expect(status.error, '');
      });

      test('ist weder success noch error', () {
        const status = BackupStatus.unknown;

        expect(status.isSuccess, isFalse);
        expect(status.isError, isFalse);
      });

      test('ageText ist "Nie"', () {
        const status = BackupStatus.unknown;
        expect(status.ageText, 'Nie');
      });
    });

    group('BackupAge', () {
      test('hat drei Werte', () {
        expect(BackupAge.values.length, 3);
        expect(BackupAge.values, contains(BackupAge.fresh));
        expect(BackupAge.values, contains(BackupAge.aging));
        expect(BackupAge.values, contains(BackupAge.critical));
      });
    });
  });
}
