// test/helpers/fake_sync_status_provider.dart

import 'dart:async';
import 'package:lager_app/services/sync_orchestrator.dart' show SyncStatus;
import 'package:lager_app/services/sync_status_provider.dart';

class FakeSyncStatusProvider implements SyncStatusProvider {
  final _controller = StreamController<SyncStatus>.broadcast();
  bool _isSyncing = false;

  @override
  Stream<SyncStatus> get syncStatus => _controller.stream;

  @override
  bool get isSyncing => _isSyncing;

  void emitIdle() {
    _isSyncing = false;
    _controller.add(SyncStatus.idle);
  }

  void emitRunning() {
    _isSyncing = true;
    _controller.add(SyncStatus.running);
  }

  void emitSuccess() {
    _isSyncing = false;
    _controller.add(SyncStatus.success);
  }

  void emitError() {
    _isSyncing = false;
    _controller.add(SyncStatus.error);
  }

  void dispose() => _controller.close();
}