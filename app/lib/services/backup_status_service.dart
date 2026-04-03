// lib/services/backup_status_service.dart
//
// M-008: Liest den Backup-Status aus last_backup.json.
// Die Datei wird vom Backup-Container geschrieben und
// über PocketBase pb_public oder pb_backups bereitgestellt.

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'app_log_service.dart';
import 'pocketbase_service.dart';

/// Repräsentiert den Status des letzten Backups.
class BackupStatus {
  final String status;
  final String timestamp;
  final int timestampUnix;
  final String file;
  final String size;
  final int backupCount;
  final int keepDays;
  final String error;

  const BackupStatus({
    required this.status,
    required this.timestamp,
    required this.timestampUnix,
    required this.file,
    required this.size,
    required this.backupCount,
    required this.keepDays,
    required this.error,
  });

  factory BackupStatus.fromJson(Map<String, dynamic> json) {
    return BackupStatus(
      status: json['status']?.toString() ?? 'unknown',
      timestamp: json['timestamp']?.toString() ?? '',
      timestampUnix: json['timestamp_unix'] is int
          ? json['timestamp_unix'] as int
          : int.tryParse(json['timestamp_unix']?.toString() ?? '0') ?? 0,
      file: json['file']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      backupCount: json['backup_count'] is int
          ? json['backup_count'] as int
          : int.tryParse(json['backup_count']?.toString() ?? '0') ?? 0,
      keepDays: json['keep_days'] is int
          ? json['keep_days'] as int
          : int.tryParse(json['keep_days']?.toString() ?? '7') ?? 7,
      error: json['error']?.toString() ?? '',
    );
  }

  /// Backup war erfolgreich.
  bool get isSuccess => status == 'success';

  /// Backup hatte einen Fehler.
  bool get isError => status == 'error';

  /// Zeitpunkt des letzten Backups als DateTime.
  DateTime get lastBackupTime =>
      DateTime.fromMillisecondsSinceEpoch(timestampUnix * 1000, isUtc: true);

  /// Alter des letzten Backups.
  Duration get age => DateTime.now().toUtc().difference(lastBackupTime);

  /// Backup-Alter-Kategorie für Farbcodierung.
  BackupAge get ageCategory {
    if (isError) return BackupAge.critical;
    final hours = age.inHours;
    if (hours < 24) return BackupAge.fresh;
    if (hours < 72) return BackupAge.aging;
    return BackupAge.critical;
  }

  /// Menschenlesbare Altersanzeige.
  String get ageText {
    if (timestampUnix == 0) return 'Nie';
    final d = age;
    if (d.inMinutes < 1) return 'Gerade eben';
    if (d.inMinutes < 60) return 'Vor ${d.inMinutes}m';
    if (d.inHours < 24) return 'Vor ${d.inHours}h';
    if (d.inDays < 7) return 'Vor ${d.inDays} Tag${d.inDays == 1 ? '' : 'en'}';
    return 'Vor ${d.inDays} Tagen ⚠️';
  }

  /// Unbekannter/leerer Status.
  static const BackupStatus unknown = BackupStatus(
    status: 'unknown',
    timestamp: '',
    timestampUnix: 0,
    file: '',
    size: '',
    backupCount: 0,
    keepDays: 7,
    error: '',
  );
}

/// Backup-Alter-Kategorie für UI-Farbcodierung.
enum BackupAge {
  /// < 24h — alles gut
  fresh,

  /// 24h–72h — Aufmerksamkeit nötig
  aging,

  /// > 72h oder Fehler — kritisch
  critical,
}

/// Service zum Abrufen des Backup-Status.
class BackupStatusService {
  static final _logger = AppLogService.logger;

  /// Liest den Backup-Status vom Server.
  ///
  /// Versucht die Datei unter folgenden Pfaden:
  /// 1. `{pbUrl}/last_backup.json` (pb_public)
  /// 2. `{pbUrl}/api/backups/status` (falls custom Endpoint)
  ///
  /// Gibt [BackupStatus.unknown] zurück wenn nicht erreichbar.
  static Future<BackupStatus> fetchStatus() async {
    final pbUrl = PocketBaseService().url;
    if (pbUrl.isEmpty) {
      _logger.w('[BackupStatus] Keine PocketBase-URL konfiguriert');
      return BackupStatus.unknown;
    }

    // Versuch 1: pb_public/last_backup.json
    try {
      final url = '$pbUrl/last_backup.json';
      _logger.d('[BackupStatus] Lade von $url');

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final status = BackupStatus.fromJson(json);
        _logger.d(
          '[BackupStatus] Status: ${status.status}, '
          'Alter: ${status.ageText}',
        );
        return status;
      }

      _logger.w(
        '[BackupStatus] HTTP ${response.statusCode} von $url',
      );
    } catch (e) {
      _logger.d('[BackupStatus] pb_public nicht erreichbar: $e');
    }

    // Versuch 2: Direkter Pfad (falls Backup-Volume anders gemountet)
    try {
      final url = '$pbUrl/backups/last_backup.json';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return BackupStatus.fromJson(json);
      }
    } catch (e) {
      _logger.d('[BackupStatus] Alternativer Pfad nicht erreichbar: $e');
    }

    _logger.w('[BackupStatus] Backup-Status nicht verfügbar');
    return BackupStatus.unknown;
  }
}