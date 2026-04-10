// lib/services/sync_orchestrator.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';
import 'pocketbase_sync_service.dart';
import 'sync_status_provider.dart'; // ← NEU

enum SyncStatus { idle, running, success, error }

class SyncOrchestrator implements SyncStatusProvider { // ← GEÄNDERT
  final PocketBaseSyncService _pocketBaseSync;
  final Logger _logger = Logger();

  bool _isSyncing = false;
  bool _isDisposed = false;

  Timer? _syncTimer;

  final _syncStatusController = StreamController<SyncStatus>.broadcast();

  @override // ← NEU
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  @override // ← NEU
  bool get isSyncing => _isSyncing;

  SyncOrchestrator({required PocketBaseSyncService pocketBaseSync})
      : _pocketBaseSync = pocketBaseSync;

  void _emit(SyncStatus status) {
    if (!_isDisposed && !_syncStatusController.isClosed) {
      _syncStatusController.add(status);
    }
  }

  Future<void> runOnce() async {
    if (kIsWeb) {
      _logger.d('SyncOrchestrator: Skipping sync on Web platform');
      return;
    }

    if (_isDisposed) {
      _logger.w('SyncOrchestrator: bereits disposed – überspringe');
      return;
    }

    if (_isSyncing) {
      _logger.w('SyncOrchestrator: Sync bereits aktiv – überspringe');
      return;
    }

    _isSyncing = true;
    _emit(SyncStatus.running);

    _logger.i('SyncOrchestrator: start');

    try {
      await _pocketBaseSync.syncOnce();

      // ── NEU: Fehlende Bilder nach Record-Sync herunterladen ───────
      await _pocketBaseSync.downloadMissingImages();

      _lastSyncTime = DateTime.now();
      _emit(SyncStatus.success);
      _logger.i('SyncOrchestrator: end (success) – $_lastSyncTime');
    } catch (e, st) {
      _emit(SyncStatus.error);
      _logger.e('SyncOrchestrator: sync failed', error: e, stackTrace: st);
    } finally {
      _isSyncing = false;
    }
  }

  void startPeriodicSync({
    Duration interval = const Duration(minutes: 5),
    bool runImmediately = false,
  }) {
    if (kIsWeb) return;
    stopPeriodicSync();
    _logger.i(
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
      _logger.i('SyncOrchestrator: Periodischer Sync gestoppt');
    }
  }

  void dispose() {
    _isDisposed = true;
    _isSyncing = false;
    stopPeriodicSync();
    _syncStatusController.close();
    _logger.i('SyncOrchestrator: disposed');
  }
}