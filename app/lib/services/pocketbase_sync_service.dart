// lib/services/pocketbase_sync_service.dart

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';

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

          // FIX Finding 1: PocketBase-Record-ID in remote_path,
          // vorhandenen Nextcloud-ETag in etag-Spalte NICHT überschreiben.
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

          // FIX Finding 1: PocketBase-Record-ID in remote_path,
          // vorhandenen Nextcloud-ETag in etag-Spalte NICHT überschreiben.
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
        // markSynced() wird NICHT aufgerufen → Artikel bleibt pending
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

      // FIX Finding 4: Remote-UUIDs sammeln für Abgleich mit lokalen Artikeln
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

          // FIX Finding 1: PocketBase 'updated'-Timestamp als ETag —
          // deterministisch, ändert sich bei jeder PB-Änderung,
          // kollidiert NICHT mit Nextcloud-WebDAV-ETags.
          final etag = updatedRaw.isNotEmpty ? updatedRaw : r.id;

          // FIX Finding 2: Nur upsertArtikel() — markSynced() danach
          // ist redundant und überschreibt den ETag mit der Record-ID.
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

      // FIX Finding 4: Lokal vorhandene Artikel, die remote fehlen,
      // als gelöscht markieren (Soft-Delete für Sync-Konsistenz).
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
        // Sicherheitsnetz: Wenn remoteUuids leer ist, war der Pull
        // möglicherweise fehlgeschlagen — kein Massen-Soft-Delete.
        _logger.w(
          'PocketBaseSync: remoteUuids ist leer — '
          'lokale Lösch-Synchronisation übersprungen.',
        );
      }
    } catch (e, st) {
      _logger.e('PocketBase pull failed', error: e, stackTrace: st);
    }
  }

  /// Sicherer Zugriff auf PocketBase-Felder ohne Exception-Risiko.
  /// Gibt leeren String zurück wenn Feld fehlt oder kein String ist.
  String _safeGet(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}