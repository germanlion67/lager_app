// lib/services/sync_status_provider.dart
//
// Minimales Interface für Komponenten, die den Sync-Status beobachten.
//
// Begründung: ArtikelListScreen braucht nur den Stream, nicht die volle
// SyncOrchestrator-API. Ermöglicht einfache Test-Doubles ohne den gesamten
// Orchestrator zu mocken.


import 'sync_orchestrator.dart' show SyncStatus;

abstract class SyncStatusProvider {
  /// Stream der Sync-Status-Änderungen (broadcast).
  Stream<SyncStatus> get syncStatus;

  /// Ob gerade ein Sync läuft.
  bool get isSyncing;

  /// Wann der letzte erfolgreiche Sync war.
  DateTime? get lastSyncTime;

  /// Stößt einen einmaligen Sync-Vorgang an.
  Future<void> runOnce();
}