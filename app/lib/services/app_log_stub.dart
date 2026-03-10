// lib/services/app_log_stub.dart

Future<void> appendToLogFile(String logLine) async {
  // Im Web: Logs werden in-memory gehalten (AppLogService._webLogs)
}

Future<String> readLogFile() async {
  return '';
}

Future<void> clearLogFile() async {
  // Nichts zu tun im Web
}
