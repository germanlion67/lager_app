// test/mocks/sync_service_mocks.dart
//
// Mockito-Annotationen für Sync-Tests.
// Nach Änderungen ausführen:
//   dart run build_runner build

import 'package:mockito/annotations.dart';
import 'package:lager_app/services/sync_orchestrator.dart';
import 'package:lager_app/services/pocketbase_sync_service.dart';
import 'package:lager_app/services/artikel_db_service.dart';
import 'package:lager_app/services/conflict_types.dart'; // ← NEU

@GenerateMocks(
  [SyncOrchestrator, PocketBaseSyncService, ArtikelDbService],
  customMocks: [
    MockSpec<SyncServiceInterface>(as: #MockSyncService), // ← generiert MockSyncService
  ],
)
void main() {}