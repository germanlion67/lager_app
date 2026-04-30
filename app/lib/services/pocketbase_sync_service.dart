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

import 'package:path/path.dart' as p;

typedef ConflictCallback = Future<void> Function(
  Artikel lokalerArtikel,
  Artikel remoteArtikel,
);

// JSON-only Requests (getList, delete, Recovery-Lookup)
const _kPushRequestTimeout = Duration(seconds: 30);

// Datei-Uploads (create/update mit Bild) — 878 KB braucht bei
// schlechtem Mobilsignal deutlich mehr als 30s
const _kPushUploadTimeout = Duration(seconds: 120);

class PocketBaseSyncService {
  final String collectionName;
  final SyncPocketBaseService _pbService;
  final SyncArtikelDbService _db;
  final Logger _logger = AppLogService.logger;

  ConflictCallback? onConflictDetected;

  PocketBaseSyncService(this.collectionName, this._pbService, this._db);

  /* ─────────────────────────────────────────────────────────── */

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

  /* ───────────────────────────────────────────────────────────
     Basis-Hilfsfunktionen
     ─────────────────────────────────────────────────────────── */

  bool _isDirty(Artikel artikel) => (artikel.etag ?? '').isEmpty;

  bool _hasPendingResolution(Artikel artikel) =>
      (artikel.pendingResolution?.trim() ?? '').isNotEmpty;

  bool _isForceResolution(Artikel artikel) {
    final v = (artikel.pendingResolution ?? '').trim();
    return v == 'force_local' || v == 'force_merge';
  }

  bool _needsConflictBecauseMissingBase(Artikel a, dynamic remote) {
    if (_isForceResolution(a)) return false;

    final remoteEtag = _extractRecordEtag(remote);

    if ((a.lastSyncedEtag ?? '').trim().isNotEmpty) {
      return a.lastSyncedEtag != remoteEtag;
    }

    if (a.etag != null && a.etag == remoteEtag) return false;
    return true;
  }

