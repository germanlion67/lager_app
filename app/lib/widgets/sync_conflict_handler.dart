// lib/widgets/sync_conflict_handler.dart
//
// O-004 Batch 3: Alle hardcodierten Farben durch colorScheme ersetzt,
// alle Magic-Number-Abstände/Radien durch AppConfig-Tokens.
//
// M-004: DialogRoute-Ladeindikator → AppLoadingOverlay (via _isSyncing State).
// M-003: Rohe $e-Strings → AppErrorHandler.showSnackBarWithDetails().
//        _showErrorDialog() → AppErrorHandler._showErrorDialog() intern.

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../core/app_exception.dart';
import '../screens/conflict_resolution_screen.dart';
import '../services/app_log_service.dart';
import '../services/sync_service.dart';
import '../widgets/app_error_handler.dart';


class SyncConflictHandler {
  static final _logger = AppLogService.logger;

  // M-003 + M-004: Kein DialogRoute mehr.
  // Der Aufrufer (SyncCapable.performSync) setzt _isSyncing = true,
  // wodurch das AppLoadingOverlay im Stack des jeweiligen Screens
  // erscheint. handleSyncWithConflicts() selbst zeigt kein Overlay.
  static Future<bool> handleSyncWithConflicts(
    BuildContext context,
    SyncService syncService,
  ) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    try {
      final result = await syncService.syncWithConflictResolution();

      if (!context.mounted) return false;

      if (result['success'] == true) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ??
                  'Synchronisation erfolgreich',
            ),
            backgroundColor: colorScheme.tertiary,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'OK',
              textColor: colorScheme.onTertiary,
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
            color = colorScheme.tertiary;
          } else if (resolved > 0 && skipped > 0) {
            message =
                '$resolved Konflikte aufgelöst, $skipped übersprungen';
            color = colorScheme.secondary;
          } else {
            message = 'Alle Konflikte übersprungen';
            color = colorScheme.onSurfaceVariant;
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
        // M-003: Sync-Fehler aus result['error'] als SyncException
        //        klassifizieren und mit Details-Button anzeigen.
        final rawError = result['error']?.toString();
        final appEx = rawError != null
            ? SyncException(
                message: result['message']?.toString() ??
                    'Synchronisation fehlgeschlagen.',
                technicalDetail: rawError,
              )
            : const SyncException();

        AppErrorHandler.showSnackBarWithDetails(context, appEx);
      }

      return false;
    } catch (e, st) {
      _logger.e(
        '[SyncConflictHandler] Sync fehlgeschlagen',
        error: e,
        stackTrace: st,
      );

      if (!context.mounted) return false;

      // M-003: Roher $e-String → AppErrorHandler klassifiziert automatisch
      //        (SocketException → NetworkException etc.)
      AppErrorHandler.showSnackBarWithDetails(
        context,
        e,
        stackTrace: st,
        contextLabel: 'SyncConflictHandler',
      );

      return false;
    }
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
          padding: EdgeInsets.all(AppConfig.spacingMedium),
          child: Row(
            children: [
              SizedBox(
                width: AppConfig.iconSizeSmall,
                height: AppConfig.iconSizeSmall,
                child: CircularProgressIndicator(
                  strokeWidth: AppConfig.strokeWidthMedium,
                ),
              ),
              SizedBox(width: AppConfig.spacingSmall),
              Text('Synchronisiere...'),
            ],
          ),
        ),
      );
    }

    return _SyncStatusCard(
      lastSync: lastSync,
      conflictCount: conflictCount,
    );
  }
}

/// Separates Widget für den Sync-Status, damit BuildContext verfügbar ist.
class _SyncStatusCard extends StatelessWidget {
  final DateTime? lastSync;
  final int? conflictCount;

  const _SyncStatusCard({
    required this.lastSync,
    required this.conflictCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    if (lastSync == null) {
      statusColor = colorScheme.onSurfaceVariant;
      statusText = 'Noch nicht synchronisiert';
      statusIcon = Icons.sync_disabled;
    } else {
      final timeDiff = DateTime.now().difference(lastSync!);

      if (conflictCount != null && conflictCount! > 0) {
        statusColor = colorScheme.secondary;
        statusText = '$conflictCount Konflikte';
        statusIcon = Icons.warning;
      } else if (timeDiff.inMinutes < 5) {
        statusColor = colorScheme.tertiary;
        statusText = 'Gerade synchronisiert';
        statusIcon = Icons.check_circle;
      } else if (timeDiff.inHours < 1) {
        statusColor = colorScheme.primary;
        statusText = 'Vor ${timeDiff.inMinutes}m synchronisiert';
        statusIcon = Icons.sync;
      } else {
        statusColor = colorScheme.onSurfaceVariant;
        statusText = 'Vor ${timeDiff.inHours}h synchronisiert';
        statusIcon = Icons.sync;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacingMedium),
        child: Row(
          children: [
            Icon(
              statusIcon,
              color: statusColor,
              size: AppConfig.iconSizeSmall,
            ),
            const SizedBox(width: AppConfig.spacingSmall),
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