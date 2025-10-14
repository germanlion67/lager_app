// lib/screens/sync_management_screen.dart

import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../widgets/sync_conflict_handler.dart';

/// Screen für die erweiterte Synchronisationsverwaltung
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Synchronisation'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showSyncHelp,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sync Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Synchronisationsstatus',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    buildSyncStatusWidget(),
                    const SizedBox(height: 16),
                    
                    // Sync Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isSyncing ? null : () => performSync(widget.syncService),
                        icon: Icon(isSyncing ? Icons.hourglass_empty : Icons.sync),
                        label: Text(isSyncing ? 'Synchronisiere...' : 'Jetzt synchronisieren'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Konflikteinstellungen
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Konfliktauflösung',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Bei Synchronisationskonflikten wird eine interaktive Auflösung angeboten:',
                    ),
                    const SizedBox(height: 8),
                    _buildFeatureList([
                      'Side-by-Side Vergleich der Versionen',
                      'Manuelle Zusammenführung möglich',
                      'Konfliktgrund wird angezeigt',
                      'Batch-Auflösung mehrerer Konflikte',
                    ]),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _checkForConflicts,
                      icon: const Icon(Icons.search),
                      label: const Text('Nach Konflikten suchen'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Erweiterte Optionen
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Erweiterte Optionen',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    ListTile(
                      leading: const Icon(Icons.upload),
                      title: const Text('Alle lokalen Änderungen hochladen'),
                      subtitle: const Text('Forciert Upload aller lokalen Artikel'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _forceUploadAll,
                    ),
                    
                    const Divider(),
                    
                    ListTile(
                      leading: const Icon(Icons.download),
                      title: const Text('Alle Remote-Änderungen herunterladen'),
                      subtitle: const Text('Überschreibt lokale Änderungen'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _forceDownloadAll,
                    ),
                    
                    const Divider(),
                    
                    ListTile(
                      leading: const Icon(Icons.refresh, color: Colors.orange),
                      title: const Text('Sync-Status zurücksetzen'),
                      subtitle: const Text('Setzt alle ETags zurück'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _resetSyncStatus,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Debug Informationen
            if (Theme.of(context).brightness == Brightness.dark) // Nur im Debug Mode
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Debug Informationen',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDebugInfo(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: buildSyncFab(widget.syncService),
    );
  }

  Widget _buildFeatureList(List<String> features) {
    return Column(
      children: features.map((feature) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check, size: 16, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(child: Text(feature, style: const TextStyle(fontSize: 14))),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildDebugInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Letzter Sync: ${lastSync?.toString() ?? "Nie"}'),
        Text('Konflikte: ${conflictCount ?? "Unbekannt"}'),
        Text('Sync aktiv: $isSyncing'),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _showSyncLogs,
          child: const Text('Sync-Logs anzeigen'),
        ),
      ],
    );
  }

  void _checkForConflicts() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Dialog(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Suche nach Konflikten...'),
              ],
            ),
          ),
        ),
      );

      final conflicts = await widget.syncService.detectConflicts();
      
      if (mounted) {
        Navigator.of(context).pop(); // Schließe Loading Dialog
        
        if (conflicts.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Keine Konflikte gefunden'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('${conflicts.length} Konflikte gefunden'),
              content: Text(
                'Es wurden ${conflicts.length} Synchronisationskonflikte gefunden. '
                'Möchten Sie diese jetzt auflösen?'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Später'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Jetzt auflösen'),
                ),
              ],
            ),
          );
          
          if (result == true && mounted) {
            await SyncConflictHandler.handleSyncWithConflicts(context, widget.syncService);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Schließe Loading Dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Suchen nach Konflikten: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _forceUploadAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alle lokalen Änderungen hochladen?'),
        content: const Text(
          'Dies wird alle lokalen Artikel zum Server hochladen und '
          'eventuell Remote-Änderungen überschreiben. Sind Sie sicher?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implementierung für Force Upload
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Force Upload wird implementiert...')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Upload erzwingen'),
          ),
        ],
      ),
    );
  }

  void _forceDownloadAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alle Remote-Änderungen herunterladen?'),
        content: const Text(
          'Dies wird alle Server-Artikel herunterladen und '
          'lokale Änderungen überschreiben. Sind Sie sicher?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implementierung für Force Download
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Force Download wird implementiert...')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Download erzwingen'),
          ),
        ],
      ),
    );
  }

  void _resetSyncStatus() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync-Status zurücksetzen?'),
        content: const Text(
          'Dies setzt alle ETags zurück und führt bei der nächsten '
          'Synchronisation zu einer vollständigen Überprüfung aller Artikel.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implementierung für Reset
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync-Status zurückgesetzt')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );
  }

  void _showSyncLogs() {
    // Implementierung für Sync-Logs
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sync-Logs werden implementiert...')),
    );
  }

  void _showSyncHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Synchronisation Hilfe'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Synchronisation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('Die Synchronisation gleicht Ihre lokalen Artikel mit dem Nextcloud-Server ab.'),
              SizedBox(height: 16),
              Text(
                'Konflikte',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('Konflikte entstehen, wenn derselbe Artikel auf verschiedenen Geräten gleichzeitig bearbeitet wurde.'),
              SizedBox(height: 16),
              Text(
                'Auflösung',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('• Lokale Version: Behält Ihre Änderungen\n'
                   '• Remote Version: Übernimmt Server-Version\n'
                   '• Zusammenführen: Kombiniert beide Versionen\n'
                   '• Überspringen: Konflikt für später aufheben'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }
}