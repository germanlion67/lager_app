import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

class AppLogService {
  static final AppLogService _instance = AppLogService._internal();
  factory AppLogService() => _instance;
  AppLogService._internal();

  Future<File> _getLogFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/app_debug.log');
  }

  Future<void> log(String message) async {
    final file = await _getLogFile();
    final now = DateTime.now().toIso8601String();
    await file.writeAsString('[$now] $message\n', mode: FileMode.append, flush: true);
  }

  Future<void> logError(String error, [StackTrace? stack]) async {
    final file = await _getLogFile();
    final now = DateTime.now().toIso8601String();
    final stackStr = stack != null ? '\n$stack' : '';
    await file.writeAsString('[$now] ERROR: $error$stackStr\n', mode: FileMode.append, flush: true);
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
