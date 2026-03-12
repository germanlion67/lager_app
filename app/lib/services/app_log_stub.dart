// lib/services/app_log_stub.dart
// Web-Stubs: Logs werden in-memory in AppLogService._webLogs gehalten.
// Alle Datei-Operationen sind No-Ops.

Future<void> appendToLogFile(String logLine) async {
  // Web: in-memory via AppLogService._webLogs
}

Future<String> readLogFile() async {
  return '';
}

Future<void> clearLogFile() async {
  // Web: AppLogService._webLogs.clear() übernimmt das
}

// FIX #13: Stub — Web hat keine Datei, Größe ist immer 0
Future<int> getLogFileSizeBytes() async {
  return 0;
}

// FIX #13: Stub — Web-Rotation läuft direkt in AppLogService
Future<void> rotateLogFile() async {
  // Web: _rotateWebLogsIfNeeded() in AppLogService übernimmt das
}