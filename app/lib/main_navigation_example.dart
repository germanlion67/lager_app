// lib/main_navigation_example.dart
// Beispiel wie die Enhanced Conflict Resolution UI in die Hauptnavigation integriert werden kann

import 'package:flutter/material.dart';
import 'screens/artikel_list_screen.dart';
import 'screens/sync_management_screen.dart';
import 'services/sync_service.dart';
import 'services/artikel_db_service.dart';
import 'services/nextcloud_client.dart';
import 'widgets/sync_conflict_handler.dart';

class MainNavigationExample extends StatefulWidget {
  const MainNavigationExample({super.key});

  @override
  State<MainNavigationExample> createState() => _MainNavigationExampleState();
}

class _MainNavigationExampleState extends State<MainNavigationExample> 
    with SyncCapable {
  int _selectedIndex = 0;
  late SyncService _syncService;

  @override
  void initState() {
    super.initState();
    _initializeSyncService();
  }

  void _initializeSyncService() {
    // Diese Werte sollten aus den Einstellungen geladen werden
    final client = NextcloudClient(
      baseUrl: Uri.parse('https://your-nextcloud.com'),
      username: 'your-username',
      appPassword: 'your-app-password',
    );
    final dbService = ArtikelDbService();
    _syncService = SyncService(client, dbService);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elektronik Verwaltung'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Quick Sync Button in der AppBar
          IconButton(
            icon: Icon(isSyncing ? Icons.hourglass_empty : Icons.sync),
            onPressed: isSyncing ? null : () => performSync(_syncService),
            tooltip: 'Synchronisieren',
          ),
          // Konflikt-Indikator
          if (conflictCount != null && conflictCount! > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '$conflictCount',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Artikel Liste
          ArtikelListScreen(),
          
          // Sync Management
          SyncManagementScreen(syncService: _syncService),
          
          // Weitere Screens...
          const Center(child: Text('Einstellungen')),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Artikel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sync),
            label: 'Sync',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Einstellungen',
          ),
        ],
      ),
      
      // Sync Status als Persistent Bottom Sheet (optional)
      persistentFooterButtons: [
        buildSyncStatusWidget(),
      ],
      
      // Erweiterte Sync FAB
      floatingActionButton: _buildEnhancedSyncFab(),
    );
  }

  Widget _buildEnhancedSyncFab() {
    if (_selectedIndex == 1) {
      // Auf Sync-Screen: Normales FAB
      return buildSyncFab(_syncService);
    }
    
    // Auf anderen Screens: Erweiterte FAB mit Konflikt-Indikator
    return Stack(
      children: [
        FloatingActionButton(
          onPressed: isSyncing ? null : () => performSync(_syncService),
          backgroundColor: isSyncing ? Colors.grey : Colors.blue,
          child: Icon(isSyncing ? Icons.hourglass_empty : Icons.sync),
        ),
        if (conflictCount != null && conflictCount! > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                '$conflictCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

/// Erweiterte Drawer-Integration mit Sync-Status
class SyncAwareDrawer extends StatelessWidget {
  final SyncService syncService;
  final bool isSyncing;
  final DateTime? lastSync;
  final int? conflictCount;
  final VoidCallback onSyncPressed;

  const SyncAwareDrawer({
    super.key,
    required this.syncService,
    required this.isSyncing,
    required this.lastSync,
    required this.conflictCount,
    required this.onSyncPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Drawer Header mit Sync-Status
          UserAccountsDrawerHeader(
            accountName: const Text('Elektronik Verwaltung'),
            accountEmail: Text(_getSyncStatusText()),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                _getSyncStatusIcon(),
                color: _getSyncStatusColor(),
              ),
            ),
            decoration: BoxDecoration(
              color: _getSyncStatusColor(),
            ),
          ),
          
          // Sync-Schnellaktionen
          if (conflictCount != null && conflictCount! > 0)
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.orange),
              title: Text('$conflictCount Konflikte'),
              subtitle: const Text('Tippen zum Auflösen'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SyncManagementScreen(syncService: syncService),
                  ),
                );
              },
            ),
          
          ListTile(
            leading: Icon(isSyncing ? Icons.hourglass_empty : Icons.sync),
            title: Text(isSyncing ? 'Synchronisiere...' : 'Synchronisieren'),
            enabled: !isSyncing,
            onTap: isSyncing ? null : () {
              Navigator.pop(context);
              onSyncPressed();
            },
          ),
          
          const Divider(),
          
          // Normale Navigation
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Artikel'),
            onTap: () => Navigator.pop(context),
          ),
          
          ListTile(
            leading: const Icon(Icons.sync_alt),
            title: const Text('Sync-Verwaltung'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SyncManagementScreen(syncService: syncService),
                ),
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Einstellungen'),
            onTap: () => Navigator.pop(context),
          ),
          
          const Spacer(),
          
          // Detaillierte Sync-Informationen im Footer
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync-Status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getSyncStatusText(),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (lastSync != null)
                  Text(
                    'Zuletzt: ${_formatLastSync(lastSync!)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSyncStatusText() {
    if (isSyncing) return 'Synchronisiere...';
    if (conflictCount != null && conflictCount! > 0) {
      return '$conflictCount Konflikte gefunden';
    }
    if (lastSync != null) {
      return 'Synchronisiert';
    }
    return 'Noch nicht synchronisiert';
  }

  IconData _getSyncStatusIcon() {
    if (isSyncing) return Icons.hourglass_empty;
    if (conflictCount != null && conflictCount! > 0) return Icons.warning;
    if (lastSync != null) return Icons.check_circle;
    return Icons.sync_disabled;
  }

  Color _getSyncStatusColor() {
    if (isSyncing) return Colors.blue;
    if (conflictCount != null && conflictCount! > 0) return Colors.orange;
    if (lastSync != null) return Colors.green;
    return Colors.grey;
  }

  String _formatLastSync(DateTime lastSync) {
    final diff = DateTime.now().difference(lastSync);
    if (diff.inMinutes < 1) return 'Gerade eben';
    if (diff.inMinutes < 60) return 'Vor ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Vor ${diff.inHours}h';
    return 'Vor ${diff.inDays}d';
  }
}