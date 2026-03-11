// lib/services/pocketbase_sync_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';

import '../models/artikel_model.dart';
import 'pocketbase_service.dart';
import 'artikel_db_service.dart';

class PocketBaseSyncService {
  final String collectionName;

  // ✅ Fix Bug 1 + 3: Beide Services injiziert – keine neuen Instanzen pro Call
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
      // ✅ Fix Bug 4: named params statt manueller String-Formatierung
      _logger.e('PocketBaseSync: syncOnce failed', error: e, stackTrace: st);
    }
  }

  /// Lokale Änderungen → PocketBase hochladen
  Future<void> _pushToPocketBase() async {
    final pending = await _db.getPendingChanges();
    _logger.i('PocketBaseSync: pushing ${pending.length} pending changes');

    for (final artikel in pending) {
      try {
        final filter = 'uuid = "${artikel.uuid}"';
        _logger.d('PocketBaseSync: searching for remote record: $filter');

        // ✅ Fix Bug 1: _pbService statt PocketBaseService()
        final list = await _pbService.client
            .collection(collectionName)
            .getList(filter: filter);

        if (list.items.isNotEmpty) {
          final recId = list.items.first.id;
          final updated = await _pbService.client
              .collection(collectionName)
              .update(recId, body: artikel.toPocketBaseMap());

          await _db.markSynced(artikel.uuid, updated.id);
          _logger.d('Updated PB record ${updated.id} for uuid ${artikel.uuid}');
        } else {
          final created = await _pbService.client
              .collection(collectionName)
              .create(body: artikel.toPocketBaseMap());

          await _db.markSynced(artikel.uuid, created.id);
          _logger.d('Created PB record ${created.id} for uuid ${artikel.uuid}');
        }
      } catch (e, st) {
        _logger.e(
          'PocketBase push failed for uuid=${artikel.uuid}',
          error: e,
          stackTrace: st,
        );
        _logger.w('Artikel ${artikel.uuid} bleibt pending für nächsten Sync');
        // ✅ markSynced() wird NICHT aufgerufen → Artikel bleibt pending
      }
    }
    _logger.i('PocketBaseSync: push phase completed');
  }

  /// Remote-Records → Lokale DB herunterladen
  Future<void> _pullFromPocketBase() async {
    _logger.i('PocketBaseSync: pulling remote records');

    try {
      // ✅ Fix Bug 1: _pbService statt PocketBaseService()
      final records = await _pbService.client
          .collection(collectionName)
          .getFullList();
      _logger.i('PocketBaseSync: fetched ${records.length} remote records');

      for (final r in records) {
        try {
          // ✅ Fix Bug 2: created/updated korrekt übergeben
          final artikel = Artikel.fromPocketBase(
            Map<String, dynamic>.from(r.data),
            r.id,
            created: r.get<String>('created'),
            updated: r.get<String>('updated'),
          );

          final etag = r.get<String>('updated').isNotEmpty
              ? r.get<String>('updated')
              : r.id;

          await _db.upsertArtikel(artikel, etag: etag);
          await _db.markSynced(artikel.uuid, r.id);
          _logger.d('Upserted local record for uuid ${artikel.uuid}');
        } catch (e, st) {
          _logger.e(
            'Failed to upsert remote record ${r.id}',
            error: e,
            stackTrace: st,
          );
        }
      }
    } catch (e, st) {
      _logger.e('PocketBase pull failed', error: e, stackTrace: st);
    }
  }
}