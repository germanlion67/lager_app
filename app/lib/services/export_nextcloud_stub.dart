// lib/services/export_nextcloud_stub.dart
//
// Web-Stub für Nextcloud-Export-Funktionen.
// Wird via Conditional Import eingebunden:
//
//   import 'export_nextcloud_io.dart'
//       if (dart.library.html) 'export_nextcloud_stub.dart';
//
// Im Web sind Nextcloud-Uploads nicht verfügbar.
// Die Funktionen geben dem Nutzer ein sichtbares Feedback
// statt lautlos zu scheitern.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../services/app_log_service.dart';

final _logger = AppLogService.logger;


/// Web-Stub: Zeigt dem Nutzer eine Meldung dass der Upload
/// im Web nicht verfügbar ist, statt lautlos zurückzukehren.
Future<void> uploadZipToNextcloud(
  String zipFilePath, {
  BuildContext? context,
}) async {
  // FIX Hinweis 3: Debug-Log damit Stub-Aufrufe in der Entwicklung
  // sichtbar sind — verhindert stille Fehler.
  if (kDebugMode) {
    _logger.d(
      '[Nextcloud Stub] uploadZipToNextcloud() aufgerufen — '
      'nicht verfügbar im Web.',
    );
  }

  // FIX Problem 1: Nutzer-Feedback wenn Context vorhanden,
  // statt lautlos zurückzukehren.
  if (context != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Nextcloud-Upload ist im Web nicht verfügbar.',
        ),
      ),
    );
  }
}

/// Web-Stub: Zeigt dem Nutzer eine Meldung dass das Backup
/// im Web nicht verfügbar ist.
Future<void> backupWithImagesToNextcloud(
  // FIX Problem 2: BuildContext konsistent non-nullable —
  // entspricht der _io.dart-Signatur und dem Aufruf-Pattern.
  BuildContext context,
) async {
  if (kDebugMode) {
    _logger.d(
      '[Nextcloud Stub] backupWithImagesToNextcloud() aufgerufen — '
      'nicht verfügbar im Web.',
    );
  }

  // FIX Problem 1: Context ist garantiert vorhanden — immer Feedback geben.
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Nextcloud-Backup ist im Web nicht verfügbar.',
        ),
      ),
    );
  }
}