// lib/screens/sync_management_screen.dart
//
// CHANGES v0.8.5:
//   F5 — SyncOrchestrator statt SyncService injiziert.
//         SyncManagementScreen war mit dem Nextcloud-SyncService verdrahtet,
//         obwohl die App PocketBase nutzt. Jetzt wird der SyncOrchestrator
//         direkt verwendet und der Status über seinen Stream beobachtet.
//   F5 — _manualSync() ruft orchestrator.runOnce() auf.
//   F5 — Stream-Subscription für Live-Status-Updates.

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/sync_orchestrator.dart';
import '../services/app_log_service.dart';
import '../widgets/app_loading_overlay.dart';

/// Screen für die Synchronisationsverwaltung (PocketBase).
///
/// Erhält den SyncOrchestrator direkt — kein SyncService (Nextcloud) mehr.
class SyncManagementScreen extends StatefulWidget {
  // F5: SyncOrchestrator statt SyncService
  final SyncOrchestrator orchestrator;

  const SyncManagementScreen({
    super.key,
    required this.orchestrator,
  });

  @override
  State<SyncManagementScreen> createState() => _SyncManagementScreenState();
}

class _SyncManagementScreenState extends State<SyncManagementScreen> {
  static final _log = AppLogService.logger;

  // F5: Stream-Subscription für Live-Status
  StreamSubscription<SyncStatus>? _statusSub;
  SyncStatus _currentStatus = SyncStatus.idle;
  bool _isManualSyncing = false;

  bool get _isBusy => _isManualSyncing || _currentStatus == SyncStatus.running;

  @override
  void initState() {
    super.initState();
    // F5: Status-Stream abonnieren
    _statusSub = widget.orchestrator.syncStatus.listen((status) {
      if (mounted) {
        setState(() => _currentStatus = status);
      }
    });
    // Initialen Status setzen
    _currentStatus =
        widget.orchestrator.isSyncing ? SyncStatus.running : SyncStatus.idle;
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Synchronisation'),
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: _isBusy ? null : _showSyncHelp,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConfig.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Status-Card ───────────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConfig.spacingLarge),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Synchronisationsstatus',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppConfig.spacingMedium),
                        _buildStatusWidget(colorScheme),
                        const SizedBox(height: AppConfig.spacingLarge),
                        SizedBox(
                          width: double.infinity,
                          child: AppLoadingButton(
                            isLoading: _isBusy,
                            onPressed: _isBusy ? null : _manualSync,
                            label: 'Jetzt synchronisieren',
                            loadingLabel: 'Synchronisiere...',
                            icon: Icons.sync,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppConfig.spacingLarge),

                // ── Letzter Sync ──────────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConfig.spacingLarge),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sync-Informationen',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppConfig.spacingMedium),
                        _buildSyncInfo(colorScheme),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppConfig.spacingLarge),

