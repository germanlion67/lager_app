// lib/services/app_log_io.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

// ==================== HELPER ====================

Future<File?> _getLogFile() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/app_debug.log');
  } catch (e) {
    debugPrint('Fehler beim Zugriff auf Filesystem: $e');
    return null;
  }
}

// FIX #13: Backup-Datei für Log-Rotation
Future<File?> _getLogBackupFile() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/app_debug.log.bak');
  } catch (e) {
    debugPrint('Fehler beim Zugriff auf Backup-Log-Datei: $e');
    return null;
  }
}

// ==================== SCHREIBEN ====================

Future<void> appendToLogFile(String logLine) async {
  final file = await _getLogFile();
  if (file != null) {
    await file.writeAsString(
      '$logLine\n',
      mode: FileMode.append,
      flush: true,
    );
  }
}

// ==================== LESEN ====================

Future<String> readLogFile() async {
  final file = await _getLogFile();
  if (file != null && await file.exists()) {
    return await file.readAsString();
  }
  return '';
}

// ==================== LÖSCHEN ====================

Future<void> clearLogFile() async {
  final file = await _getLogFile();
  if (file != null && await file.exists()) {
    await file.writeAsString('');
  }
}

// ==================== LOG-ROTATION ====================

// FIX #13: Gibt die aktuelle Log-Dateigröße in Bytes zurück.
// Gibt 0 zurück wenn die Datei nicht existiert.
Future<int> getLogFileSizeBytes() async {
  try {
    final file = await _getLogFile();
    if (file == null || !await file.exists()) return 0;
    final stat = await file.stat();
    return stat.size;
  } catch (e) {
    debugPrint('Fehler beim Lesen der Log-Dateigröße: $e');
    return 0;
  }
}

// FIX #13: Rotiert die Log-Datei:
// 1. Bestehende .bak-Datei löschen (falls vorhanden)
// 2. Aktuelle Log → .bak umbenennen
// 3. Neue leere Log-Datei mit Rotations-Marker anlegen
Future<void> rotateLogFile() async {
  try {
    final logFile = await _getLogFile();
    final bakFile = await _getLogBackupFile();

    if (logFile == null || bakFile == null) return;

    // Schritt 1: Alte .bak löschen
    if (await bakFile.exists()) {
      await bakFile.delete();
    }

    // Schritt 2: Aktuelle Log → .bak umbenennen
    if (await logFile.exists()) {
      await logFile.rename(bakFile.path);
    }

    // Schritt 3: Neue leere Log-Datei mit Rotations-Marker anlegen
    await logFile.writeAsString(
      '[Log rotiert — ${DateTime.now().toUtc().toIso8601String()}]\n',
      flush: true,
    );

    debugPrint('✅ Log-Rotation abgeschlossen: ${bakFile.path}');
  } catch (e) {
    debugPrint('❌ Fehler bei der Log-Rotation: $e');
    // Kein rethrow — Rotation-Fehler dürfen das Logging nicht blockieren
  }
}