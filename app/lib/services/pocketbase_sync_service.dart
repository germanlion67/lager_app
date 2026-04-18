// lib/services/pocketbase_sync_service.dart
//
// CHANGES v0.8.5:
//   F1 — downloadMissingImages: Datei-Existenz-Check korrigiert.
//         Vorher: artikel.bildPfad.isNotEmpty → skip (auch wenn Datei fehlt).
//         Jetzt:  Datei muss existieren UND > 0 Bytes sein.
//   F4 — _pushToPocketBase: ETag-basierte Konflikt-Erkennung vor PATCH.
//         Wenn Server-updated_at != lokaler ETag → Konflikt → UI-Callback.
//   F4 — ConflictCallback-Typedef für lose Kopplung zur UI.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/artikel_model.dart';
import 'artikel_db_service.dart';
import 'pocketbase_service.dart';

import '../config/app_config.dart'; // adjust path to where AppConfig lives

// ── F4: Konflikt-Callback-Typedef ────────────────────────────────────────────
// Begründung: PocketBaseSyncService soll keine UI-Abhängigkeit haben.
// Der Callback erlaubt main.dart/SyncOrchestrator die Konflikt-UI zu steuern,
// ohne dass der Service Flutter-Widgets importieren muss.
typedef ConflictCallback = Future<void> Function(
  Artikel lokalerArtikel,
  Artikel remoteArtikel,
);

class PocketBaseSyncService {
  final String collectionName;

  final PocketBaseService _pbService;
  final ArtikelDbService _db;
  final Logger _logger = Logger();

  // ── F4: Optionaler Konflikt-Callback ─────────────────────────────────────
  // Wird von SyncOrchestrator gesetzt, nachdem die UI bereit ist.
  ConflictCallback? onConflictDetected;

  PocketBaseSyncService(this.collectionName, this._pbService, this._db);

