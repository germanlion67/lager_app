// lib/widgets/sync_conflict_handler.dart

import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../screens/conflict_resolution_screen.dart';

class SyncConflictHandler {
  static Future<bool> handleSyncWithConflicts(
    BuildContext context,
    SyncService syncService,
  ) async {
    try {
      // Zeige Loading Indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Dialog(
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
      );

      // Starte erweiterte Synchronisation
      final result = await syncService.syncWithConflictResolution();
      
      // Schließe Loading Dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (!context.mounted) return false;

      if (result['success'] == true) {
        // Erfolgreiche Synchronisation ohne Konflikte
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Synchronisation erfolgreich'),
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
        // Konflikte gefunden - zeige Resolution UI
        final conflicts = result['conflictData'] as List<ConflictData>;
        
        final resolutionResult = await Navigator.of(context).push<Map<String, int>>(
          MaterialPageRoute(
            builder: (context) => ConflictResolutionScreen(
              conflicts: conflicts,
              syncService: syncService,
            ),
          ),
        );

        if (context.mounted && resolutionResult != null) {
          final resolved = resolutionResult['resolved'] ?? 0;
          final skipped = resolutionResult['skipped'] ?? 0;
          
          String message;
          Color color;
          
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

          ScaffoldMessenger.of(context).showSnackBar(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Synchronisation fehlgeschlagen'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                _showErrorDialog(context, result['error'] ?? 'Unbekannter Fehler');
              },
            ),
          ),
        );
      }
      
      return false;
    } catch (e) {
      // Schließe Loading Dialog falls noch offen
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Widget für Sync-Button mit Konfliktbehandlung
  static Widget buildSyncButton(BuildContext context, SyncService syncService) {
    return FloatingActionButton.extended(
      onPressed: () => handleSyncWithConflicts(context, syncService),
      icon: const Icon(Icons.sync),
      label: const Text('Sync'),
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
    );
  }

  /// Widget für Sync-Status Anzeige
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

    Color statusColor = Colors.grey;
    String statusText = 'Noch nicht synchronisiert';
    IconData statusIcon = Icons.sync_disabled;

    if (lastSync != null) {
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

/// Mixin für Screens die Sync-Funktionalität benötigen
mixin SyncCapable<T extends StatefulWidget> on State<T> {
  bool _isSyncing = false;
  DateTime? _lastSync;
  int? _conflictCount;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSync => _lastSync;
  int? get conflictCount => _conflictCount;

  Future<void> performSync(SyncService syncService) async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final success = await SyncConflictHandler.handleSyncWithConflicts(
        context,
        syncService,
      );

      if (success) {
        setState(() {
          _lastSync = DateTime.now();
          _conflictCount = 0;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Widget buildSyncFab(SyncService syncService) {
    return SyncConflictHandler.buildSyncButton(context, syncService);
  }

  Widget buildSyncStatusWidget() {
    return SyncConflictHandler.buildSyncStatus(_isSyncing, _lastSync, _conflictCount);
  }
}