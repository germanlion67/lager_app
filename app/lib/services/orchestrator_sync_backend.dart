// lib/services/orchestrator_sync_backend.dart

import 'pocketbase_sync_service.dart';

abstract class OrchestratorSyncBackend {
  Future<void> syncOnce();
  Future<void> downloadMissingImages();

  bool get isWaitingForConflictResolution;

  ConflictCallback? get onConflictDetected;
  set onConflictDetected(ConflictCallback? callback);
}