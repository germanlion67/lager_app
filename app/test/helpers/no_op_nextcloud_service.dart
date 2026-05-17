// test/helpers/no_op_nextcloud_service.dart
//
// Test-Double für SyncStatusProvider.
// Ersetzt den alten NoOpNextcloudService — kein Timer, kein HTTP.

import 'dart:async';
import 'package:lager_app/services/sync_status_provider.dart';
import 'package:lager_app/services/sync_orchestrator.dart' show SyncStatus;

class NoOpNextcloudService implements SyncStatusProvider {
  final _controller = StreamController<SyncStatus>.broadcast();

  @override
  Stream<SyncStatus> get syncStatus => _controller.stream;

  @override
  bool get isSyncing => false;

  @override
  DateTime? get lastSyncTime => null;

  @override
  Future<void> runOnce() async {} // ← NEU — No-Op, kein Netzwerk
  
  void emitStatus(SyncStatus status) => _controller.add(status);

  void dispose() => _controller.close();
}