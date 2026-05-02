// lib/services/sync_orchestrator.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../services/app_log_service.dart';
import 'pocketbase_sync_service.dart';
import 'sync_status_provider.dart';

import 'orchestrator_sync_backend.dart';

export 'pocketbase_sync_service.dart' show ConflictCallback;



enum SyncStatus { idle, running, success, error }

class SyncOrchestrator implements SyncStatusProvider {
  final OrchestratorSyncBackend _pocketBaseSync;
  final Duration _syncTimeout;
  final Duration _imageTimeout;
  final Duration _timeoutPollInterval;

  bool _isSyncing = false;
  bool _isDisposed = false;

  /// Letzte aktive Sync-Phase — wird bei Timeout/Fehler geloggt (O-012).
  String _lastSyncPhase = 'init';

  Timer? _syncTimer;

  final _syncStatusController = StreamController<SyncStatus>.broadcast();

  @override
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  @override
  bool get isSyncing => _isSyncing;

  DateTime? _lastSyncTime;
  @override
  DateTime? get lastSyncTime => _lastSyncTime;

  static final _log = AppLogService.logger;

  SyncOrchestrator({
    required OrchestratorSyncBackend pocketBaseSync,
    Duration syncTimeout = const Duration(minutes: 5),
    Duration imageTimeout = const Duration(minutes: 2),
    Duration timeoutPollInterval = const Duration(seconds: 5),
  })  : _pocketBaseSync = pocketBaseSync,
        _syncTimeout = syncTimeout,
        _imageTimeout = imageTimeout,
        _timeoutPollInterval = timeoutPollInterval;

  /// Registriert den Konflikt-Callback am PocketBaseSyncService.
  void setConflictCallback(ConflictCallback callback) {
    _pocketBaseSync.onConflictDetected = callback;
    _log.d('SyncOrchestrator: Konflikt-Callback registriert');
  }

  void _emit(SyncStatus status) {
    if (!_isDisposed && !_syncStatusController.isClosed) {
      _syncStatusController.add(status);
    }
  }

  @override
  Future<void> runOnce() async {
    if (kIsWeb) {
      _log.d('SyncOrchestrator: Skipping sync on Web platform');
      return;
    }

    if (_isDisposed) {
      _log.w('SyncOrchestrator: bereits disposed – überspringe');
      return;
    }

    if (_isSyncing) {
      _log.w('SyncOrchestrator: Sync bereits aktiv – überspringe');
      return;
    }

    _isSyncing = true;
    _lastSyncPhase = 'init';
    _emit(SyncStatus.running);
    _log.i('SyncOrchestrator: start');

    try {
      _lastSyncPhase = 'push+pull';
      await _awaitSyncOnceWithConflictAwareTimeout();

      _lastSyncPhase = 'images';
      await _pocketBaseSync
          .downloadMissingImages()
          .timeout(_imageTimeout);

      _lastSyncTime = DateTime.now();
      _lastSyncPhase = 'done';
      _emit(SyncStatus.success);
      _log.i('SyncOrchestrator: end (success) – $_lastSyncTime');
    } catch (e, st) {
      _emit(SyncStatus.error);
      _log.w(                                                    // O-012
        'SYNC|ORCHESTRATOR  fail  phase=$_lastSyncPhase  '
        'msg="${e.toString().split('\n').first}"',
      );
      _log.e('SyncOrchestrator: sync failed', error: e, stackTrace: st);
    } finally {
      _isSyncing = false;
      Future.delayed(
        const Duration(seconds: 3),
        () => _emit(SyncStatus.idle),
      );
    }
  }

  Future<void> _awaitSyncOnceWithConflictAwareTimeout() async {
    final syncFuture = _pocketBaseSync.syncOnce();
    final stopwatch = Stopwatch()..start();

    while (true) {
      try {
        await syncFuture.timeout(_timeoutPollInterval);
        return;
      } on TimeoutException {
        if (_pocketBaseSync.isWaitingForConflictResolution) {
          _log.i(
            'SYNC|ORCHESTRATOR  wait  phase=$_lastSyncPhase  '
            'state=conflict_ui  elapsed=${stopwatch.elapsed.inSeconds}s',
          );
          continue;
        }

        if (stopwatch.elapsed >= _syncTimeout) {
          throw TimeoutException(
            'Sync timed out after ${stopwatch.elapsed.inMinutes} minutes '
            '(phase=$_lastSyncPhase)',
          );
        }
      }
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
    _pocketBaseSync.onConflictDetected = null;
    stopPeriodicSync();
    _syncStatusController.close();
    _log.i('SyncOrchestrator: disposed');
  }
}