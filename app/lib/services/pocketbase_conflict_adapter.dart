// lib/services/pocketbase_conflict_adapter.dart
//
// Minimaler Adapter der SyncService für den ConflictResolutionScreen
// implementiert — ohne Nextcloud-Abhängigkeit.
//
// ConflictResolutionScreen ruft ausschließlich applyConflictResolution() auf.
// Alle anderen Methoden werden nie aufgerufen und werfen UnimplementedError
// als Sicherheitsnetz.
//
// Ausgelagert aus main.dart (O-020): Eigenständige Service-Klasse
// gehört nicht in den App-Einstiegspunkt.

import 'package:lager_app/models/artikel_model.dart';
import 'package:lager_app/services/app_log_service.dart';
import 'package:lager_app/services/artikel_db_service.dart';
import 'package:lager_app/services/conflict_resolution_utils.dart';
import 'package:lager_app/services/sync_error_recovery.dart';
import 'package:lager_app/services/sync_progress_service.dart';
import 'package:lager_app/services/sync_service.dart';
import 'package:lager_app/screens/conflict_resolution_screen.dart';

final _log = AppLogService.logger;

class PocketBaseConflictAdapter implements SyncService {
  final ArtikelDbService _db;

  PocketBaseConflictAdapter(this._db);

  @override
  final SyncProgressService progressService = SyncProgressService();

  @override
  final SyncErrorRecoveryService errorRecoveryService =
      SyncErrorRecoveryService();

  @override
  Future<void> applyConflictResolution(
    ConflictData conflict,
    ConflictResolution resolution, {
    Artikel? mergedVersion,
  }) async {
    switch (resolution) {
      case ConflictResolution.useLocal:
        await _db.markForForceLocal(conflict.localVersion.uuid);
        _log.i(
          '[Conflict] Lokale Version behalten: ${conflict.localVersion.uuid}',
        );
        return;

      case ConflictResolution.useRemote:
        final remoteEtag = requireRemoteBaselineEtag(conflict.remoteVersion);
        await _db.upsertArtikel(
          conflict.remoteVersion,
          etag: remoteEtag,
        );
        await _db.clearPendingResolution(conflict.remoteVersion.uuid);
        _log.i(
          '[Conflict] Remote-Version übernommen: ${conflict.remoteVersion.uuid}',
        );
        return;

      case ConflictResolution.merge:
        if (mergedVersion != null) {
          await _db.updateArtikel(mergedVersion);
          await _db.markForForceMerge(mergedVersion.uuid);
          _log.i(
            '[Conflict] Zusammengeführte Version gespeichert: '
            '${mergedVersion.uuid}',
          );
        } else {
          _log.w(
            '[Conflict] Merge gewählt, aber mergedVersion ist null: '
            '${conflict.localVersion.uuid}',
          );
        }
        return;

      case ConflictResolution.skip:
        _log.i(
          '[Conflict] Übersprungen: ${conflict.localVersion.uuid}',
        );
        return;
    }
  }

  @override
  Future<List<ConflictData>> detectConflicts() async {
    throw UnimplementedError(
      'PocketBaseConflictAdapter.detectConflicts ist nicht implementiert. '
      'Der ConflictResolutionScreen benötigt nur applyConflictResolution().',
    );
  }

  @override
  Future<String> getDeviceId() async {
    throw UnimplementedError(
      'PocketBaseConflictAdapter.getDeviceId ist nicht implementiert. '
      'Der ConflictResolutionScreen benötigt nur applyConflictResolution().',
    );
  }

  @override
  Future<void> syncAttachments() async {
    throw UnimplementedError(
      'PocketBaseConflictAdapter.syncAttachments ist nicht implementiert. '
      'Der ConflictResolutionScreen benötigt nur applyConflictResolution().',
    );
  }

  @override
  Future<SyncResult> syncOnce() async {
    throw UnimplementedError(
      'PocketBaseConflictAdapter.syncOnce ist nicht implementiert. '
      'Der ConflictResolutionScreen benötigt nur applyConflictResolution().',
    );
  }

  @override
  Future<Map<String, dynamic>> syncWithConflictResolution() async {
    throw UnimplementedError(
      'PocketBaseConflictAdapter.syncWithConflictResolution ist nicht '
      'implementiert. Der ConflictResolutionScreen benötigt nur '
      'applyConflictResolution().',
    );
  }

  @override
  Future<bool> testAndInitialize() async {
    throw UnimplementedError(
      'PocketBaseConflictAdapter.testAndInitialize ist nicht implementiert. '
      'Der ConflictResolutionScreen benötigt nur applyConflictResolution().',
    );
  }
}