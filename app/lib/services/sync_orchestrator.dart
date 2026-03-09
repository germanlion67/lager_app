//lib/services/sync_orchestrator.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'pocketbase_sync_service.dart';
import 'nextcloud_client.dart';
import 'sync_service.dart' as nextcloud_sync;
import 'artikel_db_service.backup';

/// Orchestrator: PocketBase is default. If Nextcloud credentials are provided,
/// the existing Nextcloud `SyncService` (in sync_service.dart) will be used.
class SyncOrchestrator {
  final PocketBaseSyncService pocket;
  final Uri? nextcloudBaseUrl;
  final String? nextcloudUser;
  final String? nextcloudPassword;

  SyncOrchestrator({required this.pocket, this.nextcloudBaseUrl, this.nextcloudUser, this.nextcloudPassword});

  bool get hasNextcloudCredentials =>
      nextcloudBaseUrl != null && (nextcloudUser ?? '').isNotEmpty && (nextcloudPassword ?? '').isNotEmpty;

  Future<void> runOnce() async {
    developer.log('SyncOrchestrator: start', name: 'sync');
    if (hasNextcloudCredentials) {
      developer.log('SyncOrchestrator: using Nextcloud backend', name: 'sync');
      final client = NextcloudClient(
        baseUrl: nextcloudBaseUrl!,
        username: nextcloudUser!,
        appPassword: nextcloudPassword!,
      );
      // ArtikelDbService is required by the existing Nextcloud SyncService
      final dbService = ArtikelDbService();
      final svc = nextcloud_sync.SyncService(client, dbService);
      await svc.syncOnce();
    } else {
      developer.log('SyncOrchestrator: using PocketBase backend (default)', name: 'sync');
      await pocket.syncOnce();
    }
    developer.log('SyncOrchestrator: end', name: 'sync');
  }

  
}
