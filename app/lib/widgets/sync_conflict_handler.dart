// lib/widgets/sync_conflict_handler.dart

import 'package:flutter/material.dart';

import '../screens/conflict_resolution_screen.dart';
import '../services/sync_service.dart';

class SyncConflictHandler {
  static Future<bool> handleSyncWithConflicts(
    BuildContext context,
    SyncService syncService,
  ) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // FIX: await + explizites Typargument <void> für DialogRoute
    await nav.push(
      DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Dialog(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Synchronisiere...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await syncService.syncWithConflictResolution();

      if (!context.mounted) return false;
      nav.pop(); // Schließe Loading Dialog

      if (result['success'] == true) {
        messenger.showSnackBar(
          SnackBar(
            // FIX: .toString() — dynamic → String
            content: Text(
              result['message']?.toString() ?? 'Synchronisation erfolgreich',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
        return true;
      } else if (result.containsKey('conflictData')) {
        final conflicts = result['conflictData'] as List<ConflictData>;

        final resolutionResult = await nav.push<Map<String, int>>(
          MaterialPageRoute(
            builder: (_) => ConflictResolutionScreen(
              conflicts: conflicts,
              syncService: syncService,
            ),
          ),
        );

        if (!context.mounted) return false;

        if (resolutionResult != null) {
          final resolved = resolutionResult['resolved'] ?? 0;
          final skipped = resolutionResult['skipped'] ?? 0;

          final String message;
          final Color color;

          if (resolved > 0 && skipped == 0) {
            message = '$resolved Konflikte erfolgreich aufgelöst';
            color = Colors.green;
          } else if (resolved > 0 && skipped > 0) {
            message = '$resolved Konflikte aufgelöst, $skipped übersprungen';
            color = Colors.orange;
          } else {
            message = 'Alle Konflikte übersprungen';
            color = Colors.grey;
          }

          messenger.showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: color,
              behavior: SnackBarBehavior.floating,
            ),
          );

          return resolved > 0;
        }
      } else {
        // Fehler bei der Synchronisation
        messenger.showSnackBar(
          SnackBar(
            // FIX: .toString() — dynamic → String
            content: Text(
              result['message']?.toString() ?? 'Synchronisation fehlgeschlagen',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                _showErrorDialog(
                  context,
                  // FIX: .toString() — dynamic → String
                  result['error']?.toString() ?? 'Unbekannter Fehler',
                );
              },
            ),
          ),
        );
      }

      return false;
    } catch (e, st) {
      debugPrint('[SyncConflictHandler] Sync fehlgeschlagen: $e\n$st');

      if (context.mounted) nav.pop();

      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Synchronisation fehlgeschlagen: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      return false;
    }
  }

  static void _showErrorDialog(BuildContext context, String error) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Synchronisationsfehler'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bei der Synchronisation ist ein Fehler aufgetreten:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  error,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Mögliche Lösungen:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              const Text('• Internetverbindung prüfen'),
              const Text('• Nextcloud-Einstellungen überprüfen'),
              const Text('• Später erneut versuchen'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Widget für Sync-Button mit Konfliktbehandlung.
  static Widget buildSyncButton(
    BuildContext context,
    SyncService syncService,
  ) {
    return FloatingActionButton.extended(
      onPressed: () => handleSyncWithConflicts(context, syncService),
      icon: const Icon(Icons.sync),
      label: const Text('Sync'),
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
    );
  }

  /// Widget für Sync-Status Anzeige.
  static Widget buildSyncStatus(
    bool isSyncing,
    DateTime? lastSync,
    int? conflictCount,
  ) {
    if (isSyncing) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Synchronisiere...'),
            ],
          ),
        ),
      );
    }

    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    if (lastSync == null) {
      statusColor = Colors.grey;
      statusText = 'Noch nicht synchronisiert';
      statusIcon = Icons.sync_disabled;
    } else {
      final timeDiff = DateTime.now().difference(lastSync);

      if (conflictCount != null && conflictCount > 0) {
        statusColor = Colors.orange;
        statusText = '$conflictCount Konflikte';
        statusIcon = Icons.warning;
      } else if (timeDiff.inMinutes < 5) {
        statusColor = Colors.green;
        statusText = 'Gerade synchronisiert';
        statusIcon = Icons.check_circle;
      } else if (timeDiff.inHours < 1) {
        statusColor = Colors.blue;
        statusText = 'Vor ${timeDiff.inMinutes}m synchronisiert';
        statusIcon = Icons.sync;
      } else {
        statusColor = Colors.grey;
        statusText = 'Vor ${timeDiff.inHours}h synchronisiert';
        statusIcon = Icons.sync;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 16),
            const SizedBox(width: 8),
            Text(
              statusText,
              style: TextStyle(color: statusColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mixin für Screens die Sync-Funktionalität benötigen.
mixin SyncCapable<T extends StatefulWidget> on State<T> {
  bool _isSyncing = false;
  DateTime? _lastSync;
  int? _conflictCount;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSync => _lastSync;
  int? get conflictCount => _conflictCount;

  Future<void> performSync(SyncService syncService) async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final success = await SyncConflictHandler.handleSyncWithConflicts(
        context,
        syncService,
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          _lastSync = DateTime.now();
          _conflictCount = 0;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Widget buildSyncFab(SyncService syncService) =>
      SyncConflictHandler.buildSyncButton(context, syncService);

  Widget buildSyncStatusWidget() => SyncConflictHandler.buildSyncStatus(
        _isSyncing,
        _lastSync,
        _conflictCount,
      );
}