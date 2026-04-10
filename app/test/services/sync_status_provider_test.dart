import 'package:flutter_test/flutter_test.dart';
import 'package:lager_app/services/sync_orchestrator.dart' show SyncStatus;
import '../helpers/fake_sync_status_provider.dart';

void main() {
  group('FakeSyncStatusProvider', () {
    late FakeSyncStatusProvider provider;

    setUp(() {
      provider = FakeSyncStatusProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('initial state is not syncing', () {
      expect(provider.isSyncing, isFalse);
    });

    test('emitRunning sets isSyncing to true', () {
      provider.emitRunning();
      expect(provider.isSyncing, isTrue);
    });

    test('emitSuccess sets isSyncing to false', () {
      provider.emitRunning();
      provider.emitSuccess();
      expect(provider.isSyncing, isFalse);
    });

    test('emitError sets isSyncing to false', () {
      provider.emitRunning();
      provider.emitError();
      expect(provider.isSyncing, isFalse);
    });

    test('syncStatus stream emits correct sequence', () async {
      final events = <SyncStatus>[];
      final sub = provider.syncStatus.listen(events.add);

      provider.emitRunning();
      provider.emitSuccess();
      provider.emitError();
      provider.emitIdle();

      await Future<void>.delayed(Duration.zero);

      expect(events, [
        SyncStatus.running,
        SyncStatus.success,
        SyncStatus.error,
        SyncStatus.idle,
      ]);

      await sub.cancel();
    });

    test('syncStatus is broadcast stream (multiple listeners)', () async {
      final events1 = <SyncStatus>[];
      final events2 = <SyncStatus>[];

      final sub1 = provider.syncStatus.listen(events1.add);
      final sub2 = provider.syncStatus.listen(events2.add);

      provider.emitRunning();
      provider.emitSuccess();

      await Future<void>.delayed(Duration.zero);

      expect(events1, [SyncStatus.running, SyncStatus.success]);
      expect(events2, [SyncStatus.running, SyncStatus.success]);

      await sub1.cancel();
      await sub2.cancel();
    });
  });
}