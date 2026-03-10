// lib/services/app_log_io.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

Future<File?> _getLogFile() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/app_debug.log');
  } catch (e) {
    debugPrint('Fehler beim Zugriff auf Filesystem: $e');
    return null;
  }
}

Future<void> appendToLogFile(String logLine) async {
  final file = await _getLogFile();
  if (file != null) {
    await file.writeAsString('$logLine\n', mode: FileMode.append, flush: true);
  }
}

Future<String> readLogFile() async {
  final file = await _getLogFile();
  if (file != null && await file.exists()) {
    return await file.readAsString();
  }
  return '';
}

Future<void> clearLogFile() async {
  final file = await _getLogFile();
  if (file != null && await file.exists()) {
    await file.writeAsString('');
  }
}
