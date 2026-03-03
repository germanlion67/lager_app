import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AppLogService {
  static final AppLogService _instance = AppLogService._internal();
  factory AppLogService() => _instance;
  AppLogService._internal();

  final List<String> _webLogs = [];
  List<String> get webLogs => _webLogs;

  // Gibt File? zurück, damit der Compiler weiß: Es kann null sein.
  Future<File?> _getLogFile() async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/app_debug.log');
    } catch (e) {
      debugPrint("Fehler beim Zugriff auf Filesystem: $e");
      return null;
    }
  }

  Future<void> log(String message) async {
    final now = DateTime.now().toIso8601String();
    final logLine = '[$now] $message';

    if (kIsWeb) {
      _webLogs.add(logLine);
      debugPrint(logLine);
      return;
    }

    final file = await _getLogFile();
    // WICHTIG: Null-Check für den Compiler
    if (file != null) {
      await file.writeAsString('$logLine\n', mode: FileMode.append, flush: true);
    }
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

    final file = await _getLogFile();
    if (file != null) {
      await file.writeAsString('$logLine\n', mode: FileMode.append, flush: true);
    }
  }

  Future<String> readLog() async {
    if (kIsWeb) {
      return _webLogs.isEmpty ? 'Keine Logeinträge vorhanden.' : _webLogs.join('\n');
    }

    final file = await _getLogFile();
    if (file != null && await file.exists()) {
      return await file.readAsString();
    }
    return '';
  }

  Future<void> clearLog() async {
    if (kIsWeb) {
      _webLogs.clear();
      return;
    }

    final file = await _getLogFile();
    if (file != null && await file.exists()) {
      await file.writeAsString('');
    }
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
            child: Text(logContent.isEmpty ? 'Keine Logeinträge vorhanden.' : logContent),
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
