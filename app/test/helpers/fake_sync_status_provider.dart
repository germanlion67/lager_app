// test/helpers/fake_sync_status_provider.dart

import 'dart:async';
import 'package:lager_app/services/sync_orchestrator.dart' show SyncStatus;
import 'package:lager_app/services/sync_status_provider.dart';

class FakeSyncStatusProvider implements SyncStatusProvider {
  final _controller = StreamController<SyncStatus>.broadcast();
  bool _isSyncing = false;
  DateTime? _fakeLastSyncTime;

  @override
  Stream<SyncStatus> get syncStatus => _controller.stream;

  @override
  bool get isSyncing => _isSyncing;

  // NEU: Implementierung des Getters
  @override
  DateTime? get lastSyncTime => _fakeLastSyncTime;

  // NEU: Implementierung der Methode
  @override
  Future<void> runOnce() async {
    // Simuliert den Start eines Syncs
    emitRunning();
    // Kurze Verzögerung simulieren
    await Future<void>.delayed(const Duration(milliseconds: 100));
    emitSuccess();
  }

  // Hilfsmethode für Tests, um die Zeit manuell zu setzen
  void setLastSyncTime(DateTime time) {
    _fakeLastSyncTime = time;
  }

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
    _fakeLastSyncTime = DateTime.now(); // Zeit stempeln bei Erfolg
    _controller.add(SyncStatus.success);
  }

  void emitError() {
    _isSyncing = false;
    _controller.add(SyncStatus.error);
  }

  void dispose() => _controller.close();
}