// lib/services/sync_orchestrator.dart
//
// Zentraler Einstiegspunkt für die Datensynchronisation.
// Verwendet PocketBase als einziges Sync-Backend.
//
// ⚠️ NUR für Mobile/Desktop – im Web wird PocketBase direkt verwendet,
// es gibt keine lokale DB und keinen Sync.

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';
import 'pocketbase_sync_service.dart';

class SyncOrchestrator {
  final PocketBaseSyncService _pocketBaseSync;
  final Logger _logger = Logger();

  SyncOrchestrator({required PocketBaseSyncService pocketBaseSync})
      : _pocketBaseSync = pocketBaseSync;

  /// Führt einen kompletten Sync-Zyklus durch.
  /// Wird im Web sofort abgebrochen (no-op).
  Future<void> runOnce() async {
    if (kIsWeb) {
      _logger.d('SyncOrchestrator: Skipping sync on Web platform');
      return;
    }

    _logger.i('SyncOrchestrator: start');
    try {
      await _pocketBaseSync.syncOnce();
      _logger.i('SyncOrchestrator: end (success)');
    } catch (e, st) {
      _logger.e('SyncOrchestrator: sync failed', error: e, stackTrace: st);
    }
  }
}
