// lib/services/app_log_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional import für Datei-Operationen
import 'app_log_io.dart'
    if (dart.library.html) 'app_log_stub.dart' as platform;

class AppLogService {
  static final AppLogService _instance = AppLogService._internal();
  factory AppLogService() => _instance;
  AppLogService._internal();

  // FIX #14: Mutex-Queue — verhindert Race Conditions beim Schreiben.
  // Alle Schreiboperationen werden sequenziell abgearbeitet.
  Future<void> _lastOperation = Future.value();

  // FIX #13: Maximale Log-Dateigröße in Bytes (Standard: 512 KB)
  static const int _maxLogSizeBytes = 512 * 1024;

  // FIX #14: Unmodifiable — verhindert externe Mutation der Liste
  final List<String> _webLogs = [];
  List<String> get webLogs => List.unmodifiable(_webLogs);

  // ==================== SCHREIBEN ====================

  Future<void> log(String message) async {
    // Konsistent mit Fix #8: UTC-Timestamps überall
    final now = DateTime.now().toUtc().toIso8601String();
    final logLine = '[$now] $message';

    if (kIsWeb) {
      // FIX #13: Web-Rotation bei zu vielen Einträgen
      _rotateWebLogsIfNeeded();
      _webLogs.add(logLine);
      debugPrint(logLine);
      return;
    }

    // FIX #14: Schreiboperation in die Mutex-Queue einreihen
    _lastOperation = _lastOperation.then((_) async {
      try {
        // FIX #13: Vor dem Schreiben Größe prüfen und ggf. rotieren
        await _rotateIfNeeded();
        await platform.appendToLogFile(logLine);
      } catch (e) {
        debugPrint('⚠️ AppLogService.log Fehler: $e');
      }
    });
    await _lastOperation;
  }

  Future<void> logError(String error, [StackTrace? stack]) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final stackStr = stack != null ? '\n$stack' : '';
    final logLine = '[$now] ERROR: $error$stackStr';

    if (kIsWeb) {
      // FIX #13: Web-Rotation bei zu vielen Einträgen
      _rotateWebLogsIfNeeded();
      _webLogs.add(logLine);
      debugPrint(logLine);
      return;
    }

    // FIX #14: Schreiboperation in die Mutex-Queue einreihen
    _lastOperation = _lastOperation.then((_) async {
      try {
        // FIX #13: Vor dem Schreiben Größe prüfen und ggf. rotieren
        await _rotateIfNeeded();
        await platform.appendToLogFile(logLine);
      } catch (e) {
        debugPrint('⚠️ AppLogService.logError Fehler: $e');
      }
    });
    await _lastOperation;
  }

  // ==================== LESEN ====================

  Future<String> readLog() async {
    if (kIsWeb) {
      return _webLogs.isEmpty
          ? 'Keine Logeinträge vorhanden.'
          : _webLogs.join('\n');
    }

    try {
      return await platform.readLogFile();
    } catch (e) {
      return 'Fehler beim Lesen des Logs: $e';
    }
  }

  // ==================== LÖSCHEN ====================

  Future<void> clearLog() async {
    if (kIsWeb) {
      _webLogs.clear();
      return;
    }

    // FIX #14: Auch clearLog in die Mutex-Queue einreihen
    _lastOperation = _lastOperation.then((_) async {
      try {
        await platform.clearLogFile();
      } catch (e) {
        debugPrint('⚠️ AppLogService.clearLog Fehler: $e');
      }
    });
    await _lastOperation;
  }

  // ==================== LOG-ROTATION ====================

  // FIX #13: Web-Rotation — bei >1000 Einträgen werden
  // die ältesten 200 entfernt
  void _rotateWebLogsIfNeeded() {
    if (_webLogs.length >= 1000) {
      _webLogs.removeRange(0, 200);
      _webLogs.insert(
        0,
        '[...Log rotiert — ${DateTime.now().toUtc().toIso8601String()}...]',
      );
    }
  }

  // FIX #13: Native Rotation — prüft Dateigröße via platform,
  // delegiert Rotation an app_log_io.dart
  Future<void> _rotateIfNeeded() async {
    try {
      final sizeBytes = await platform.getLogFileSizeBytes();
      if (sizeBytes >= _maxLogSizeBytes) {
        await platform.rotateLogFile();
        debugPrint(
          '🔄 AppLogService: Log rotiert '
          '(Größe war ${sizeBytes ~/ 1024} KB)',
        );
      }
    } catch (e) {
      // Rotation-Fehler sind nicht kritisch — weiter loggen
      debugPrint('⚠️ AppLogService._rotateIfNeeded Fehler: $e');
    }
  }

  // ==================== DIALOG ====================

  static Future<void> showLogDialog(BuildContext context) async {
    final logContent = await AppLogService().readLog();
    if (!context.mounted) return;

    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('App-Log'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              logContent.isEmpty
                  ? 'Keine Logeinträge vorhanden.'
                  : logContent,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await AppLogService().clearLog();
              if (ctx.mounted) Navigator.of(ctx).pop(true);
            },
            child: const Text('Log löschen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }
}