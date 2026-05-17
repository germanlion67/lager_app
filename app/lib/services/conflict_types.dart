// lib/services/conflict_types.dart
// O-014: Conflict-Typen + SyncServiceInterface
// Extrahiert aus sync_service.dart + conflict_resolution_screen.dart

import '../models/artikel_model.dart';
import 'sync_progress_service.dart';
import 'sync_error_recovery.dart';

// ─────────────────────────────────────────────
// ConflictData
// ─────────────────────────────────────────────

class ConflictData {
  final Artikel localVersion;
  final Artikel remoteVersion;
  final String conflictReason;
  final DateTime detectedAt;

  const ConflictData({
    required this.localVersion,
    required this.remoteVersion,
    required this.conflictReason,
    required this.detectedAt,
  });
}

// ─────────────────────────────────────────────
// ConflictResolution
// ─────────────────────────────────────────────

enum ConflictResolution { useLocal, useRemote, merge, skip }

// ─────────────────────────────────────────────
// SyncResult
// ─────────────────────────────────────────────

class SyncResult {
  final int pulled;
  final int pushed;
  final int conflicts;
  final List<String> errors;

  SyncResult({
    required this.pulled,
    required this.pushed,
    required this.conflicts,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccessful => errors.isEmpty;

  @override
  String toString() =>
      'SyncResult(pulled: $pulled, pushed: $pushed, '
      'conflicts: $conflicts, errors: ${errors.length})';
}

// ─────────────────────────────────────────────
// SyncServiceInterface
// ─────────────────────────────────────────────

/// Interface für alle SyncService-Implementierungen.
/// Entkoppelt ConflictResolutionScreen, SyncConflictHandler und main.dart
/// von der konkreten Nextcloud/PocketBase-Implementierung.
abstract class SyncServiceInterface {
  SyncProgressService get progressService;
  SyncErrorRecoveryService get errorRecoveryService;

  Future<String> getDeviceId();
  Future<bool> testAndInitialize();
  Future<SyncResult> syncOnce();
  Future<void> syncAttachments();
  Future<List<ConflictData>> detectConflicts();
  Future<Map<String, dynamic>> syncWithConflictResolution();
  Future<void> applyConflictResolution(
    ConflictData conflict,
    ConflictResolution resolution, {
    Artikel? mergedVersion,
  });
}