  /// Führt einen kompletten Sync-Zyklus durch: Push → Pull.
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
      rethrow; // ← NEU: Exception nach oben weiterleiten für SyncOrchestrator
    }
  }

  /// Lokale Änderungen → PocketBase hochladen.
  ///
  /// F4: Vor jedem PATCH wird der Remote-updated_at mit dem lokalen ETag
  /// verglichen. Weichen sie ab, wurde der Record auf dem Server geändert
  /// → Konflikt-Callback wird aufgerufen statt blind zu überschreiben.
  Future<void> _pushToPocketBase() async {
    final pending = await _db.getPendingChanges();
    _logger.i('PocketBaseSync: pushing ${pending.length} pending changes');

    for (final artikel in pending) {
      try {
        final safeUuid = artikel.uuid.replaceAll('"', '');
        final filter = 'uuid = "$safeUuid"';
        _logger.d('PocketBaseSync: searching for remote record: $filter');

        final list = await _pbService.client
            .collection(collectionName)
            .getList(filter: filter);

        // Gelöschte Artikel remote löschen
        if (artikel.deleted == true) {
          if (list.items.isNotEmpty) {
            await _pbService.client
                .collection(collectionName)
                .delete(list.items.first.id);
            _logger.d(
              'Deleted PB record ${list.items.first.id} '
              'for uuid ${artikel.uuid}',
            );
          } else {
            _logger.d(
              'Remote record for uuid ${artikel.uuid} already absent',
            );
          }
          await _db.markSynced(artikel.uuid, 'deleted');
          continue;
        }

        if (list.items.isNotEmpty) {
          final remoteRecord = list.items.first;
          final recId = remoteRecord.id;

          // ── F4: Konflikt-Erkennung ──────────────────────────────────────
          // Der lokale ETag ist der `updated`-Timestamp vom letzten Pull.
          // Wenn der Server jetzt einen anderen `updated`-Wert hat,
          // wurde der Record auf dem Server geändert → Konflikt.
          final remoteUpdated = _safeGet(remoteRecord.data, 'updated');
          final lokalerEtag = artikel.etag ?? '';

          // Nur prüfen wenn wir einen ETag haben (= Artikel war schon mal
          // synchronisiert). Neue Artikel (etag == null) haben keinen Konflikt.
          if (lokalerEtag.isNotEmpty &&
              lokalerEtag != 'deleted' &&
              remoteUpdated.isNotEmpty &&
              lokalerEtag != remoteUpdated) {
            _logger.w(
              'PocketBaseSync: Konflikt erkannt für ${artikel.uuid} '
              '(lokal ETag: $lokalerEtag, remote updated: $remoteUpdated)',
            );

            if (onConflictDetected != null) {
              try {
                // Remote-Version für Vergleich laden
                final remoteArtikel = Artikel.fromPocketBase(
                  Map<String, dynamic>.from(remoteRecord.data),
                  remoteRecord.id,
                  created: _safeGet(remoteRecord.data, 'created'),
                  updated: remoteUpdated,
                );
                await onConflictDetected!(artikel, remoteArtikel);
              } catch (e, st) {
                _logger.e(
                  'PocketBaseSync: Konflikt-Callback fehlgeschlagen',
                  error: e,
                  stackTrace: st,
                );
              }
            } else {
              _logger.w(
                'PocketBaseSync: Kein Konflikt-Callback registriert — '
                'überspringe Artikel ${artikel.uuid}',
              );
            }
            // Artikel nicht pushen — Konflikt muss erst aufgelöst werden
            continue;
          }

          // Kein Konflikt → normal updaten
          final body = artikel.toPocketBaseMap();
          if (_pbService.isAuthenticated && _pbService.currentUserId != null) {
            body['owner'] = _pbService.currentUserId;
          }
          final updated = await _pbService.client
              .collection(collectionName)
              .update(recId, body: body);

          await _db.markSynced(
            artikel.uuid,
            _safeGet(updated.data, 'updated').isNotEmpty
                ? _safeGet(updated.data, 'updated')
                : updated.id,
            remotePath: updated.id,
          );
          _logger.d(
            'Updated PB record ${updated.id} for uuid ${artikel.uuid}',
          );
        } else {
          // Neuer Artikel → POST
          final body = artikel.toPocketBaseMap();
          if (_pbService.isAuthenticated && _pbService.currentUserId != null) {
            body['owner'] = _pbService.currentUserId;
          }
          final created = await _pbService.client
              .collection(collectionName)
              .create(body: body);

          // ETag = updated-Timestamp des neu erstellten Records
          final createdEtag = _safeGet(created.data, 'updated').isNotEmpty
              ? _safeGet(created.data, 'updated')
              : created.id;

          await _db.markSynced(
            artikel.uuid,
            createdEtag,
            remotePath: created.id,
          );
          _logger.d(
            'Created PB record ${created.id} for uuid ${artikel.uuid}',
          );
        }
      } catch (e, st) {
        _logger.e(
          'PocketBase push failed for uuid=${artikel.uuid}',
          error: e,
          stackTrace: st,
        );
        _logger.w('Artikel ${artikel.uuid} bleibt pending für nächsten Sync');
      }
    }
    _logger.i('PocketBaseSync: push phase completed');
  }

  /// Remote-Records → Lokale DB herunterladen.
  Future<void> _pullFromPocketBase() async {
    _logger.i('PocketBaseSync: pulling remote records');

    try {
      final records = await _pbService.client
          .collection(collectionName)
          .getFullList();
      _logger.i('PocketBaseSync: fetched ${records.length} remote records');

      final remoteUuids = <String>{};

      for (final r in records) {
        try {
          final updatedRaw = _safeGet(r.data, 'updated');
          final createdRaw = _safeGet(r.data, 'created');

          final artikel = Artikel.fromPocketBase(
            Map<String, dynamic>.from(r.data),
            r.id,
            created: createdRaw,
            updated: updatedRaw,
          );

          // ETag = updated-Timestamp (eindeutig pro Record-Version)
          final etag = updatedRaw.isNotEmpty ? updatedRaw : r.id;

          await _db.upsertArtikel(artikel, etag: etag);
          _logger.d('Upserted local record for uuid ${artikel.uuid}');

          if (artikel.uuid.isNotEmpty) remoteUuids.add(artikel.uuid);
        } catch (e, st) {
          _logger.e(
            'Failed to upsert remote record ${r.id}',
            error: e,
            stackTrace: st,
          );
        }
      }

      if (remoteUuids.isNotEmpty) {
        final localArtikel = await _db.getAlleArtikel();
        for (final lokal in localArtikel) {
          if (!remoteUuids.contains(lokal.uuid)) {
            await _db.deleteArtikel(lokal);
            _logger.d(
              'Lokal soft-deleted (remote nicht mehr vorhanden): '
              '${lokal.uuid}',
            );
          }
        }
      } else {
        _logger.w(
          'PocketBaseSync: remoteUuids ist leer — '
          'lokale Lösch-Synchronisation übersprungen.',
        );
      }
    } catch (e, st) {
      _logger.e('PocketBase pull failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── IMAGE DOWNLOAD ────────────────────────────────────────────────────────

  /// Prüft alle synchronisierten Artikel auf fehlende lokale Bilddateien
  /// und lädt diese von PocketBase herunter.
  Future<void> downloadMissingImages() async {
    if (kIsWeb) return;

    _logger.i('PocketBaseSync: downloadMissingImages start');
    int downloaded = 0;
    int skipped = 0;
    int failed = 0;

    try {
      final alleArtikel = await _db.getAlleArtikel();

      for (final artikel in alleArtikel) {
        String? imageUrl; // <-- declare outside so catch blocks can use it
        try {
          final remoteBild = artikel.remoteBildPfad;
          final recordId = artikel.remotePath;

          if (remoteBild == null || remoteBild.isEmpty) {
            skipped++;
            continue;
          }
          if (recordId == null || recordId.isEmpty) {
            skipped++;
            continue;
          }

          // ── F1: Korrigierter Existenz-Check ──────────────────────────────
          // Vorher: artikel.bildPfad.isNotEmpty → skip
          //         (übersprang auch Artikel mit veraltetem/ungültigem Pfad)
          // Jetzt:  Datei muss physisch existieren UND > 0 Bytes haben.
          //         Ein leerer oder nicht-existierender Pfad → Download.
          if (artikel.bildPfad.isNotEmpty) {
            try {
              final localFile = File(artikel.bildPfad);
              if (localFile.existsSync() && localFile.lengthSync() > 0) {
                skipped++;
                continue; // Bild ist wirklich vorhanden → überspringen
              }
              // Datei existiert nicht oder ist leer → neu herunterladen
              _logger.d(
                'PocketBaseSync: Lokale Bilddatei fehlt oder leer für '
                '${artikel.uuid} (Pfad: ${artikel.bildPfad}) → re-download',
              );
            } catch (fileError) {
              // Dateisystem-Fehler → sicherheitshalber neu herunterladen
              _logger.w(
                'PocketBaseSync: Datei-Check fehlgeschlagen für '
                '${artikel.uuid}: $fileError → re-download',
              );
            }
          }

          final imageUrl = _buildImageUrl(recordId, remoteBild);
          if (imageUrl == null) {
            _logger.w(
              'PocketBaseSync: Konnte keine Bild-URL bauen für '
              'Artikel ${artikel.uuid} (recordId: $recordId)',
            );
            skipped++;
            continue;
          }

          _logger.d(
            'PocketBaseSync: Downloading image for '
            '${artikel.uuid}: $imageUrl',
          );

          final response = await http
              .get(
                Uri.parse(imageUrl),
                headers: _buildAuthHeaders(),
              )
              .timeout(AppConfig.networkTimeout);

          if (response.statusCode != 200) {
            _logger.w(
              'PocketBaseSync: Image download HTTP ${response.statusCode} '
              '${artikel.uuid} (url: ${imageUrl body: ${response.body}',
            );
            failed++;
            continue;
          }

          
          final bytes = response.bodyBytes;
          if (bytes.isEmpty) {
            _logger.w(
              'PocketBaseSync: Leere Antwort für Bild '
              '${artikel.uuid} (url: $imageUrl)',
            );
            failed++;
            continue;
          }


          
          final cacheDir = await getApplicationCacheDirectory();
          final imageDir = Directory(
            '${cacheDir.path}/images/${artikel.uuid}',
          );
          if (!imageDir.existsSync()) {
            imageDir.createSync(recursive: true);
          }

          final localPath = '${imageDir.path}/$remoteBild';
          await File(localPath).writeAsBytes(bytes);

          await _db.setBildPfadByUuidSilent(artikel.uuid, localPath);

          downloaded++;
          _logger.d(
            'PocketBaseSync: Bild gespeichert für '
            '${artikel.uuid}: $localPath',
          );
        } on TimeoutException catch (e, st) {
          failed++;
          _logger.w(
            'PocketBaseSync: Image download timeout '
            '(${AppConfig.networkTimeout.inSeconds}s) '
            'für Artikel ${artikel.uuid} (url: ${imageUrl ?? "n/a"})',
            error: e,
            stackTrace: st,
          );
        } catch (e, st) {
          failed++;
          _logger.w(
            'PocketBaseSync: Image download failed for '
            '${artikel.uuid} (url: ${imageUrl ?? "n/a"}): $e',
            error: e,
            stackTrace: st,
          );
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

  /// Baut die PocketBase File-URL für ein Artikel-Bild.
  String? _buildImageUrl(String recordId, String filename) {
    try {
      if (!_pbService.hasClient || _pbService.url.isEmpty) return null;
      final baseUri = Uri.parse(_pbService.url);
      return baseUri
          .resolve(
            '/api/files/$collectionName/$recordId/'
            '${Uri.encodeComponent(filename)}',
          )
          .toString();
    } catch (e) {
      _logger.w('PocketBaseSync: _buildImageUrl failed: $e');
      return null;
    }
  }

  /// Baut Auth-Headers für den PocketBase File-Download.
  Map<String, String> _buildAuthHeaders() {
    final headers = <String, String>{};
    try {
      if (_pbService.hasClient && _pbService.isAuthenticated) {
        final token = _pbService.client.authStore.token;
        if (token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (_) {
      // Auth-Header optional
    }
    return headers;
  }

  String _safeGet(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}
