// lib/widgets/nextcloud_resync_dialog.dart

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/nextcloud_sync_service.dart';

const int _kMaxVisibleErrors = kMaxVisibleErrors;

Future<void> showNextcloudResyncDialog(BuildContext context) async {
  if (!context.mounted) return;

  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(width: AppConfig.spacingLarge),
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
        SnackBar(
          content: const Text('Nextcloud-Zugangsdaten nicht gefunden.'),
          backgroundColor: colorScheme.error,
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

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nextcloud Synchronisation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (result.hasErrors) ...[
              const SizedBox(height: AppConfig.spacingLarge),
              Text(
                'Fehler-Details:',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppConfig.spacingSmall),
              ...result.errors.take(_kMaxVisibleErrors).map(
                    (error) => Padding(
                      padding: const EdgeInsets.only(
                          bottom: AppConfig.spacingXSmall,),
                      child: Text(
                        '• $error',
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ),
              if (result.errors.length > _kMaxVisibleErrors)
                Text(
                  '... und ${result.errors.length - _kMaxVisibleErrors} '
                  'weitere Fehler',
                  style: textTheme.bodySmall,
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

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isFullSuccess
              ? '${result.successfullySynced} Datei(en) synchronisiert'
              : '${result.successfullySynced} erfolgreich, '
                '${result.failed} Fehler',
        ),
        backgroundColor:
            result.isFullSuccess ? colorScheme.tertiary : colorScheme.secondary,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Synchronisation fehlgeschlagen: $e'),
        backgroundColor: colorScheme.error,
      ),
    );
  }
}