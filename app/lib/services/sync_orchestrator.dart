// lib/services/sync_orchestrator.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';
import 'pocketbase_sync_service.dart';

enum SyncStatus { idle, running, success, error }

class SyncOrchestrator {
  final PocketBaseSyncService _pocketBaseSync;
  final Logger _logger = Logger();

  bool _isSyncing = false;
  bool _isDisposed = false; // ✅ Fix Bug 1: disposed-Flag

  Timer? _syncTimer;

  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  bool get isSyncing => _isSyncing;

  SyncOrchestrator({required PocketBaseSyncService pocketBaseSync})
      : _pocketBaseSync = pocketBaseSync;

  // ✅ Fix Bug 1: Sicherer Emit – kein Add auf geschlossenem Stream
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

    // ✅ Fix Bug 1: Nach dispose() keinen Sync mehr starten
    if (_isDisposed) {
      _logger.w('SyncOrchestrator: bereits disposed – überspringe');
      return;
    }

    if (_isSyncing) {
      _logger.w('SyncOrchestrator: Sync bereits aktiv – überspringe');
      return;
    }

    _isSyncing = true;
    _emit(SyncStatus.running); // ✅ Sicherer Emit

    _logger.i('SyncOrchestrator: start');

    try {
      await _pocketBaseSync.syncOnce();
      _lastSyncTime = DateTime.now();
      _emit(SyncStatus.success); // ✅ Sicherer Emit
      _logger.i('SyncOrchestrator: end (success) – $_lastSyncTime');
    } catch (e, st) {
      _emit(SyncStatus.error); // ✅ Sicherer Emit
      _logger.e('SyncOrchestrator: sync failed', error: e, stackTrace: st);
    } finally {
      _isSyncing = false;
    }
  }

  // ✅ Fix Bug 2: runImmediately-Parameter statt hartem sofort-Sync
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
    if (runImmediately) runOnce(); // ✅ Nur wenn explizit gewünscht
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
    _isDisposed = true; // ✅ Fix Bug 1: Erst Flag, dann cleanup
    stopPeriodicSync();
    _syncStatusController.close();
    _logger.i('SyncOrchestrator: disposed');
  }
}