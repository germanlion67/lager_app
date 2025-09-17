import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
}
