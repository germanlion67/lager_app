// lib/services/pocketbase_sync_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';
import 'pocketbase_service.dart';
import 'artikel_db_service.dart';
import '../models/artikel_model.dart';

/// Simple PocketBase sync implementation (push local changes, then pull remote).
///
/// ⚠️ NUR für Mobile/Desktop – im Web wird PocketBase direkt verwendet,
/// es gibt keine lokale DB und keinen Sync.
///
/// Uses `PocketBaseService().client` for API access and `ArtikelDbService` for local DB.
class PocketBaseSyncService {
  final String collectionName;
  final Logger _logger = Logger();

  PocketBaseSyncService(this.collectionName);

  /// Führt einen kompletten Sync-Zyklus durch: Push → Pull.
  /// Wird im Web sofort abgebrochen (no-op).
  Future<void> syncOnce() async {
    // Web hat keine lokale DB → kein Sync nötig
    if (kIsWeb) {
      _logger.d('PocketBaseSync: Skipping sync on Web platform');
      return;
    }

    _logger.i('PocketBaseSync: syncOnce start (collection=$collectionName)');
    final db = ArtikelDbService();
    try {
      await _pushToPocketBase(db);
      await _pullFromPocketBase(db);
      // Letzten Sync-Zeitpunkt speichern
      await db.setLastSyncTime();
      _logger.i('PocketBaseSync: syncOnce end (success)');
    } catch (e, st) {
      _logger.e('PocketBaseSync: syncOnce failed: $e\n$st');
    }
  }

  /// Lokale Änderungen → PocketBase hochladen
  Future<void> _pushToPocketBase(ArtikelDbService db) async {
    final pending = await db.getPendingChanges();
    _logger.i('PocketBaseSync: pushing ${pending.length} pending changes');

    for (final artikel in pending) {
      try {
        final filter = 'uuid = "${artikel.uuid}"';
        _logger.d(
            'PocketBaseSync: searching for remote record with filter: $filter');

        final list = await PocketBaseService()
            .client
            .collection(collectionName)
            .getList(filter: filter);

        if (list.items.isNotEmpty) {
          // Update: Remote-Record existiert bereits
          final recId = list.items.first.id;
          final updated = await PocketBaseService()
              .client
              .collection(collectionName)
              .update(recId, body: artikel.toPocketBaseMap());

          await db.markSynced(artikel.uuid, updated.id);
          _logger.d(
              'Updated PocketBase record ${updated.id} for uuid ${artikel.uuid}');
        } else {
          // Create: Neuer Remote-Record
          final created = await PocketBaseService()
              .client
              .collection(collectionName)
              .create(body: artikel.toMap());

          await db.markSynced(artikel.uuid, created.id);
          _logger.d(
              'Created PocketBase record ${created.id} for uuid ${artikel.uuid}');
        }
      } catch (e, st) {
        _logger.e(
            'PocketBase push failed for uuid=${artikel.uuid}: $e\n$st');
      }
    }
    _logger.i('PocketBaseSync: push phase completed');
  }

  /// Remote-Records → Lokale DB herunterladen
  Future<void> _pullFromPocketBase(ArtikelDbService db) async {
    _logger.i('PocketBaseSync: pulling remote records');

    try {
      final records = await PocketBaseService()
          .client
          .collection(collectionName)
          .getFullList();
      _logger.i('PocketBaseSync: fetched ${records.length} remote records');

      for (final r in records) {
        try {
          final Map<String, dynamic> data =
              Map<String, dynamic>.from(r.data);

          // UUID sicherstellen
          if (!data.containsKey('uuid') || data['uuid'] == null) {
            data['uuid'] = r.id;
          }

          // Remote-Pfad und ETag für Upsert-Logik
          final remotePath = '${r.id}.json';
          final etag =
              (r.updated != null) ? r.updated.toString() : r.id;
          final jsonBody = jsonEncode({...data, 'id': r.id});

          await db.upsertFromRemote(remotePath, etag, jsonBody);
          await db.markSynced(data['uuid'].toString(), r.id);
        } catch (e, st) {
          _logger.e('Failed to upsert remote record ${r.id}: $e\n$st');
        }
      }
    } catch (e, st) {
      _logger.e('PocketBase pull failed: $e\n$st');
    }
  }
}
