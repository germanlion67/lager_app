import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Neu hinzufügen

class AppLogService {
  static final AppLogService _instance = AppLogService._internal();
  factory AppLogService() => _instance;
  AppLogService._internal();
  final List<String> _webLogs = []; 

  // Getter, um die Logs im Web-UI anzeigen zu können
  List<String> get webLogs => _webLogs;
  
  Future<dynamic> _getLogFile() async {
    // path_provider wirft im Web Fehler, wenn man getApplicationDocumentsDirectory() ruft
    if (kIsWeb) return null; 
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/app_debug.log');
  }

  Future<File> _getLogFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/app_debug.log');
  }

  Future<void> log(String message) async {
    final now = DateTime.now().toIso8601String();
    final logLine = '[$now] $message';

    if (kIsWeb) {
      _webLogs.add(logLine);
      debugPrint(logLine); // Optional: Auch in die Browser-Konsole schreiben
      return;
    }

    final file = await _getLogFile();
    await file.writeAsString('$logLine\n', mode: FileMode.append, flush: true);
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
    await file.writeAsString('$logLine\n', mode: FileMode.append, flush: true);
  }

  Future<String> readLog() async {
    final file = await _getLogFile();
    if (await file.exists()) {
      return await file.readAsString();
    }
    return '';
  }

  Future<void> clearLog() async {
    final file = await _getLogFile();
    if (await file.exists()) {
      await file.writeAsString('');
    }
  }

  static Future<void> showLogDialog(BuildContext context) async {
    final logContent = await AppLogService().readLog();
    if (!context.mounted) return;
    final result = await showDialog<bool>(
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
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop(true);
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
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logdatei gelöscht')),
      );
    }
  }
}
