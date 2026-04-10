// lib/services/pocketbase_sync_service.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/artikel_model.dart';
import 'artikel_db_service.dart';
import 'pocketbase_service.dart';

class PocketBaseSyncService {
  final String collectionName;

  final PocketBaseService _pbService;
  final ArtikelDbService _db;
  final Logger _logger = Logger();

  PocketBaseSyncService(this.collectionName, this._pbService, this._db);

  /// Führt einen kompletten Sync-Zyklus durch: Push → Pull.
  /// Wird im Web sofort abgebrochen (no-op).
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
    }
  }

  /// Lokale Änderungen → PocketBase hochladen.
  Future<void> _pushToPocketBase() async {
    final pending = await _db.getPendingChanges();
    _logger.i('PocketBaseSync: pushing ${pending.length} pending changes');

    for (final artikel in pending) {
      try {
        // FIX Finding 5: UUID von Anführungszeichen bereinigen
        final safeUuid = artikel.uuid.replaceAll('"', '');
        final filter = 'uuid = "$safeUuid"';
        _logger.d('PocketBaseSync: searching for remote record: $filter');

        final list = await _pbService.client
            .collection(collectionName)
            .getList(filter: filter);

        // FIX Finding 3: Gelöschte Artikel remote löschen statt updaten
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
              'Remote record for uuid ${artikel.uuid} already absent — '
              'nothing to delete',
            );
          }
          // FIX Finding 1: 'deleted' als ETag-Marker, remote_path leer lassen
          await _db.markSynced(artikel.uuid, 'deleted');
          continue;
        }

        if (list.items.isNotEmpty) {
          final recId = list.items.first.id;
          final body = artikel.toPocketBaseMap();
          if (_pbService.isAuthenticated && _pbService.currentUserId != null) {
            body['owner'] = _pbService.currentUserId;
          }
          final updated = await _pbService.client
              .collection(collectionName)
              .update(recId, body: body);

          await _db.markSynced(
            artikel.uuid,
            artikel.etag ?? '',
            remotePath: updated.id,
          );
          _logger.d(
            'Updated PB record ${updated.id} for uuid ${artikel.uuid}',
          );
        } else {
          final body = artikel.toPocketBaseMap();
          if (_pbService.isAuthenticated && _pbService.currentUserId != null) {
            body['owner'] = _pbService.currentUserId;
          }
          final created = await _pbService.client
              .collection(collectionName)
              .create(body: body);

          await _db.markSynced(
            artikel.uuid,
            artikel.etag ?? '',
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
        _logger.w(
          'Artikel ${artikel.uuid} bleibt pending für nächsten Sync',
        );
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
    }
  }

  // ==================== NEU: IMAGE DOWNLOAD ====================

  /// Prüft alle synchronisierten Artikel auf fehlende lokale Bilddateien
  /// und lädt diese von PocketBase herunter.
  ///
  /// Strategie:
  /// - Nur Artikel mit remoteBildPfad UND remotePath (PB Record-ID)
  /// - Nur wenn lokaler bildPfad leer oder Datei nicht existiert
  /// - Download über PocketBase File-API (HTTP GET)
  /// - Speicherung im App-Cache-Verzeichnis
  /// - DB-Update über setBildPfadByUuidSilent() → kein Sync-Trigger
  Future<void> downloadMissingImages() async {
    if (kIsWeb) return;

    _logger.i('PocketBaseSync: downloadMissingImages start');
    int downloaded = 0;
    int skipped = 0;
    int failed = 0;

    try {
      // Alle nicht-gelöschten Artikel laden (ohne Pagination-Limit)
      final alleArtikel = await _db.getAlleArtikel(limit: 999999, offset: 0);

      for (final artikel in alleArtikel) {
        try {
          // Kein Remote-Bild vorhanden → überspringen
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

          // Lokales Bild existiert bereits und ist nicht leer → überspringen
          if (artikel.bildPfad.isNotEmpty) {
            final localFile = File(artikel.bildPfad);
            if (localFile.existsSync() && localFile.lengthSync() > 0) {
              skipped++;
              continue;
            }
          }

          // Bild-URL bauen
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

          // HTTP-Download mit Auth-Header
          final response = await http.get(
            Uri.parse(imageUrl),
            headers: _buildAuthHeaders(),
          );

          if (response.statusCode != 200) {
            _logger.w(
              'PocketBaseSync: Image download HTTP ${response.statusCode} '
              'für ${artikel.uuid}',
            );
            failed++;
            continue;
          }

          final bytes = response.bodyBytes;
          if (bytes.isEmpty) {
            _logger.w(
              'PocketBaseSync: Leere Antwort für Bild ${artikel.uuid}',
            );
            failed++;
            continue;
          }

          // Lokalen Pfad erstellen und Datei speichern
          final cacheDir = await getApplicationCacheDirectory();
          final imageDir = Directory(
            '${cacheDir.path}/images/${artikel.uuid}',
          );
          if (!imageDir.existsSync()) {
            imageDir.createSync(recursive: true);
          }

          final localPath = '${imageDir.path}/$remoteBild';
          await File(localPath).writeAsBytes(bytes);

          // DB aktualisieren — NUR bildPfad, OHNE updated_at/etag zu ändern
          // → kein erneuter Push wird ausgelöst
          await _db.setBildPfadByUuidSilent(artikel.uuid, localPath);

          downloaded++;
          _logger.d(
            'PocketBaseSync: Bild gespeichert für '
            '${artikel.uuid}: $localPath',
          );
        } catch (e, st) {
          failed++;
          _logger.w(
            'PocketBaseSync: Image download failed for '
            '${artikel.uuid}: $e',
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
  ///
  /// Format: {pb_url}/api/files/{collectionName}/{recordId}/{filename}
  ///
  /// Das PB-Feld heißt 'bild' (siehe Artikel.fromPocketBase),
  /// aber der Dateiname in remoteBildPfad ist der tatsächliche Filename
  /// auf dem PB-Server (z.B. "foto_abc123.jpg").
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
  ///
  /// Nutzt den Token aus dem bestehenden PocketBase-Client,
  /// falls authentifiziert. PB-Files können auch public sein —
  /// in dem Fall ist der Header optional.
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
      // Auth-Header optional — PB-Files können auch public sein
    }
    return headers;
  }

  /// Sicherer Zugriff auf PocketBase-Felder ohne Exception-Risiko.
  String _safeGet(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}