  Map<String, dynamic> _asStringDynamicMap(dynamic value) {
    if (value == null) return <String, dynamic>{};
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  String _extractRecordEtag(dynamic record) {
    final data = _asStringDynamicMap(record.data);
    final updated = _safeGet(data, 'updated');
    return updated.isNotEmpty ? updated : record.id.toString();
  }

  bool _hasRemoteChangedSinceLastSync(Artikel lokal, String remoteEtag) {
    final base = (lokal.lastSyncedEtag ?? '').trim();
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

  /* ───────────────────────────────────────────────────────────
     Fehlererkennung
     ─────────────────────────────────────────────────────────── */

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

  /* ───────────────────────────────────────────────────────────
     Push-Logik
     ─────────────────────────────────────────────────────────── */

  Future<void> _findAndDeleteRemote(
    dynamic remoteRecord,
    Artikel artikel,
  ) async {
    await _pbService.client
        .collection(collectionName)
        .delete(remoteRecord.id.toString())
        .timeout(_kPushRequestTimeout);
    await _db.markSynced(artikel.uuid, 'deleted');
  }

  Future<void> _pushToPocketBase() async {
    final pending = await _db.getPendingChanges();

    int pushCreated = 0, pushUpdated = 0, pushDeleted = 0;
    int pushConflicts = 0, pushErrors = 0;

    _logger.i('PocketBaseSync: pushing ${pending.length} pending changes');

    for (final artikel in pending) {
      try {
        final safeUuid = artikel.uuid.replaceAll('"', '');
        final filter = 'uuid = "$safeUuid"';
        final list = await _pbService.client
            .collection(collectionName)
            .getList(filter: filter)
            .timeout(_kPushRequestTimeout);

        /* ---------- DELETE ---------- */
        if (artikel.deleted == true) {
          if (list.items.isNotEmpty) {
            final remoteRecord = list.items.first;
            final remoteEtag = _extractRecordEtag(remoteRecord);
            final remoteArtikel = _recordToArtikel(remoteRecord);

            final missingBase =
                _needsConflictBecauseMissingBase(artikel, remoteRecord);
            if (missingBase) {
              pushConflicts++;
              final snapshot = await _db.loadRemoteConflictSnapshot(artikel.uuid);
              await _emitConflictIfPossible(artikel, snapshot ?? remoteArtikel);
              continue;
            }

            final hasConflict = !_isForceResolution(artikel) &&
                _hasRemoteChangedSinceLastSync(artikel, remoteEtag);
            if (hasConflict) {
              pushConflicts++;
              final snapshot = await _db.loadRemoteConflictSnapshot(artikel.uuid);
              await _emitConflictIfPossible(artikel, snapshot ?? remoteArtikel);
              continue;
            }

            await _findAndDeleteRemote(remoteRecord, artikel);
            pushDeleted++;
            _logger.i('SYNC|PUSH|DELETE  ok  uuid=${artikel.uuid}');
          } else {
            await _db.markSynced(artikel.uuid, 'deleted');
            pushDeleted++;
            _logger.i(
              'SYNC|PUSH|DELETE  ok(local-only)  uuid=${artikel.uuid}',
            );
          }
          continue;
        }

        /* ---------- UPDATE ---------- */
        if (list.items.isNotEmpty) {
          final remoteRecord = list.items.first;
          final remoteArtikel = _recordToArtikel(remoteRecord);
          final remoteEtag = _extractRecordEtag(remoteRecord);

          final missingBase =
              _needsConflictBecauseMissingBase(artikel, remoteRecord);
          if (missingBase) {
            pushConflicts++;
            final snapshot = await _db.loadRemoteConflictSnapshot(artikel.uuid);
            await _emitConflictIfPossible(artikel, snapshot ?? remoteArtikel);
            continue;
          }

          final hasConflict = !_isForceResolution(artikel) &&
              _hasRemoteChangedSinceLastSync(artikel, remoteEtag);
          if (hasConflict) {
            pushConflicts++;
            final snapshot = await _db.loadRemoteConflictSnapshot(artikel.uuid);
            await _emitConflictIfPossible(artikel, snapshot ?? remoteArtikel);
            continue;
          }

          final body = <String, dynamic>{...artikel.toPocketBaseMap()};
          if (_pbService.isAuthenticated && _pbService.currentUserId != null) {
            body['owner'] = _pbService.currentUserId;
          }

          final remoteData = _asStringDynamicMap(remoteRecord.data);
          if (artikel.bildPfad.trim().isEmpty &&
              _safeGet(remoteData, 'bild').isNotEmpty) {
            body['bild'] = null;
          }

          final files = _buildFiles(artikel);

          // Upload-Timeout nur wenn Dateien mitgesendet werden (Fix B)
          final updateTimeout =
              files.isEmpty ? _kPushRequestTimeout : _kPushUploadTimeout;

          final updated = await _pbService.client
              .collection(collectionName)
              .update(remoteRecord.id.toString(), body: body, files: files)
              .timeout(updateTimeout);

          final updatedEtag = _extractRecordEtag(updated);
          await _db.markSynced(
            artikel.uuid,
            updatedEtag,
            remotePath: updated.id.toString(),
            remoteBildPfad: _extractBildName(updated.data), // ← Fix B-003
          );
          pushUpdated++;
          _logger.i('SYNC|PUSH|UPDATE  ok  uuid=${artikel.uuid}');
          continue;
        }

        /* ---------- CREATE ---------- */
        final body = <String, dynamic>{...artikel.toPocketBaseMap()};
        if (_pbService.isAuthenticated && _pbService.currentUserId != null) {
          body['owner'] = _pbService.currentUserId;
        }

        final files = _buildFiles(artikel);

        // Upload-Timeout nur wenn Dateien mitgesendet werden (Fix B)
        final createTimeout =
            files.isEmpty ? _kPushRequestTimeout : _kPushUploadTimeout;

        try {
          final created = await _pbService.client
              .collection(collectionName)
              .create(body: body, files: files)
              .timeout(createTimeout);

          final createdEtag = _extractRecordEtag(created);
          await _db.markSynced(
            artikel.uuid,
            createdEtag,
            remotePath: created.id.toString(),
            remoteBildPfad: _extractBildName(created.data), // ← Fix B-003
          );
          pushCreated++;
          _logger.i('SYNC|PUSH|CREATE  ok  uuid=${artikel.uuid}');
        } catch (e) {
          // Fix C — Timeout-after-success Recovery:
          // Der Server hat den Record möglicherweise bereits erstellt,
          // aber die Antwort kam nicht mehr rechtzeitig an.
          // Dasselbe gilt für Duplicate-UUID-Fehler.
          // In beiden Fällen: Recovery-Lookup statt direktem Rethrow.
          final isTimeout = e is TimeoutException;
          if (!_isDuplicateUuidError(e) && !isTimeout) rethrow;

          _logger.w(
            'PocketBaseSync: Create ohne Antwort '
            '(${isTimeout ? "Timeout" : "Duplicate-UUID"}); '
            'starte Recovery-Lookup (uuid=${artikel.uuid})',
          );

          final existing = await _findRemoteRecordByUuid(artikel.uuid)
              .timeout(_kPushRequestTimeout);

          if (existing == null) {
            // Timeout, aber Record existiert auch remote nicht →
            // echter Fehler, kein stiller Recovery möglich
            _logger.w(
              'PocketBaseSync: Recovery-Lookup ohne Ergebnis '
              '(uuid=${artikel.uuid}) — Create fehlgeschlagen',
            );
            rethrow;
          }

          await _markLocalAsSyncedFromRemote(artikel, existing);
          pushCreated++;
          _logger.i(
            'PocketBaseSync: Create-Recovery erfolgreich '
            '(uuid=${artikel.uuid}, remoteId=${existing.id})',
          );
        }
      } catch (err, st) {
        pushErrors++;
        _logger.w(
          'SYNC|PUSH  fail  uuid=${artikel.uuid}  '
          'msg="${err.toString().split('\n').first}"',
        );
        _logger.e(
          'PocketBase push failed (uuid=${artikel.uuid})',
          error: err,
          stackTrace: st,
        );
      }
    }

    _logger.i(
      'SYNC|PUSH  done  '
      'created=$pushCreated  updated=$pushUpdated  deleted=$pushDeleted  '
      'conflicts=$pushConflicts  errors=$pushErrors  '
      'total=${pending.length}',
    );
  }

  /* ───────────────────────────────────────────────────────────
     Helper – Bild in Multipart-Datei verpacken
     ─────────────────────────────────────────────────────────── */

  List<http.MultipartFile> _buildFiles(Artikel artikel) {
    if (kIsWeb) return const [];

    final path = artikel.bildPfad.trim();
    if (path.isEmpty) return const [];
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() == 0) return const [];

    final remoteName = (artikel.remoteBildPfad ?? '').trim();
    if (remoteName.isNotEmpty && remoteName == p.basename(path)) {
      return const [];
    }

    return [
      http.MultipartFile.fromBytes(
        'bild',
        file.readAsBytesSync(),
        filename: p.basename(path),
      ),
    ];
  }

  /* ───────────────────────────────────────────────────────────
     Pull-Logik
     ─────────────────────────────────────────────────────────── */

  Future<void> _pullFromPocketBase() async {
    int pullUpserted = 0, pullSkipped = 0, pullConflicts = 0;
    int pullDeleted = 0, pullErrors = 0;

    try {
      final records = await _pbService.client
          .collection(collectionName)
          .getFullList()
          .timeout(const Duration(seconds: 30));

      final remoteUuids = <String>{};

      for (final r in records) {
        try {
          final artikel = _recordToArtikel(r);
          final etag = _extractRecordEtag(r);
          final localArtikel = await _db.getArtikelByUUID(artikel.uuid);

          if (localArtikel != null) {
            final localDirty = _isDirty(localArtikel);
            final hasPending = _hasPendingResolution(localArtikel);
            final missingBase =
                _needsConflictBecauseMissingBase(localArtikel, r);
            final remoteChanged =
                _hasRemoteChangedSinceLastSync(localArtikel, etag);

            if (hasPending) {
              pullSkipped++;
              remoteUuids.add(artikel.uuid);
              continue;
            }

            if (localDirty && (missingBase || remoteChanged)) {
              pullConflicts++;

              // FIX 2: Kein _emitConflictIfPossible hier.
              // Der Pull erkennt den Konflikt nur intern und speichert
              // den Remote-Stand für die Konflikt-UI.
              // Der Callback wird ausschließlich vom Push ausgelöst —
              // dort hat der User bereits die Konflikt-UI gesehen.
              //
              // Remote-Stand mit Bild-Info persistent speichern damit
              // die Konflikt-UI (ausgelöst durch Push) die korrekte
              // Remote-Version inkl. Bild anzeigen kann (Fix 3).
              final remoteBildName = _extractBildName(r.data);
              final artikelMitBild = remoteBildName != null
                  ? artikel.copyWith(remoteBildPfad: remoteBildName)
                  : artikel;

              await _db.saveRemoteConflictSnapshot(
                uuid: artikel.uuid,
                remoteArtikel: artikelMitBild,
              );

              _logger.d(
                'SYNC|PULL  conflict(local-dirty)  uuid=${artikel.uuid}  '
                'remoteBild=${remoteBildName ?? "–"}  '
                '→ snapshot gespeichert, kein Callback',
              );

              remoteUuids.add(artikel.uuid);
              continue;
            }

            if (localDirty) {
              pullSkipped++;
              remoteUuids.add(artikel.uuid);
              continue;
            }
          }

          final remoteBildName = _safeGet(r.data, 'bild');
          if (remoteBildName.isEmpty &&
              (localArtikel?.remoteBildPfad ?? '').isNotEmpty) {
            await _db.clearBildInfoByUuidSilent(artikel.uuid);
          }

          await _db.upsertArtikel(artikel, etag: etag);
          pullUpserted++;
          remoteUuids.add(artikel.uuid);
        } catch (e, st) {
          pullErrors++;
          _logger.e('Upsert remote record failed', error: e, stackTrace: st);
        }
      }

      if (remoteUuids.isNotEmpty) {
        final locals = await _db.getAlleArtikel(limit: 10000);
        for (final l in locals) {
          if ((l.remotePath ?? '').isNotEmpty &&
              !remoteUuids.contains(l.uuid)) {
            if (_isDirty(l) || _hasPendingResolution(l)) continue;
            await _db.deleteArtikel(l);
            pullDeleted++;
          }
        }
      }

      _logger.i(
        'SYNC|PULL  done  '
        'upserted=$pullUpserted  skipped=$pullSkipped  '
        'conflicts=$pullConflicts  deleted=$pullDeleted  '
        'errors=$pullErrors  total=${records.length}',
      );
    } catch (e, st) {
      _logger.e('PocketBase pull failed', error: e, stackTrace: st);
      _logger.w(
        'SYNC|PULL  fail  msg="${e.toString().split('\n').first}"',
      );
      rethrow;
    }
  }

  /* ───────────────────────────────────────────────────────────
     Bilder nachladen
     ─────────────────────────────────────────────────────────── */

  Future<void> downloadMissingImages() async {
    if (kIsWeb) return;

    _logger.i('PocketBaseSync: downloadMissingImages start');
    int downloaded = 0, skipped = 0, failed = 0;

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

          bool needsDownload = false;
          if (artikel.bildPfad.isEmpty) {
            needsDownload = true;
          } else {
            final f = File(artikel.bildPfad);
            if (!f.existsSync() || f.lengthSync() == 0) {
              needsDownload = true;
            } else if (!artikel.bildPfad.endsWith(remoteBild)) {
              needsDownload = true;
            } else {
              final m = f.lastModifiedSync();
              if (artikel.aktualisiertAm
                  .isAfter(m.add(const Duration(seconds: 2)))) {
                needsDownload = true;
              }
            }
          }

          if (!needsDownload) {
            skipped++;
            continue;
          }

          final url = _buildImageUrl(recordId, remoteBild);
          if (url == null) {
            skipped++;
            continue;
          }

          final resp = await http
              .get(Uri.parse(url), headers: _buildAuthHeaders())
              .timeout(AppConfig.networkTimeout);

          if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
            failed++;
            continue;
          }

          final cacheDir = await getApplicationCacheDirectory();
          final imgDir =
              Directory('${cacheDir.path}/images/${artikel.uuid}');
          if (!imgDir.existsSync()) imgDir.createSync(recursive: true);
          for (final f in imgDir.listSync()) {
            if (f is File) f.deleteSync();
          }

          final localPath = '${imgDir.path}/$remoteBild';
          await File(localPath).writeAsBytes(resp.bodyBytes);
          await _db.setBildPfadByUuidSilent(artikel.uuid, localPath);
          downloaded++;
        } catch (_) {
          failed++;
        }
      }

      _logger.i(
        'PocketBaseSync: downloadMissingImages end '
        '(downloaded=$downloaded, skipped=$skipped, failed=$failed)',
      );
    } catch (e, st) {
      _logger.e(
        'PocketBaseSync: downloadMissingImages failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  /* ─────────────────────────────────────────────────────────── */

  String? _buildImageUrl(String recId, String filename) {
    if (!_pbService.hasClient || _pbService.url.isEmpty) return null;
    return Uri.parse(_pbService.url)
        .resolve(
          '/api/files/$collectionName/$recId/${Uri.encodeComponent(filename)}',
        )
        .toString();
  }

  Map<String, String> _buildAuthHeaders() {
    final headers = <String, String>{};
    if (_pbService.hasClient && _pbService.isAuthenticated) {
      final token = _pbService.client.authStore.token;
      if (token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> _findRemoteRecordByUuid(String uuid) async {
    final list = await _pbService.client
        .collection(collectionName)
        .getList(
          page: 1,
          perPage: 1,
          filter: 'uuid = "${uuid.replaceAll('"', '')}"',
        )
        .timeout(_kPushRequestTimeout);
    return list.items.isNotEmpty ? list.items.first : null;
  }

  Future<void> _markLocalAsSyncedFromRemote(
    Artikel a,
    dynamic remote,
  ) async =>
      _db.markSynced(
        a.uuid,
        _extractRecordEtag(remote),
        remotePath: remote.id.toString(),
      );

  Future<void> _emitConflictIfPossible(Artikel l, Artikel r) async {
    if (onConflictDetected != null) await onConflictDetected!(l, r);
  }

  String _safeGet(Map<String, dynamic> m, String k) =>
      (m[k] ?? '').toString();

  /// PocketBase gibt `bild` nach File-Upload als List<`String`> zurück,
  /// nicht als String. Diese Methode normalisiert beide Fälle.
  String? _extractBildName(dynamic data) {
    final raw = _asStringDynamicMap(data)['bild'];
    if (raw == null) return null;
    if (raw is List && raw.isNotEmpty) return raw.first.toString();
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }
     
}