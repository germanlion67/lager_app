// lib/services/pocketbase_sync_service.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../models/artikel_model.dart';
import 'app_log_service.dart';
import 'pocketbase_sync_contracts.dart';

typedef ConflictCallback = Future<void> Function(
  Artikel lokalerArtikel,
  Artikel remoteArtikel,
);

class PocketBaseSyncService {
  final String collectionName;
  final SyncPocketBaseService _pbService;
  final SyncArtikelDbService _db;
  final Logger _logger = AppLogService.logger;

  ConflictCallback? onConflictDetected;

  PocketBaseSyncService(this.collectionName, this._pbService, this._db);

  Future<void> syncOnce() async {
    if (kIsWeb) {
      _logger.d('PocketBaseSync: Skipping sync on Web platform');
      return;
    }

    _logger.i('PocketBaseSync: syncOnce start (collection=$collectionName)');
    try {
      await _pushToPocketBase();
      await _pullFromPocketBase();
      await _db.setLastSyncTime();
      _logger.i('PocketBaseSync: syncOnce end (success)');
    } catch (e, st) {
      _logger.e('PocketBaseSync: syncOnce failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  bool _isDirty(Artikel artikel) {
    final etag = artikel.etag ?? '';
    return etag.isEmpty;
  }

  bool _hasPendingResolution(Artikel artikel) {
    final pending = artikel.pendingResolution?.trim() ?? '';
    return pending.isNotEmpty;
  }

  bool _isForceResolution(Artikel artikel) {
    final pending = artikel.pendingResolution?.trim() ?? '';
    return pending == 'force_local' || pending == 'force_merge';
  }

  bool _needsConflictBecauseMissingBase(Artikel artikel) {
    if (_isForceResolution(artikel)) return false;
    final base = artikel.lastSyncedEtag?.trim() ?? '';
    return base.isEmpty;
  }

  Map<String, dynamic> _asStringDynamicMap(dynamic value) {
    if (value == null) return <String, dynamic>{};

    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), val),
      );
    }

    return <String, dynamic>{};
  }

  String _extractRecordEtag(dynamic record) {
    final data = _asStringDynamicMap(record.data);
    final updated = _safeGet(data, 'updated');
    return updated.isNotEmpty ? updated : record.id.toString();
  }

  bool _hasRemoteChangedSinceLastSync(Artikel lokal, String remoteEtag) {
    final base = lokal.lastSyncedEtag?.trim() ?? '';
    if (base.isEmpty) return false;
    return remoteEtag.isNotEmpty && remoteEtag != base;
  }

  Artikel _recordToArtikel(dynamic record) {
    final data = _asStringDynamicMap(record.data);
    return Artikel.fromPocketBase(
      data,
      record.id.toString(),
      created: _safeGet(data, 'created'),
      updated: _safeGet(data, 'updated'),
    );
  }

  bool _isDuplicateUuidError(Object error) {
    final text = error.toString().toLowerCase();

    final mentionsUuid = text.contains('uuid');
    final mentionsDuplicate = text.contains('duplicate') ||
        text.contains('unique') ||
        text.contains('already exists');

    final mentionsValidation =
        text.contains('validation') && text.contains('uuid');

    return mentionsUuid && (mentionsDuplicate || mentionsValidation);
  }

  Future<dynamic> _findRemoteRecordByUuid(String uuid) async {
    final safeUuid = uuid.replaceAll('"', '');
    final filter = 'uuid = "$safeUuid"';

    final list = await _pbService.client
        .collection(collectionName)
        .getList(
          page: 1,
          perPage: 1,
          filter: filter,
        );

    if (list.items.isEmpty) {
      return null;
    }

    return list.items.first;
  }

  Future<void> _markLocalAsSyncedFromRemote(
    Artikel artikel,
    dynamic remoteRecord,
  ) async {
    final remoteData = _asStringDynamicMap(remoteRecord.data);
    final remoteEtag = _safeGet(remoteData, 'updated').isNotEmpty
        ? _safeGet(remoteData, 'updated')
        : remoteRecord.id.toString();

    await _db.markSynced(
      artikel.uuid,
      remoteEtag,
      remotePath: remoteRecord.id.toString(),
    );
  }

  Future<void> _emitConflictIfPossible(
    Artikel lokal,
    Artikel remote,
  ) async {
    if (onConflictDetected != null) {
      await onConflictDetected!(lokal, remote);
    }
  }

  Future<void> _pushToPocketBase() async {
    final pending = await _db.getPendingChanges();
    _logger.i('PocketBaseSync: pushing ${pending.length} pending changes');

    for (final artikel in pending) {
      try {
        final safeUuid = artikel.uuid.replaceAll('"', '');
        final filter = 'uuid = "$safeUuid"';

        final list = await _pbService.client
            .collection(collectionName)
            .getList(filter: filter);

        if (artikel.deleted == true) {
          if (list.items.isNotEmpty) {
            final remoteRecord = list.items.first;
            final remoteEtag = _extractRecordEtag(remoteRecord);
            final remoteArtikel = _recordToArtikel(remoteRecord);

            final missingConflictBase =
                _needsConflictBecauseMissingBase(artikel);

            if (missingConflictBase) {
              _logger.w(
                'PocketBaseSync: Delete-Konflikt ohne last_synced_etag '
                'für ${artikel.uuid}',
              );
              await _emitConflictIfPossible(artikel, remoteArtikel);
              continue;
            }

            final hasConflict = !_isForceResolution(artikel) &&
                _hasRemoteChangedSinceLastSync(artikel, remoteEtag);

            if (hasConflict) {
              _logger.w(
                'PocketBaseSync: Delete-Konflikt erkannt für ${artikel.uuid}',
              );
              await _emitConflictIfPossible(artikel, remoteArtikel);
              continue;
            }

            await _pbService.client
                .collection(collectionName)
                .delete(remoteRecord.id.toString());
          }

          await _db.markSynced(artikel.uuid, 'deleted');
          continue;
        }

        if (list.items.isNotEmpty) {
          final remoteRecord = list.items.first;
          final recId = remoteRecord.id.toString();
          final remoteEtag = _extractRecordEtag(remoteRecord);
          final remoteArtikel = _recordToArtikel(remoteRecord);

          final missingConflictBase =
              _needsConflictBecauseMissingBase(artikel);

          if (missingConflictBase) {
            _logger.w(
              'PocketBaseSync: Konflikt ohne last_synced_etag '
              'für ${artikel.uuid}',
            );
            await _emitConflictIfPossible(artikel, remoteArtikel);
            continue;
          }

          final hasConflict = !_isForceResolution(artikel) &&
              _hasRemoteChangedSinceLastSync(artikel, remoteEtag);

          if (hasConflict) {
            _logger.w('PocketBaseSync: Konflikt erkannt für ${artikel.uuid}');
            await _emitConflictIfPossible(artikel, remoteArtikel);
            continue;
          }

          final body = <String, dynamic>{
            ...artikel.toPocketBaseMap(),
          };

          if (_pbService.isAuthenticated && _pbService.currentUserId != null) {
            body['owner'] = _pbService.currentUserId;
          }

          final updated = await _pbService.client
              .collection(collectionName)
              .update(recId, body: body);

          final updatedData = _asStringDynamicMap(updated.data);
          final updatedEtag = _safeGet(updatedData, 'updated').isNotEmpty
              ? _safeGet(updatedData, 'updated')
              : updated.id.toString();

          await _db.markSynced(
            artikel.uuid,
            updatedEtag,
            remotePath: updated.id.toString(),
          );
        } else {
          final body = <String, dynamic>{
            ...artikel.toPocketBaseMap(),
          };

          if (_pbService.isAuthenticated && _pbService.currentUserId != null) {
            body['owner'] = _pbService.currentUserId;
          }

          try {
            final created = await _pbService.client
                .collection(collectionName)
                .create(body: body);

            final createdData = _asStringDynamicMap(created.data);
            final createdEtag = _safeGet(createdData, 'updated').isNotEmpty
                ? _safeGet(createdData, 'updated')
                : created.id.toString();

            await _db.markSynced(
              artikel.uuid,
              createdEtag,
              remotePath: created.id.toString(),
            );
          } catch (e) {
            if (!_isDuplicateUuidError(e)) {
              rethrow;
            }

            _logger.w(
              'PocketBaseSync: Duplicate-UUID beim Create erkannt; '
              'starte Recovery-Lookup (uuid=${artikel.uuid})',
            );

            try {
              final existing = await _findRemoteRecordByUuid(artikel.uuid);

              if (existing == null) {
                throw StateError(
                  'Duplicate-UUID erkannt, aber kein Remote-Record per uuid '
                  'gefunden (uuid=${artikel.uuid})',
                );
              }

              await _markLocalAsSyncedFromRemote(artikel, existing);

              _logger.i(
                'PocketBaseSync: Duplicate-UUID-Recovery erfolgreich '
                '(uuid=${artikel.uuid}, remoteId=${existing.id})',
              );
            } catch (recoveryError, recoveryStack) {
              _logger.e(
                'PocketBaseSync: Duplicate-UUID-Recovery fehlgeschlagen '
                '(uuid=${artikel.uuid})',
                error: recoveryError,
                stackTrace: recoveryStack,
              );
              rethrow;
            }
          }
        }
      } catch (e, st) {
        _logger.e(
          'PocketBase push failed for uuid=${artikel.uuid}',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  Future<void> _pullFromPocketBase() async {
    try {
      final records = await _pbService.client
          .collection(collectionName)
          .getFullList()
          .timeout(const Duration(seconds: 30));

      final remoteUuids = <String>{};

      for (final r in records) {
        try {
          final data = _asStringDynamicMap(r.data);
          final updatedRaw = _safeGet(data, 'updated');

          final artikel = Artikel.fromPocketBase(
            data,
            r.id.toString(),
            created: _safeGet(data, 'created'),
            updated: updatedRaw,
          );

          final etag = updatedRaw.isNotEmpty ? updatedRaw : r.id.toString();
          final localArtikel = await _db.getArtikelByUUID(artikel.uuid);

          if (localArtikel != null) {
            final localDirty = _isDirty(localArtikel);
            final hasPending = _hasPendingResolution(localArtikel);
            final missingConflictBase =
                _needsConflictBecauseMissingBase(localArtikel);
            final remoteChanged =
                _hasRemoteChangedSinceLastSync(localArtikel, etag);

            if (hasPending) {
              _logger.i(
                'PocketBaseSync: Pull übersprungen wegen pending_resolution '
                'für ${artikel.uuid}',
              );
              if (artikel.uuid.isNotEmpty) {
                remoteUuids.add(artikel.uuid);
              }
              continue;
            }

            if (localDirty && missingConflictBase) {
              _logger.w(
                'PocketBaseSync: Pull-Konflikt ohne last_synced_etag '
                'für ${artikel.uuid}',
              );
              await _emitConflictIfPossible(localArtikel, artikel);

              if (artikel.uuid.isNotEmpty) {
                remoteUuids.add(artikel.uuid);
              }
              continue;
            }

            if (localDirty && remoteChanged) {
              _logger.w(
                'PocketBaseSync: Pull-Konflikt erkannt für ${artikel.uuid}',
              );
              await _emitConflictIfPossible(localArtikel, artikel);

              if (artikel.uuid.isNotEmpty) {
                remoteUuids.add(artikel.uuid);
              }
              continue;
            }

            if (localDirty) {
              _logger.i(
                'PocketBaseSync: Pull übersprungen, lokale Änderungen '
                'vorhanden für ${artikel.uuid}',
              );
              if (artikel.uuid.isNotEmpty) {
                remoteUuids.add(artikel.uuid);
              }
              continue;
            }
          }

          await _db.upsertArtikel(artikel, etag: etag);

          if (artikel.uuid.isNotEmpty) {
            remoteUuids.add(artikel.uuid);
          }
        } catch (e, st) {
          _logger.e(
            'Failed to upsert remote record ${r.id}',
            error: e,
            stackTrace: st,
          );
        }
      }

      if (remoteUuids.isNotEmpty) {
        final localArtikel = await _db.getAlleArtikel(limit: 10000);
        for (final lokal in localArtikel) {
          if (lokal.remotePath != null &&
              lokal.remotePath!.isNotEmpty &&
              !remoteUuids.contains(lokal.uuid)) {
            final localDirty = _isDirty(lokal);
            final hasPending = _hasPendingResolution(lokal);

            if (hasPending || localDirty) {
              _logger.i(
                'PocketBaseSync: Lokale Löschung übersprungen wegen '
                'offener lokaler Änderungen für ${lokal.uuid}',
              );
              continue;
            }

            _logger.i(
              'PocketBaseSync: Lösche lokal '
              '(remote nicht mehr vorhanden): ${lokal.name}',
            );
            await _db.deleteArtikel(lokal);
          }
        }
      }
    } catch (e, st) {
      _logger.e('PocketBase pull failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> downloadMissingImages() async {
    if (kIsWeb) return;

    _logger.i('PocketBaseSync: downloadMissingImages start');
    int downloaded = 0;
    int skipped = 0;
    int failed = 0;

    try {
      final alleArtikel = await _db.getAlleArtikel();

      for (final artikel in alleArtikel) {
        try {
          final remoteBild = artikel.remoteBildPfad;
          final recordId = artikel.remotePath;

          if (remoteBild == null ||
              remoteBild.isEmpty ||
              recordId == null ||
              recordId.isEmpty) {
            skipped++;
            continue;
          }

          bool mussNeuLaden = false;

          if (artikel.bildPfad.isEmpty) {
            mussNeuLaden = true;
          } else {
            final localFile = File(artikel.bildPfad);

            if (!localFile.existsSync() || localFile.lengthSync() == 0) {
              mussNeuLaden = true;
            } else {
              if (!artikel.bildPfad.endsWith(remoteBild)) {
                mussNeuLaden = true;
                _logger.d(
                  'Bild-Dateiname hat sich geändert für ${artikel.uuid}. '
                  'Lade neu.',
                );
              }

              final lastModified = localFile.lastModifiedSync();
              if (artikel.aktualisiertAm.isAfter(
                lastModified.add(const Duration(seconds: 2)),
              )) {
                mussNeuLaden = true;
                _logger.d(
                  'Bild in PocketBase ist neuer als lokale Datei für '
                  '${artikel.uuid}. Lade neu.',
                );
              }
            }
          }

          if (!mussNeuLaden) {
            skipped++;
            continue;
          }

          final imageUrl = _buildImageUrl(recordId, remoteBild);
          if (imageUrl == null) {
            skipped++;
            continue;
          }

          _logger.d(
            'PocketBaseSync: Downloading image for ${artikel.uuid}: $imageUrl',
          );

          final response = await http
              .get(Uri.parse(imageUrl), headers: _buildAuthHeaders())
              .timeout(AppConfig.networkTimeout);

          if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
            failed++;
            _logger.w(
              'PocketBaseSync: Image download HTTP ${response.statusCode} '
              'für ${artikel.uuid}',
            );
            continue;
          }

          final cacheDir = await getApplicationCacheDirectory();
          final imageDir = Directory('${cacheDir.path}/images/${artikel.uuid}');
          if (!imageDir.existsSync()) {
            imageDir.createSync(recursive: true);
          }

          if (imageDir.existsSync()) {
            for (final file in imageDir.listSync()) {
              if (file is File) {
                file.deleteSync();
              }
            }
          }

          final localPath = '${imageDir.path}/$remoteBild';
          await File(localPath).writeAsBytes(response.bodyBytes);
          await _db.setBildPfadByUuidSilent(artikel.uuid, localPath);

          downloaded++;
          _logger.d(
            'PocketBaseSync: Bild gespeichert für ${artikel.uuid}: $localPath',
          );
        } catch (e) {
          failed++;
          _logger.w('PocketBaseSync: Image download failed for ${artikel.uuid}: $e');
        }
      }

      _logger.i(
        'PocketBaseSync: downloadMissingImages end '
        '(downloaded: $downloaded, skipped: $skipped, failed: $failed)',
      );
    } catch (e, st) {
      _logger.e(
        'PocketBaseSync: downloadMissingImages failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  String? _buildImageUrl(String recordId, String filename) {
    try {
      if (!_pbService.hasClient || _pbService.url.isEmpty) return null;
      return Uri.parse(_pbService.url)
          .resolve(
            '/api/files/$collectionName/$recordId/'
            '${Uri.encodeComponent(filename)}',
          )
          .toString();
    } catch (e) {
      _logger.w('Fehler beim Erstellen der Bild-URL: $e');
      return null;
    }
  }

  Map<String, String> _buildAuthHeaders() {
    final headers = <String, String>{};
    if (_pbService.hasClient && _pbService.isAuthenticated) {
      final token = _pbService.client.authStore.token;
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  String _safeGet(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return '';
    return value.toString();
  }
}