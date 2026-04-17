// lib/services/sync_orchestrator.dart
//
// CHANGES v0.8.5:
//   F2 — onConflictDetected-Callback an PocketBaseSyncService weitergeben.
//         SyncOrchestrator ist die einzige Stelle die weiß ob ein
//         NavigatorContext verfügbar ist.
//   F3 — _syncRunning durch Orchestrator-eigenes Flag ersetzt.
//         PocketBaseSyncService.syncOnce() wirft jetzt Exceptions weiter
//         (rethrow) → _isSyncing wird zuverlässig im finally zurückgesetzt.
//   NEU — conflictCallback-Parameter im Konstruktor (optional, testbar).

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../services/app_log_service.dart';
import 'pocketbase_sync_service.dart';
import 'sync_status_provider.dart';

export 'pocketbase_sync_service.dart' show ConflictCallback;

enum SyncStatus { idle, running, success, error }

class SyncOrchestrator implements SyncStatusProvider {
  final PocketBaseSyncService _pocketBaseSync;

  // _conflictCallback-Feld entfernt — der Callback lebt ausschließlich
  // in _pocketBaseSync.onConflictDetected. Eine Kopie hier wäre
  // redundant und würde den unused_field-Lint auslösen.

  bool _isSyncing = false;
  bool _isDisposed = false;

  Timer? _syncTimer;

  final _syncStatusController = StreamController<SyncStatus>.broadcast();

  @override
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  @override
  bool get isSyncing => _isSyncing;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  static final _log = AppLogService.logger;

  SyncOrchestrator({required PocketBaseSyncService pocketBaseSync})
      : _pocketBaseSync = pocketBaseSync;

  /// Registriert den Konflikt-Callback am PocketBaseSyncService.
  ///
  /// Wird von main.dart nach dem ersten Frame aufgerufen,
  /// wenn der Navigator verfügbar ist.
  void setConflictCallback(ConflictCallback callback) {
    _pocketBaseSync.onConflictDetected = callback;
    _log.d('SyncOrchestrator: Konflikt-Callback registriert');
  }

  void _emit(SyncStatus status) {
    if (!_isDisposed && !_syncStatusController.isClosed) {
      _syncStatusController.add(status);
    }
  }

  Future<void> runOnce() async {
    if (kIsWeb) {
      _log.d('SyncOrchestrator: Skipping sync on Web platform');
      return;
    }

    if (_isDisposed) {
      _log.w('SyncOrchestrator: bereits disposed – überspringe');
      return;
    }

    // F3: Guard mit lokalem Flag — verhindert Race-Condition
    if (_isSyncing) {
      _log.w('SyncOrchestrator: Sync bereits aktiv – überspringe');
      return;
    }

    _isSyncing = true;
    _emit(SyncStatus.running);
    _log.i('SyncOrchestrator: start');

    try {
      await _pocketBaseSync.syncOnce();
      await _pocketBaseSync.downloadMissingImages();

      _lastSyncTime = DateTime.now();
      _emit(SyncStatus.success);
      _log.i('SyncOrchestrator: end (success) – $_lastSyncTime');
    } catch (e, st) {
      _emit(SyncStatus.error);
      _log.e('SyncOrchestrator: sync failed', error: e, stackTrace: st);
      // Exception NICHT weiterwerfen — Orchestrator soll nie crashen.
      // Der Fehler ist im Stream als SyncStatus.error sichtbar.
    } finally {
      // F3: _isSyncing wird IMMER zurückgesetzt, auch bei Exception
      _isSyncing = false;
    }
  }

  void startPeriodicSync({
    Duration interval = const Duration(minutes: 5),
    bool runImmediately = false,
  }) {
    if (kIsWeb) return;
    stopPeriodicSync();
    _log.i(
      'SyncOrchestrator: Starte periodischen Sync '
      '(alle ${interval.inMinutes} min)',
    );
    if (runImmediately) runOnce(); // ignore: discarded_futures
    _syncTimer = Timer.periodic(interval, (_) => runOnce());
  }

  void stopPeriodicSync() {
    if (_syncTimer != null) {
      _syncTimer!.cancel();
      _syncTimer = null;
      _log.i('SyncOrchestrator: Periodischer Sync gestoppt');
    }
  }

  void dispose() {
    _isDisposed = true;
    _isSyncing = false;
    // Callback am Service zurücksetzen, nicht am entfernten lokalen Feld
    _pocketBaseSync.onConflictDetected = null;
    stopPeriodicSync();
    _syncStatusController.close();
    _log.i('SyncOrchestrator: disposed');
  }
}