                // ── Konfliktauflösung ─────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConfig.spacingLarge),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Konfliktauflösung',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppConfig.spacingMedium),
                        const Text(
                          'Bei Synchronisationskonflikten wird automatisch '
                          'ein Vergleichs-Dialog angezeigt.',
                        ),
                        const SizedBox(height: AppConfig.spacingSmall),
                        _buildFeatureList(colorScheme),
                      ],
                    ),
                  ),
                ),

                if (kDebugMode) ...[
                  const SizedBox(height: AppConfig.spacingLarge),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppConfig.spacingLarge),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Debug',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppConfig.spacingMedium),
                          Text(
                            'Status: ${_currentStatus.name}\n'
                            'Letzter Sync: '
                            '${widget.orchestrator.lastSyncTime ?? "Nie"}\n'
                            'Syncing: ${widget.orchestrator.isSyncing}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        if (_isBusy)
          const AppLoadingOverlay(message: 'Synchronisiere...'),
      ],
    );
  }

  // ── F5: Manueller Sync via SyncOrchestrator ───────────────────────────────
  Future<void> _manualSync() async {
    if (_isBusy) return;

    final messenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    setState(() => _isManualSyncing = true);

    try {
      _log.i('[SyncManagement] Manueller Sync gestartet');
      await widget.orchestrator.runOnce();
      _log.i('[SyncManagement] Manueller Sync abgeschlossen');

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Synchronisation abgeschlossen'),
          backgroundColor: colorScheme.tertiary,
        ),
      );
    } catch (e, st) {
      _log.e('[SyncManagement] Manueller Sync fehlgeschlagen',
          error: e, stackTrace: st,);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Synchronisation fehlgeschlagen: $e'),
          backgroundColor: colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isManualSyncing = false);
    }
  }

  Widget _buildStatusWidget(ColorScheme colorScheme) {
    final (icon, label, color) = switch (_currentStatus) {
      SyncStatus.running => (Icons.sync, 'Synchronisiert...', colorScheme.primary),
      SyncStatus.success => (Icons.check_circle, 'Erfolgreich', colorScheme.tertiary),
      SyncStatus.error   => (Icons.error, 'Fehler aufgetreten', colorScheme.error),
      SyncStatus.idle    => (Icons.cloud_done, 'Bereit', colorScheme.onSurfaceVariant),
    };

    return Row(
      children: [
        Icon(icon, color: color, size: AppConfig.iconSizeMedium),
        const SizedBox(width: AppConfig.spacingSmall),
        Text(label, style: TextStyle(color: color)),
        if (_currentStatus == SyncStatus.running) ...[
          const SizedBox(width: AppConfig.spacingSmall),
          SizedBox(
            width: AppConfig.iconSizeSmall,
            height: AppConfig.iconSizeSmall,
            child: CircularProgressIndicator(
              strokeWidth: AppConfig.strokeWidthThin,
              color: colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSyncInfo(ColorScheme colorScheme) {
    final lastSync = widget.orchestrator.lastSyncTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.schedule,
              size: AppConfig.iconSizeSmall,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppConfig.spacingSmall),
            Text(
              lastSync != null
                  ? 'Letzter Sync: ${_formatDateTime(lastSync)}'
                  : 'Noch kein Sync durchgeführt',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Gerade eben';
    if (diff.inMinutes < 60) return 'Vor ${diff.inMinutes} Minuten';
    if (diff.inHours < 24) return 'Vor ${diff.inHours} Stunden';
    return '${dt.day}.${dt.month}.${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildFeatureList(ColorScheme colorScheme) {
    const features = [
      'Side-by-Side Vergleich der Versionen',
      'Manuelle Zusammenführung möglich',
      'Konfliktgrund wird angezeigt',
    ];

    return Column(
      children: features
          .map(
            (f) => Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppConfig.spacingXSmall / 2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check,
                    size: AppConfig.iconSizeSmall,
                    color: colorScheme.tertiary,
                  ),
                  const SizedBox(width: AppConfig.spacingSmall),
                  Expanded(child: Text(f)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _showSyncHelp() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Synchronisation Hilfe'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Synchronisation',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: AppConfig.spacingSmall),
              Text(
                'Die Synchronisation gleicht Ihre lokalen Artikel '
                'mit dem PocketBase-Server ab.',
              ),
              SizedBox(height: AppConfig.spacingLarge),
              Text(
                'Konflikte',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: AppConfig.spacingSmall),
              Text(
                'Konflikte entstehen, wenn derselbe Artikel auf '
                'verschiedenen Geräten gleichzeitig bearbeitet wurde. '
                'Ein Vergleichs-Dialog erscheint automatisch.',
              ),
              SizedBox(height: AppConfig.spacingLarge),
              Text(
                'Auflösung',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: AppConfig.spacingSmall),
              Text(
                '• Lokale Version: Behält Ihre Änderungen\n'
                '• Remote Version: Übernimmt Server-Version\n'
                '• Zusammenführen: Kombiniert beide Versionen\n'
                '• Überspringen: Konflikt für später aufheben',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }
}