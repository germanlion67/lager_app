// lib/core/app_logger.dart
//
// Dünner Wrapper um AppLogService.
// Kein eigener Logger, kein eigener Puffer — alles läuft durch AppLogService.
//
// VERWENDUNG (unverändert):
//   import 'package:lager_app/core/app_logger.dart';
//   final Logger _logger = AppLogger.create();
//
// LOG-LEVEL REFERENZ:
//   _logger.t('Trace')    → Sehr detailliert
//   _logger.d('Debug')    → Normales Debugging
//   _logger.i('Info')     → Wichtige Ereignisse
//   _logger.w('Warning')  → Unerwartet, aber kein Absturz
//   _logger.e('Error')    → Fehler in catch-Blöcken
//   _logger.f('Fatal')    → Kritisch

import 'package:logger/logger.dart';
import '../services/app_log_service.dart';

abstract final class AppLogger {
  /// Gibt immer AppLogService.logger zurück — keinen neuen Logger.
  /// Kein eigener Puffer, kein eigener Output.
  static Logger create() => AppLogService.logger;

  /// Direktzugriff — identisch mit AppLogService.logger.
  static Logger get logger => AppLogService.logger;
}