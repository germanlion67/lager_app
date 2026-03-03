//lib/services/sync_service.dart

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:logger/logger.dart';
import 'package:image/image.dart' as img;
import 'nextcloud_client.dart';
import 'artikel_db_service.dart';
import '../models/artikel_model.dart';
import '../screens/conflict_resolution_screen.dart';
import 'sync_progress_service.dart';
import 'sync_error_recovery.dart';

/// Ergebnis einer Synchronisierung
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
      'SyncResult(pulled: $pulled, pushed: $pushed, conflicts: $conflicts, errors: ${errors.length})';
}

/// Push-Ergebnis für einen einzelnen Artikel
class _PushResult {
  final bool isSuccess;
  final bool isConflict;
  final String? error;

  _PushResult.success() : isSuccess = true, isConflict = false, error = null;
  _PushResult.conflict() : isSuccess = false, isConflict = true, error = null;
  _PushResult.error(this.error) : isSuccess = false, isConflict = false;
}

/// Hauptservice für die Synchronisation zwischen lokaler DB und Nextcloud
class SyncService {
  final NextcloudClient _client;
  final ArtikelDbService _dbService;
  final Logger logger = Logger();
  final SyncProgressService progressService = SyncProgressService();
  final SyncErrorRecoveryService errorRecoveryService = SyncErrorRecoveryService();
  String? _deviceId;

  SyncService(this._client, this._dbService);

  /// Eindeutige Geräte-ID für Konflikterkennung
  Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? 'ios-${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        _deviceId = windowsInfo.computerName;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        _deviceId = linuxInfo.machineId ?? 'linux-${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isMacOS) {
        _deviceId = 'macos-${DateTime.now().millisecondsSinceEpoch}';
      } else {
        _deviceId = 'unknown-${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      logger.w('Could not get device ID: $e');
      _deviceId = 'fallback-${DateTime.now().millisecondsSinceEpoch}';
    }
    
