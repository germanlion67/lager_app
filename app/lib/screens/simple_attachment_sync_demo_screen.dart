// lib/screens/simple_attachment_sync_demo_screen.dart

import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/nextcloud_client.dart';
import '../services/artikel_db_service.dart';

class SimpleAttachmentSyncDemoScreen extends StatefulWidget {
  const SimpleAttachmentSyncDemoScreen({super.key});

  @override
  State<SimpleAttachmentSyncDemoScreen> createState() => _SimpleAttachmentSyncDemoScreenState();
}

class _SimpleAttachmentSyncDemoScreenState extends State<SimpleAttachmentSyncDemoScreen> {
  late SyncService _syncService;
  late ArtikelDbService _dbService;
  bool _isInitialized = false;
  String? _initError;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final client = NextcloudClient(
        baseUrl: Uri.parse('https://demo.nextcloud.com'),
        username: 'demo',
        appPassword: 'demo',
      );
      _dbService = ArtikelDbService();
      _syncService = SyncService(client, _dbService);
      
      final isConnected = await _syncService.testAndInitialize();
      if (!isConnected) {
        setState(() {
          _initError = 'Nextcloud connection failed';
          _isInitialized = false;
        });
        return;
      }
      
      setState(() {
        _isInitialized = true;
        _initError = null;
      });
    } catch (e) {
      setState(() {
        _initError = 'Failed to initialize services: $e';
        _isInitialized = false;
      });
    }
  }

  Future<void> _syncAttachments() async {
    if (!_isInitialized || _isSyncing) return;
    
    setState(() => _isSyncing = true);
    
    try {
      await _syncService.syncAttachments();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Attachment synchronization completed!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✗ Attachment sync failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _fullSync() async {
    if (!_isInitialized || _isSyncing) return;
    
    setState(() => _isSyncing = true);
    
    try {
      final result = await _syncService.syncOnce();
      
      if (!mounted) return;
      final message = result.hasErrors 
        ? '⚠ Sync completed with ${result.errors.length} errors'
        : '✓ Full sync successful: ${result.pushed} pushed, ${result.pulled} pulled, ${result.conflicts} conflicts';
        
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: result.hasErrors ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✗ Full sync failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _showUnsyncedStats() async {
    final unsyncedArticles = await _dbService.getUnsyncedArtikel();
    final allArticles = await _dbService.getAlleArtikel();
    final articlesWithRemoteImages = allArticles.where((artikel) => 
      (artikel.remoteBildPfad ?? '').isNotEmpty
    ).length;
    
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Attachment Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📊 Total articles: ${allArticles.length}'),
            Text('📤 Articles with unsynced images: ${unsyncedArticles.length}'),
            Text('☁️ Articles with remote images: $articlesWithRemoteImages'),
            const SizedBox(height: 16),
            if (unsyncedArticles.isNotEmpty) ...[
              const Text('🔄 Unsynced articles:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...unsyncedArticles.take(5).map((artikel) => 
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text('• ${artikel.name}'),
                )
              ),
              if (unsyncedArticles.length > 5)
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text('... and ${unsyncedArticles.length - 5} more'),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attachment Sync Demo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _initError != null
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Initialization Error:',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(_initError!),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initializeServices,
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        : !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Demo Info
                  Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.attach_file, size: 48, color: Colors.green),
                          const SizedBox(height: 8),
                          Text(
                            '🎉 Attachment Upload Ready!',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'The attachment synchronization feature has been successfully implemented and integrated into the sync process.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Action Buttons
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Test Attachment Operations',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          
                          ElevatedButton.icon(
                            onPressed: _isSyncing ? null : _syncAttachments,
                            icon: _isSyncing 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.attach_file),
                            label: const Text('Sync Attachments Only'),
                          ),
                          const SizedBox(height: 8),
                          
                          ElevatedButton.icon(
                            onPressed: _isSyncing ? null : _fullSync,
                            icon: _isSyncing 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.sync),
                            label: const Text('Full Sync (includes attachments)'),
                          ),
                          const SizedBox(height: 8),
                          
                          OutlinedButton.icon(
                            onPressed: _showUnsyncedStats,
                            icon: const Icon(Icons.info),
                            label: const Text('Show Attachment Statistics'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Features Info
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '✨ Implemented Features',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const _FeatureItem('📤 Upload local images to Nextcloud'),
                          const _FeatureItem('📥 Download remote images to local storage'),
                          const _FeatureItem('📊 Real-time progress tracking and statistics'),
                          const _FeatureItem('🔄 Intelligent error recovery with retry mechanisms'),
                          const _FeatureItem('🔗 Full integration with existing sync process'),
                          const _FeatureItem('📈 Comprehensive attachment monitoring'),
                          const _FeatureItem('⚡ Efficient batch processing'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final String text;
  
  const _FeatureItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text),
    );
  }
}