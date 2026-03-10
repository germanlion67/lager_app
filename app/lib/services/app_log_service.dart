// lib/services/app_log_service.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional import für Datei-Operationen
import 'app_log_io.dart'
    if (dart.library.html) 'app_log_stub.dart' as platform;

class AppLogService {
  static final AppLogService _instance = AppLogService._internal();
  factory AppLogService() => _instance;
  AppLogService._internal();

  final List<String> _webLogs = [];
  List<String> get webLogs => _webLogs;

  Future<void> log(String message) async {
    final now = DateTime.now().toIso8601String();
    final logLine = '[$now] $message';

    if (kIsWeb) {
      _webLogs.add(logLine);
      debugPrint(logLine);
      return;
    }

    await platform.appendToLogFile(logLine);
  }

  Future<void> logError(String error, [StackTrace? stack]) async {
    final now = DateTime.now().toIso8601String();
    final stackStr = stack != null ? '\n$stack' : '';
    final logLine = '[$now] ERROR: $error$stackStr';

    if (kIsWeb) {
      _webLogs.add(logLine);
      debugPrint(logLine);
      return;
    }

    await platform.appendToLogFile(logLine);
  }

  Future<String> readLog() async {
    if (kIsWeb) {
      return _webLogs.isEmpty
          ? 'Keine Logeinträge vorhanden.'
          : _webLogs.join('\n');
    }

    return await platform.readLogFile();
  }

  Future<void> clearLog() async {
    if (kIsWeb) {
      _webLogs.clear();
      return;
    }

    await platform.clearLogFile();
  }

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
              logContent.isEmpty ? 'Keine Logeinträge vorhanden.' : logContent,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