    logger.d('Device ID: $_deviceId');
    return _deviceId!;
  }

  /// Testet die Verbindung und initialisiert notwendige Ordner
  Future<bool> testAndInitialize() async {
    try {
      logger.i('Testing connection to Nextcloud...');
      
      if (!await _client.testConnection()) {
        logger.e('Connection test failed');
        return false;
      }

      await _client.createFolder('items/');
      await _client.createFolder('attachments/');
      
      logger.i('Connection successful and folders initialized');
      return true;
    } catch (e) {
      logger.e('Failed to test and initialize: $e');
      return false;
    }
  }

  /// Führt eine vollständige Synchronisation durch
  Future<SyncResult> syncOnce() async {
    progressService.startOperation('Vollständige Synchronisation');
    int pulled = 0, pushed = 0, conflicts = 0;
    final errors = <String>[];

    logger.i('Starting sync...');
    
    try {
      progressService.updateOperation(
        status: SyncStatus.connecting,
        message: 'Verbinde mit Server...',
      );

      if (!await testAndInitialize()) {
        const errorMsg = 'Failed to initialize connection';
        errors.add(errorMsg);
        progressService.failOperation(Exception(errorMsg));
        return SyncResult(pulled: 0, pushed: 0, conflicts: 0, errors: errors);
      }

      // 1. PUSH: Lokale Änderungen hochladen
      logger.d('Phase 1: Pushing local changes...');
      progressService.updateOperation(
        status: SyncStatus.analyzing,
        message: 'Analysiere lokale Änderungen...',
      );
      
      final pendingChanges = await _dbService.getPendingChanges();
      logger.i('Found ${pendingChanges.length} pending local changes');
      
      progressService.setTotalItems(pendingChanges.length * 2); // Push + Pull
      progressService.updateOperation(
        status: SyncStatus.uploading,
        message: 'Lade lokale Änderungen hoch...',
      );

      for (final artikel in pendingChanges) {
        try {
          progressService.updateOperation(
            currentItem: artikel.name,
            message: 'Lade "${artikel.name}" hoch...',
          );

          final result = await _pushArtikel(artikel);
          if (result.isConflict) {
            conflicts++;
            progressService.incrementStat('conflict');
          } else if (result.isSuccess) {
            pushed++;
            progressService.incrementStat('uploaded');
            // Optional: Anhänge synchronisieren, wenn lokaler Pfad vorhanden ist
            await _trySyncAttachment(artikel);
          }
          progressService.incrementStat('processed');
        } catch (e) {
          final errorMsg = 'Push error for "${artikel.name}": $e';
          errors.add(errorMsg);
          logger.e('Failed to push article ${artikel.name}', error: e);
          
          // Error Recovery
          try {
            final recoveryResult = await errorRecoveryService.handleError(
              e,
              itemId: artikel.uuid,
              itemName: artikel.name,
              context: {'operation': 'push'},
            );
            
            if (recoveryResult.canRetry) {
              await errorRecoveryService.performRetry(
                recoveryResult.error,
                () => _pushArtikel(artikel),
              );
              pushed++;
              progressService.incrementStat('uploaded');
            } else {
              progressService.incrementStat('error');
            }
          } catch (retryError) {
            progressService.incrementStat('error');
            logger.e('Retry failed for ${artikel.name}', error: retryError);
          }
          progressService.incrementStat('processed');
        }
      }

      // 2. PULL: Remote-Änderungen holen
      logger.d('Phase 2: Pulling remote changes...');
      progressService.updateOperation(
        status: SyncStatus.downloading,
        message: 'Lade Remote-Änderungen herunter...',
      );
      
      final remoteItems = await _client.listItemsEtags();
      logger.i('Found ${remoteItems.length} items on server');
      
      // Aktualisiere Total mit Remote Items
      progressService.setTotalItems(pendingChanges.length + remoteItems.length);

      for (final remoteItem in remoteItems) {
        try {
          progressService.updateOperation(
            currentItem: remoteItem.path,
            message: 'Lade "${remoteItem.path}" herunter...',
          );

          if (await _pullArtikel(remoteItem)) {
            pulled++;
            progressService.incrementStat('downloaded');
          }
          progressService.incrementStat('processed');
        } catch (e) {
          final errorMsg = 'Pull error for "${remoteItem.path}": $e';
          errors.add(errorMsg);
          logger.e('Failed to pull item ${remoteItem.path}', error: e);
          
          // Error Recovery
          try {
            final recoveryResult = await errorRecoveryService.handleError(
              e,
              itemId: remoteItem.path,
              itemName: remoteItem.path,
              context: {'operation': 'pull'},
            );
            
            if (recoveryResult.canRetry) {
              await errorRecoveryService.performRetry(
                recoveryResult.error,
                () => _pullArtikel(remoteItem),
              );
              pulled++;
              progressService.incrementStat('downloaded');
            } else {
              progressService.incrementStat('error');
            }
          } catch (retryError) {
            progressService.incrementStat('error');
            logger.e('Retry failed for ${remoteItem.path}', error: retryError);
          }
          progressService.incrementStat('processed');
        }
      }

      // 3. ATTACHMENTS: Systematische Attachment-Synchronisation
      logger.d('Phase 3: Syncing attachments...');
      progressService.updateOperation(
        status: SyncStatus.processing,
        message: 'Synchronisiere Anhänge...',
      );
      
      await syncAttachments();

      // 4. Sync-Zeitstempel aktualisieren
      await _dbService.setLastSyncTime();

      progressService.updateOperation(
        status: SyncStatus.finalizing,
        message: 'Finalisiere Synchronisation...',
        progress: 1.0,
      );

      final result = SyncResult(
        pulled: pulled,
        pushed: pushed,
        conflicts: conflicts,
        errors: errors,
      );

      if (errors.isEmpty) {
        progressService.completeOperation(
          message: 'Synchronisation erfolgreich abgeschlossen: $pushed hochgeladen, $pulled heruntergeladen, $conflicts Konflikte',
        );
      } else {
        progressService.failOperation(
          Exception('Synchronisation mit Fehlern abgeschlossen'),
          message: 'Synchronisation abgeschlossen mit ${errors.length} Fehlern',
        );
      }

      logger.i('Sync completed: $result');
      return result;

    } catch (e) {
      logger.e('General sync error: $e');
      errors.add('General sync error: $e');
      
      progressService.failOperation(
        e,
        message: 'Synchronisation fehlgeschlagen: ${e.toString()}',
      );
      
      return SyncResult(pulled: pulled, pushed: pushed, conflicts: conflicts, errors: errors);
    }
  }

  /// Versucht, das lokale Bild hochzuladen, falls vorhanden und noch kein Remote-Pfad gesetzt ist
  Future<void> _trySyncAttachment(Artikel artikel) async {
    try {
      if ((artikel.bildPfad).isEmpty) return;
      if ((artikel.remoteBildPfad ?? '').isNotEmpty) return;

      final file = File(artikel.bildPfad);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      final filename = artikel.bildPfad.split(Platform.pathSeparator).last;
      final etag = await _client.uploadAttachment(artikel.uuid, filename, bytes);
      if (etag != null) {
        final remotePath = 'attachments/${artikel.uuid}/$filename';
        await _dbService.setRemoteBildPfadByUuid(artikel.uuid, remotePath);
        logger.d('Attachment synced for ${artikel.name}: $remotePath');
      }
    } catch (e) {
      logger.w('Attachment sync skipped for ${artikel.name}: $e');
    }
  }

  /// Lädt einen lokalen Artikel zum Server hoch
  Future<_PushResult> _pushArtikel(Artikel artikel) async {
    try {
      final remotePath = '${artikel.uuid}.json';
      
      final articleToUpload = artikel.copyWith(
        deviceId: await getDeviceId(),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      
      logger.d('Pushing article: ${articleToUpload.name} (UUID: ${articleToUpload.uuid})');

      final newEtag = await _client.uploadItem(
        remotePath,
        articleToUpload.toJson(),
        ifMatch: articleToUpload.etag,
      );

      if (newEtag == null) {
        logger.w('Conflict detected for ${articleToUpload.name}');
        await _resolveConflict(articleToUpload);
        return _PushResult.conflict();
      } else {
        await _dbService.markSynced(articleToUpload.uuid, newEtag);
        logger.d('Successfully pushed ${articleToUpload.name}');
        return _PushResult.success();
      }
    } catch (e) {
      logger.e('Failed to push article ${artikel.name}: $e');
      return _PushResult.error(e.toString());
    }
  }

  /// Lädt einen Remote-Artikel in die lokale DB
  Future<bool> _pullArtikel(RemoteItemMeta remoteItem) async {
    try {
      final uuid = remoteItem.path.replaceAll('.json', '');
      final lokalerArtikel = await _dbService.getArtikelByUUID(uuid);
      
      if (lokalerArtikel != null && lokalerArtikel.etag == remoteItem.etag) {
        logger.d('Article ${remoteItem.path} already up-to-date');
        return false;
      }

      logger.d('Pulling article: ${remoteItem.path}');
      final jsonBody = await _client.downloadItem(remoteItem.path);
      
      await _dbService.upsertFromRemote(remoteItem.path, remoteItem.etag, jsonBody);
      logger.d('Successfully pulled ${remoteItem.path}');
      // Nach Pull: ggf. Remote-Bild herunterladen
      final artikel = await _dbService.getArtikelByUUID(uuid);
      if (artikel != null) {
        await _tryDownloadAttachment(artikel);
      }
      return true;
    } catch (e) {
      logger.e('Failed to pull article ${remoteItem.path}: $e');
      rethrow;
    }
  }

  /// Löst einen Konflikt zwischen lokaler und Remote-Version
  Future<void> _resolveConflict(Artikel lokalerArtikel) async {
    try {
      logger.i('Resolving conflict for ${lokalerArtikel.name}...');
      
      final remotePath = '${lokalerArtikel.uuid}.json';
      final remoteJson = await _client.downloadItem(remotePath);
      final remoteArtikel = Artikel.fromJson(remoteJson);

      logger.d('Conflict details:');
      logger.d('  Local updatedAt: ${lokalerArtikel.updatedAt}');
      logger.d('  Remote updatedAt: ${remoteArtikel.updatedAt}');

      if (lokalerArtikel.updatedAt > remoteArtikel.updatedAt) {
        logger.i('Local version is newer - force pushing');
        final newEtag = await _client.uploadItem(remotePath, lokalerArtikel.toJson());
        if (newEtag != null) {
          await _dbService.markSynced(lokalerArtikel.uuid, newEtag);
        }
      } else if (remoteArtikel.updatedAt > lokalerArtikel.updatedAt) {
        logger.i('Remote version is newer - updating local');
        await _dbService.upsertFromRemote(remotePath, remoteArtikel.etag!, remoteJson);
      } else {
        final localWins = (lokalerArtikel.deviceId ?? '').compareTo(remoteArtikel.deviceId ?? '') < 0;
        if (localWins) {
          logger.i('Same timestamp - local device wins alphabetically');
          final newEtag = await _client.uploadItem(remotePath, lokalerArtikel.toJson());
          if (newEtag != null) {
            await _dbService.markSynced(lokalerArtikel.uuid, newEtag);
          }
        } else {
          logger.i('Same timestamp - remote device wins alphabetically');
          await _dbService.upsertFromRemote(remotePath, remoteArtikel.etag!, remoteJson);
        }
      }

      logger.i('Conflict resolved for ${lokalerArtikel.name}');
    } catch (e) {
      logger.e('Failed to resolve conflict for ${lokalerArtikel.name}: $e');
      throw Exception('Conflict resolution failed: $e');
    }
  }

  /// Versucht, ein Remote-Bild herunterzuladen und lokal zu speichern, falls vorhanden und lokal fehlt
  Future<void> _tryDownloadAttachment(Artikel artikel) async {
    try {
      // Nur wenn remoteBildPfad gesetzt und lokal kein Bild vorhanden
      if ((artikel.remoteBildPfad ?? '').isEmpty) return;
      if ((artikel.bildPfad).isNotEmpty && await File(artikel.bildPfad).exists()) return;

      final remotePath = artikel.remoteBildPfad!;
      final filename = remotePath.split('/').last;
      final bytes = await _client.downloadAttachment(artikel.uuid, filename);

      // Zielordner: cache/images/<uuid>/
      final cacheDir = Directory('cache/images/${artikel.uuid}');
      if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
      final localPath = '${cacheDir.path}/$filename';
      final file = File(localPath);
      await file.writeAsBytes(bytes);

      // Update bildPfad in DB
      await _dbService.setBildPfadByUuid(artikel.uuid, localPath);
      logger.d('Downloaded remote image for ${artikel.name}: $localPath');
      // Nach Bild-Download: Thumbnail erzeugen
      await _cacheThumbnail(artikel.copyWith(bildPfad: localPath));
    } catch (e) {
      logger.w('Remote image download failed for ${artikel.name}: $e');
    }
  }

  /// Erzeugt ein Thumbnail für ein Bild und speichert es im Cache
  Future<void> _cacheThumbnail(Artikel artikel) async {
    try {
      if ((artikel.bildPfad).isEmpty || !await File(artikel.bildPfad).exists()) return;
      final imageFile = File(artikel.bildPfad);
      final bytes = await imageFile.readAsBytes();
      // Thumbnail erzeugen (z.B. mit package:image)
      final original = img.decodeImage(bytes);
      if (original == null) return;
      final thumbnail = img.copyResize(original, width: 128, height: 128);
      final cacheDir = Directory('cache/thumbnails/${artikel.uuid}');
      if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
      final thumbPath = '${cacheDir.path}/thumb.png';
      final thumbBytes = img.encodePng(thumbnail);
      await File(thumbPath).writeAsBytes(thumbBytes);
      await _dbService.setThumbnailPfadByUuid(artikel.uuid, thumbPath);

      // ETag aus Bilddatei oder HTTP-Header (hier Dummy, in Praxis aus Response)
      final etag = 'dummy-thumbnail-etag';
      await _dbService.setThumbnailEtagByUuid(artikel.uuid, etag);
      logger.d('Thumbnail für ${artikel.name} gecached: $thumbPath, ETag: $etag');
    } catch (e) {
      logger.w('Thumbnail-Caching fehlgeschlagen für ${artikel.name}: $e');
    }
  }

  /// Sammelt alle Konflikte für die Enhanced Conflict Resolution UI
  Future<List<ConflictData>> detectConflicts() async {
    final conflicts = <ConflictData>[];
    
    try {
      logger.i('Detecting sync conflicts...');
      
      // Hole alle lokalen Artikel, die Konflikte haben könnten
      final localArtikel = await _dbService.getAlleArtikel();
      final remoteItems = await _client.listItemsEtags();
      
      for (final artikel in localArtikel) {
        try {
          // Suche nach Remote-Version
          final remotePath = '${artikel.uuid}.json';
          final remoteItem = remoteItems.firstWhere(
            (item) => item.path == remotePath,
            orElse: () => throw StateError('Not found'),
          );
          
          // Prüfe ob ETag-Konflikt vorliegt
          if (artikel.etag != null && artikel.etag != remoteItem.etag) {
            logger.d('ETag conflict detected for ${artikel.name}');
            
            // Lade Remote-Version zum Vergleich
            final remoteJson = await _client.downloadItem(remotePath);
            final remoteArtikel = Artikel.fromJson(remoteJson);
            
            // Bestimme Konfliktgrund
            String conflictReason = _determineConflictReason(artikel, remoteArtikel);
            
            conflicts.add(ConflictData(
              localVersion: artikel,
              remoteVersion: remoteArtikel,
              conflictReason: conflictReason,
              detectedAt: DateTime.now(),
            ));
          }
        } catch (e) {
          // Artikel existiert nicht remote oder anderer Fehler
          logger.d('Skipping conflict check for ${artikel.name}: $e');
        }
      }
      
      logger.i('Found ${conflicts.length} conflicts');
      return conflicts;
    } catch (e) {
      logger.e('Error detecting conflicts: $e');
      return [];
    }
  }

  /// Bestimmt den Grund für einen Konflikt
  String _determineConflictReason(Artikel local, Artikel remote) {
    if (local.updatedAt == remote.updatedAt) {
      return 'Gleichzeitige Bearbeitung';
    } else if ((local.updatedAt - remote.updatedAt).abs() < 60000) { // < 1 Minute
      return 'Zeitnahe Bearbeitung (${((local.updatedAt - remote.updatedAt) / 1000).round()}s Unterschied)';
    } else if (local.updatedAt > remote.updatedAt) {
      return 'Lokale Version neuer (${_formatTimeDifference(local.updatedAt - remote.updatedAt)})';
    } else {
      return 'Remote Version neuer (${_formatTimeDifference(remote.updatedAt - local.updatedAt)})';
    }
  }

  /// Formatiert Zeitunterschied in lesbarer Form
  String _formatTimeDifference(int millisDiff) {
    final diff = Duration(milliseconds: millisDiff.abs());
    if (diff.inDays > 0) {
      return '${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    } else {
      return '${diff.inSeconds}s';
    }
  }

  /// Erweiterte Sync-Funktion mit UI-basierter Konfliktauflösung
  Future<Map<String, dynamic>> syncWithConflictResolution() async {
    try {
      logger.i('Starting enhanced sync with conflict resolution...');
      
      // Erste normale Sync-Runde
      await syncOnce();
      
      // Prüfe auf verbleibende Konflikte
      final conflicts = await detectConflicts();
      
      if (conflicts.isEmpty) {
        logger.i('No conflicts found - sync completed successfully');
        return {
          'success': true,
          'conflicts': 0,
          'resolved': 0,
          'message': 'Synchronisation erfolgreich abgeschlossen'
        };
      }
      
      logger.i('Found ${conflicts.length} conflicts requiring user resolution');
      return {
        'success': false,
        'conflicts': conflicts.length,
        'conflictData': conflicts,
        'message': 'Konflikte gefunden - Benutzerentscheidung erforderlich'
      };
      
    } catch (e) {
      logger.e('Enhanced sync failed: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Synchronisation fehlgeschlagen'
      };
    }
  }

  /// Wendet eine Konfliktlösung an (wird von der UI aufgerufen)
  Future<void> applyConflictResolution(
    ConflictData conflict, 
    ConflictResolution resolution, 
    {Artikel? mergedVersion}
  ) async {
    try {
      logger.i('Applying resolution ${resolution.name} for ${conflict.localVersion.name}');
      
      switch (resolution) {
        case ConflictResolution.useLocal:
          await _applyLocalVersion(conflict);
          break;
        case ConflictResolution.useRemote:
          await _applyRemoteVersion(conflict);
          break;
        case ConflictResolution.merge:
          if (mergedVersion != null) {
            await _applyMergedVersion(conflict, mergedVersion);
          } else {
            throw ArgumentError('Merged version required for merge resolution');
          }
          break;
        case ConflictResolution.skip:
          logger.i('Skipping conflict for ${conflict.localVersion.name}');
          break;
      }
      
      logger.i('Successfully applied resolution for ${conflict.localVersion.name}');
    } catch (e) {
      logger.e('Failed to apply resolution for ${conflict.localVersion.name}: $e');
      rethrow;
    }
  }

  /// Wendet die lokale Version an (force push to remote)
  Future<void> _applyLocalVersion(ConflictData conflict) async {
    final remotePath = '${conflict.localVersion.uuid}.json';
    final newEtag = await _client.uploadItem(remotePath, conflict.localVersion.toJson());
    if (newEtag != null) {
      await _dbService.markSynced(conflict.localVersion.uuid, newEtag);
      logger.d('Local version pushed to remote for ${conflict.localVersion.name}');
    }
  }

  /// Wendet die Remote-Version an (update local)
  Future<void> _applyRemoteVersion(ConflictData conflict) async {
    await _dbService.updateArtikel(conflict.remoteVersion);
    await _dbService.markSynced(conflict.remoteVersion.uuid, conflict.remoteVersion.etag!);
    logger.d('Remote version applied locally for ${conflict.remoteVersion.name}');
  }

  /// Wendet eine zusammengeführte Version an
  Future<void> _applyMergedVersion(ConflictData conflict, Artikel mergedVersion) async {
    // Aktualisiere lokale Datenbank
    await _dbService.updateArtikel(mergedVersion);
    
    // Pushe zusammengeführte Version zu Remote
    final remotePath = '${mergedVersion.uuid}.json';
    final newEtag = await _client.uploadItem(remotePath, mergedVersion.toJson());
    if (newEtag != null) {
      await _dbService.markSynced(mergedVersion.uuid, newEtag);
      logger.d('Merged version applied for ${mergedVersion.name}');
    }
  }

  /// Synchronisiert systematisch alle ausstehenden Attachments (Bilder)
  /// Diese Methode wird als separate Phase in syncOnce aufgerufen
  Future<void> syncAttachments() async {
    try {
      logger.i('Starting systematic attachment synchronization...');
      
      // 1. UPLOAD: Lokale Bilder hochladen, die noch keinen Remote-Pfad haben
      progressService.updateOperation(
        status: SyncStatus.uploading,
        message: 'Lade ausstehende Bilder hoch...',
      );
      
      final unsyncedArticles = await _dbService.getUnsyncedArtikel();
      logger.i('Found ${unsyncedArticles.length} articles with unsynced images');
      
      int uploadedCount = 0;
      int failedUploads = 0;
      
      for (final artikel in unsyncedArticles) {
        try {
          progressService.updateOperation(
            currentItem: artikel.name,
            message: 'Lade Bild für "${artikel.name}" hoch...',
          );
          
          await _uploadAttachmentForArticle(artikel);
          uploadedCount++;
          progressService.incrementStat('uploaded');
          logger.d('Successfully uploaded attachment for ${artikel.name}');
          
        } catch (e) {
          failedUploads++;
          progressService.incrementStat('error');
          logger.e('Failed to upload attachment for ${artikel.name}: $e');
          
          // Error Recovery für Attachment Upload
          try {
            final recoveryResult = await errorRecoveryService.handleError(
              e,
              itemId: artikel.uuid,
              itemName: artikel.name,
              context: {'operation': 'attachment_upload'},
            );
            
            if (recoveryResult.canRetry) {
              await errorRecoveryService.performRetry(
                recoveryResult.error,
                () => _uploadAttachmentForArticle(artikel),
              );
              uploadedCount++;
              failedUploads--;
              progressService.incrementStat('uploaded');
              progressService.decrementStat('error');
            }
          } catch (retryError) {
            logger.e('Retry failed for attachment upload ${artikel.name}: $retryError');
          }
        }
      }

      // 2. DOWNLOAD: Remote Bilder herunterladen, die lokal fehlen
      progressService.updateOperation(
        status: SyncStatus.downloading,
        message: 'Lade fehlende Remote-Bilder herunter...',
      );
      
      final allArticles = await _dbService.getAlleArtikel();
      final articlesWithRemoteImages = allArticles.where((artikel) => 
        (artikel.remoteBildPfad ?? '').isNotEmpty && 
        ((artikel.bildPfad).isEmpty || !File(artikel.bildPfad).existsSync())
      ).toList();
      
      logger.i('Found ${articlesWithRemoteImages.length} articles with missing local images');
      
      int downloadedCount = 0;
      int failedDownloads = 0;
      
      for (final artikel in articlesWithRemoteImages) {
        try {
          progressService.updateOperation(
            currentItem: artikel.name,
            message: 'Lade Remote-Bild für "${artikel.name}" herunter...',
          );
          
          await _tryDownloadAttachment(artikel);
          downloadedCount++;
          progressService.incrementStat('downloaded');
          logger.d('Successfully downloaded attachment for ${artikel.name}');
          
        } catch (e) {
          failedDownloads++;
          progressService.incrementStat('error');
          logger.e('Failed to download attachment for ${artikel.name}: $e');
          
          // Error Recovery für Attachment Download
          try {
            final recoveryResult = await errorRecoveryService.handleError(
              e,
              itemId: artikel.uuid,
              itemName: artikel.name,
              context: {'operation': 'attachment_download'},
            );
            
            if (recoveryResult.canRetry) {
              await errorRecoveryService.performRetry(
                recoveryResult.error,
                () => _tryDownloadAttachment(artikel),
              );
              downloadedCount++;
              failedDownloads--;
              progressService.incrementStat('downloaded');
              progressService.decrementStat('error');
            }
          } catch (retryError) {
            logger.e('Retry failed for attachment download ${artikel.name}: $retryError');
          }
        }
      }

      logger.i('Attachment synchronization completed: '
               '$uploadedCount uploaded, $downloadedCount downloaded, '
               '${failedUploads + failedDownloads} failed');
               
    } catch (e) {
      logger.e('General attachment sync error: $e');
      progressService.incrementStat('error');
      rethrow;
    }
  }

  /// Lädt das Attachment (Bild) für einen spezifischen Artikel hoch
  Future<void> _uploadAttachmentForArticle(Artikel artikel) async {
    if ((artikel.bildPfad).isEmpty) {
      throw Exception('No local image path available');
    }
    
    if ((artikel.remoteBildPfad ?? '').isNotEmpty) {
      logger.d('Article ${artikel.name} already has remote image path, skipping upload');
      return;
    }

    final file = File(artikel.bildPfad);
    if (!await file.exists()) {
      throw Exception('Local image file not found: ${artikel.bildPfad}');
    }

    // Zusätzliche Validierung: Datei lesbar und nicht korrupt
    final fileSize = await file.length();
    if (fileSize == 0) {
      throw Exception('Image file is empty: ${artikel.bildPfad}');
    }

    try {
      final bytes = await file.readAsBytes();
      final filename = artikel.bildPfad.split(Platform.pathSeparator).last;
      
      logger.d('Uploading attachment for ${artikel.name}: $filename ($fileSize bytes)');
      
      // Upload via NextcloudClient
      final etag = await _client.uploadAttachment(artikel.uuid, filename, bytes);
      if (etag == null) {
        throw Exception('Upload failed - no ETag returned');
      }

      // Remote-Pfad generieren und in DB speichern
      final remotePath = 'attachments/${artikel.uuid}/$filename';
      await _dbService.setRemoteBildPfadByUuid(artikel.uuid, remotePath);
      
      logger.i('Successfully uploaded attachment for ${artikel.name}: $remotePath');
      
    } catch (e) {
      logger.e('Failed to upload attachment for ${artikel.name}: $e');
      rethrow;
    }
  }
}