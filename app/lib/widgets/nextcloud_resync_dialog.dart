// lib/widgets/nextcloud_resync_dialog.dart

import 'package:flutter/material.dart';
import '../services/nextcloud_sync_service.dart';

const int _kMaxVisibleErrors = kMaxVisibleErrors;

Future<void> showNextcloudResyncDialog(BuildContext context) async {
  if (!context.mounted) return;

  await showDialog<void>(                    // FIX: await + <void>
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Synchronisiere Dateien...'),
        ],
      ),
    ),
  );

  try {
    final syncService = NextcloudSyncService();
    final initialized = await syncService.init();

    if (!initialized) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nextcloud-Zugangsdaten nicht gefunden.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await syncService.resyncPendingFiles();

    if (!context.mounted) return;
    Navigator.pop(context);

    final message = result.isFullSuccess
        ? 'Synchronisation erfolgreich!\n'
          '${result.successfullySynced} Datei(en) hochgeladen.'
        : 'Synchronisation abgeschlossen mit Fehlern:\n'
          '✓ ${result.successfullySynced} erfolgreich\n'
          '✗ ${result.failed} fehlgeschlagen';

    await showDialog<void>(                  // FIX: await + <void>
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nextcloud Synchronisation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (result.hasErrors) ...[
              const SizedBox(height: 16),
              const Text(
                'Fehler-Details:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...result.errors.take(_kMaxVisibleErrors).map(
                    (error) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $error',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
              if (result.errors.length > _kMaxVisibleErrors)
                Text(
                  '... und ${result.errors.length - _kMaxVisibleErrors} '
                  'weitere Fehler',
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;            // FIX: mounted-Guard nach zweitem await
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isFullSuccess
              ? '${result.successfullySynced} Datei(en) synchronisiert'
              : '${result.successfullySynced} erfolgreich, '
                '${result.failed} Fehler',
        ),
        backgroundColor:
            result.isFullSuccess ? Colors.green : Colors.orange,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Synchronisation fehlgeschlagen: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}