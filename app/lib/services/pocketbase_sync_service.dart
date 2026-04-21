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
import '../config/app_config.dart';

typedef ConflictCallback = Future<void> Function(
  Artikel lokalerArtikel,
  Artikel remoteArtikel,
);

class PocketBaseSyncService {
  final String collectionName;
  final PocketBaseService _pbService;
  final ArtikelDbService _db;
  final Logger _logger = Logger();

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
            await _pbService.client
                .collection(collectionName)
                .delete(list.items.first.id);
          }
          await _db.markSynced(artikel.uuid, 'deleted');
          continue;
        }

        if (list.items.isNotEmpty) {
          final remoteRecord = list.items.first;
          final recId = remoteRecord.id;

          final remoteUpdated = _safeGet(remoteRecord.data, 'updated');
          final lokalerEtag = artikel.etag ?? '';

          if (lokalerEtag.isNotEmpty &&
              lokalerEtag != 'deleted' &&
              remoteUpdated.isNotEmpty &&
              lokalerEtag != remoteUpdated) {
            _logger.w('PocketBaseSync: Konflikt erkannt für ${artikel.uuid}');

            if (onConflictDetected != null) {
              final remoteArtikel = Artikel.fromPocketBase(
                Map<String, dynamic>.from(remoteRecord.data),
                remoteRecord.id,
                created: _safeGet(remoteRecord.data, 'created'),
                updated: remoteUpdated,
              );
              await onConflictDetected!(artikel, remoteArtikel);
            }
            continue;
          }

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
        } else {
          final body = artikel.toPocketBaseMap();
          if (_pbService.isAuthenticated && _pbService.currentUserId != null) {
            body['owner'] = _pbService.currentUserId;
          }
          final created = await _pbService.client
              .collection(collectionName)
              .create(body: body);

          final createdEtag = _safeGet(created.data, 'updated').isNotEmpty
              ? _safeGet(created.data, 'updated')
              : created.id;

          await _db.markSynced(artikel.uuid, createdEtag,
              remotePath: created.id,);
        }
      } catch (e, st) {
        _logger.e('PocketBase push failed for uuid=${artikel.uuid}',
            error: e, stackTrace: st,);
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
          final updatedRaw = _safeGet(r.data, 'updated');
          final artikel = Artikel.fromPocketBase(
            Map<String, dynamic>.from(r.data),
            r.id,
            created: _safeGet(r.data, 'created'),
            updated: updatedRaw,
          );

          final etag = updatedRaw.isNotEmpty ? updatedRaw : r.id;
          await _db.upsertArtikel(artikel, etag: etag);

          if (artikel.uuid.isNotEmpty) remoteUuids.add(artikel.uuid);
        } catch (e) {
          _logger.e('Failed to upsert remote record ${r.id}: $e');
        }
      }

      if (remoteUuids.isNotEmpty) {
        final localArtikel = await _db.getAlleArtikel(limit: 10000);
        for (final lokal in localArtikel) {
          if (lokal.remotePath != null &&
              lokal.remotePath!.isNotEmpty &&
              !remoteUuids.contains(lokal.uuid)) {
            _logger.i(
                'PocketBaseSync: Lösche lokal (remote nicht mehr vorhanden): ${lokal.name}',);
            await _db.deleteArtikel(lokal);
          }
        }
      }
    } catch (e) {
      _logger.e('PocketBase pull failed: $e');
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
          final remoteBild = artikel.remoteBildPfad; // z.B. "bild_abc123.jpg"
          final recordId = artikel.remotePath;

          if (remoteBild == null || remoteBild.isEmpty || recordId == null || recordId.isEmpty) {
            skipped++;
            continue;
          }

          // --- VERBESSERTE LOGIK START ---
          bool mussNeuLaden = false;

          if (artikel.bildPfad.isEmpty) {
            mussNeuLaden = true;
          } else {
            final localFile = File(artikel.bildPfad);
            
            if (!localFile.existsSync() || localFile.lengthSync() == 0) {
              mussNeuLaden = true;
            } else {
              // 1. Check: Hat sich der Dateiname in PocketBase geändert?
              // (PocketBase hängt oft Zufallschars an, wenn man ein Bild ersetzt)
              if (!artikel.bildPfad.endsWith(remoteBild)) {
                mussNeuLaden = true;
                _logger.d('Bild-Dateiname hat sich geändert für ${artikel.uuid}. Lade neu.');
              } 
              
              // 2. Check: Ist der Artikel in der DB neuer als das Dateidatum auf dem Handy?
              // Wir geben 2 Sekunden Puffer für Dateisystem-Ungenauigkeiten.
              final lastModified = localFile.lastModifiedSync();
              if (artikel.aktualisiertAm.isAfter(lastModified.add(const Duration(seconds: 2)))) {
                mussNeuLaden = true;
                _logger.d('Bild in PocketBase ist neuer als lokale Datei für ${artikel.uuid}. Lade neu.');
              }
            }
          }

          if (!mussNeuLaden) {
            skipped++;
            continue;
          }
          // --- VERBESSERTE LOGIK ENDE ---

          final imageUrl = _buildImageUrl(recordId, remoteBild);
          if (imageUrl == null) {
            skipped++;
            continue;
          }

          final response = await http
              .get(Uri.parse(imageUrl), headers: _buildAuthHeaders())
              .timeout(AppConfig.networkTimeout);

          if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
            failed++;
            continue;
          }

          final cacheDir = await getApplicationCacheDirectory();
          final imageDir = Directory('${cacheDir.path}/images/${artikel.uuid}');
          if (!imageDir.existsSync()) imageDir.createSync(recursive: true);

          // Alte Dateien im Ordner löschen, bevor wir die neue schreiben
          // (Verhindert Datenmüll bei Namensänderungen)
          if (imageDir.existsSync()) {
            imageDir.listSync().forEach((file) {
              if (file is File) file.deleteSync();
            });
          }

          final localPath = '${imageDir.path}/$remoteBild';
          await File(localPath).writeAsBytes(response.bodyBytes);
          await _db.setBildPfadByUuidSilent(artikel.uuid, localPath);

          downloaded++;
        } catch (e) {
          failed++;
          _logger.w('Image download failed for ${artikel.uuid}: $e');
        }
      }
      _logger.i(
          'PocketBaseSync: downloadMissingImages end (downloaded: $downloaded, skipped: $skipped, failed: $failed)',);
    } catch (e) {
      _logger.e('PocketBaseSync: downloadMissingImages failed: $e');
    }
  }

  // ✅ Single, correct implementation — builds URL directly from base URL string
  String? _buildImageUrl(String recordId, String filename) {
    try {
      if (!_pbService.hasClient || _pbService.url.isEmpty) return null;
      return Uri.parse(_pbService.url)
          .resolve(
              '/api/files/$collectionName/$recordId/${Uri.encodeComponent(filename)}',)
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
      if (token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  String _safeGet(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return '';
    return value.toString();
  }
}