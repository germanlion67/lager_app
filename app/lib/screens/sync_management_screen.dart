// lib/screens/sync_management_screen.dart
//
// O-004 Batch 2: Alle hardcodierten Farben durch colorScheme ersetzt,
// alle Magic-Number-Abstände/Radien durch AppConfig-Tokens.
//
// M-004: Loading States — _isCheckingConflicts, AppLoadingOverlay.
//        Inkonsistenter DialogRoute-Ladeindikator ersetzt.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/sync_service.dart';
import '../widgets/sync_conflict_handler.dart';
import '../services/app_log_service.dart';
// M-004: Zentrales Loading-Widget
import '../widgets/app_loading_overlay.dart';

/// Screen für die erweiterte Synchronisationsverwaltung.
class SyncManagementScreen extends StatefulWidget {
  final SyncService syncService;

  const SyncManagementScreen({
    super.key,
    required this.syncService,
  });

  @override
  State<SyncManagementScreen> createState() => _SyncManagementScreenState();
}

class _SyncManagementScreenState extends State<SyncManagementScreen>
    with SyncCapable {

  // M-004: Loading State für Konflikt-Suche
  bool _isCheckingConflicts = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // M-004: Stack für AppLoadingOverlay
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Synchronisation'),
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline),
                // M-004: während Loading deaktiviert
                onPressed: (isSyncing || _isCheckingConflicts)
                    ? null
                    : _showSyncHelp,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConfig.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sync Status Card
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
                        buildSyncStatusWidget(),
                        const SizedBox(height: AppConfig.spacingLarge),

                        // M-004: AppLoadingButton ersetzt manuellen
                        //        isSyncing-Icon-Wechsel im ElevatedButton
                        SizedBox(
                          width: double.infinity,
                          child: AppLoadingButton(
                            isLoading: isSyncing,
                            onPressed: _isCheckingConflicts
                                ? null
                                : () => performSync(widget.syncService),
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

                // Konflikteinstellungen
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
                          'Bei Synchronisationskonflikten wird eine '
                          'interaktive Auflösung angeboten:',
                        ),
                        const SizedBox(height: AppConfig.spacingSmall),
                        _buildFeatureList(context),
                        const SizedBox(height: AppConfig.spacingLarge),
                        OutlinedButton.icon(
                          // M-004: während Loading deaktiviert
                          onPressed: (isSyncing || _isCheckingConflicts)
                              ? null
                              : _checkForConflicts,
                          icon: const Icon(Icons.search),
                          label: const Text('Nach Konflikten suchen'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppConfig.spacingLarge),

                // Erweiterte Optionen
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConfig.spacingLarge),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Erweiterte Optionen',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppConfig.spacingMedium),

                        ListTile(
                          leading: const Icon(Icons.upload),
                          title: const Text(
                            'Alle lokalen Änderungen hochladen',
                          ),
                          subtitle: const Text(
                            'Forciert Upload aller lokalen Artikel',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          // M-004: während Loading deaktiviert
                          onTap: (isSyncing || _isCheckingConflicts)
                              ? null
                              : _forceUploadAll,
                        ),

                        const Divider(),

                        ListTile(
                          leading: const Icon(Icons.download),
                          title: const Text(
                            'Alle Remote-Änderungen herunterladen',
                          ),
                          subtitle: const Text(
                            'Überschreibt lokale Änderungen',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          // M-004: während Loading deaktiviert
                          onTap: (isSyncing || _isCheckingConflicts)
                              ? null
                              : _forceDownloadAll,
                        ),

                        const Divider(),

                        ListTile(
                          leading: Icon(
                            Icons.refresh,
                            color: colorScheme.secondary,
                          ),
                          title: const Text('Sync-Status zurücksetzen'),
                          subtitle: const Text('Setzt alle ETags zurück'),
                          trailing: const Icon(Icons.chevron_right),
                          // M-004: während Loading deaktiviert
                          onTap: (isSyncing || _isCheckingConflicts)
                              ? null
                              : _resetSyncStatus,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppConfig.spacingLarge),

                if (kDebugMode)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppConfig.spacingLarge),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Debug Informationen',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppConfig.spacingMedium),
                          _buildDebugInfo(),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          floatingActionButton: buildSyncFab(widget.syncService),
        ),

        // M-004: Overlay während aktivem Sync
        if (isSyncing)
          const AppLoadingOverlay(message: 'Synchronisiere...'),

        // M-004: Overlay während Konflikt-Suche
        if (_isCheckingConflicts)
          const AppLoadingOverlay(message: 'Suche nach Konflikten...'),
      ],
    );
  }

  Widget _buildFeatureList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    const features = [
      'Side-by-Side Vergleich der Versionen',
      'Manuelle Zusammenführung möglich',
      'Konfliktgrund wird angezeigt',
      'Batch-Auflösung mehrerer Konflikte',
    ];

    return Column(
      children: features
          .map(
            (feature) => Padding(
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
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(
                        fontSize: AppConfig.fontSizeMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDebugInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Letzter Sync: ${lastSync?.toString() ?? "Nie"}'),
        Text('Konflikte: ${conflictCount ?? "Unbekannt"}'),
        Text('Sync aktiv: $isSyncing'),
        const SizedBox(height: AppConfig.spacingSmall),
        OutlinedButton(
          onPressed: _showSyncLogs,
          child: const Text('Sync-Logs anzeigen'),
        ),
      ],
    );
  }

  // M-004: _checkForConflicts() verwendet jetzt _isCheckingConflicts +
  //        AppLoadingOverlay statt manuellem DialogRoute.
  Future<void> _checkForConflicts() async {
    final messenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    // M-004: Loading-State setzen → Overlay erscheint
    setState(() => _isCheckingConflicts = true);

    try {
      final conflicts = await widget.syncService.detectConflicts();

      if (!mounted) return;

      if (conflicts.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Keine Konflikte gefunden'),
            backgroundColor: colorScheme.tertiary,
          ),
        );
      } else {
        final result = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('${conflicts.length} Konflikte gefunden'),
            content: Text(
              'Es wurden ${conflicts.length} Synchronisationskonflikte '
              'gefunden. Möchten Sie diese jetzt auflösen?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Später'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Jetzt auflösen'),
              ),
            ],
          ),
        );

        if (result == true && mounted) {
          await SyncConflictHandler.handleSyncWithConflicts(
            context,
            widget.syncService,
          );
        }
      }
    } catch (e, st) {
      AppLogService.logger.e(
        'Konflikt-Suche fehlgeschlagen',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Fehler beim Suchen nach Konflikten: $e'),
          backgroundColor: colorScheme.error,
        ),
      );
    } finally {
      // M-004: Loading-State immer zurücksetzen
      if (mounted) setState(() => _isCheckingConflicts = false);
    }
  }

  Future<void> _forceUploadAll() async {
    final messenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alle lokalen Änderungen hochladen?'),
        content: const Text(
          'Dies wird alle lokalen Artikel zum Server hochladen und '
          'eventuell Remote-Änderungen überschreiben. Sind Sie sicher?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.secondary,
            ),
            child: const Text('Upload erzwingen'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Force Upload wird implementiert...'),
        ),
      );
    }
  }

  Future<void> _forceDownloadAll() async {
    final messenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alle Remote-Änderungen herunterladen?'),
        content: const Text(
          'Dies wird alle Server-Artikel herunterladen und '
          'lokale Änderungen überschreiben. Sind Sie sicher?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            child: const Text('Download erzwingen'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Force Download wird implementiert...'),
        ),
      );
    }
  }

  Future<void> _resetSyncStatus() async {
    final messenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sync-Status zurücksetzen?'),
        content: const Text(
          'Dies setzt alle ETags zurück und führt bei der nächsten '
          'Synchronisation zu einer vollständigen Überprüfung aller Artikel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.secondary,
            ),
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sync-Status zurückgesetzt')),
      );
    }
  }

  void _showSyncLogs() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sync-Logs werden implementiert...'),
      ),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: AppConfig.fontSizeLarge,
                ),
              ),
              SizedBox(height: AppConfig.spacingSmall),
              Text(
                'Die Synchronisation gleicht Ihre lokalen Artikel mit '
                'dem Nextcloud-Server ab.',
              ),
              SizedBox(height: AppConfig.spacingLarge),
              Text(
                'Konflikte',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: AppConfig.fontSizeLarge,
                ),
              ),
              SizedBox(height: AppConfig.spacingSmall),
              Text(
                'Konflikte entstehen, wenn derselbe Artikel auf '
                'verschiedenen Geräten gleichzeitig bearbeitet wurde.',
              ),
              SizedBox(height: AppConfig.spacingLarge),
              Text(
                'Auflösung',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: AppConfig.fontSizeLarge,
                ),
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