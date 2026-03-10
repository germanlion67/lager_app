//lib/services/pocketbase_sync_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'pocketbase_service.dart';
import 'artikel_db_service.backup';
import '../models/artikel_model.dart';

/// Simple PocketBase sync implementation (push local changes, then pull remote).
/// Uses `PocketBaseService.client` for API access and `ArtikelDbService` for local DB.
class PocketBaseSyncService {
  final String collectionName;
  final Logger _logger = Logger();

  PocketBaseSyncService(this.collectionName);

  Future<void> syncOnce() async {
    _logger.i('PocketBaseSync: syncOnce start (collection=$collectionName)');
    final db = ArtikelDbService();
    try {
      await _pushToPocketBase();
      await _pullFromPocketBase();
      // mark last sync time
      await db.setLastSyncTime();
      _logger.i('PocketBaseSync: syncOnce end (success)');
    } catch (e, st) {
      _logger.e('PocketBaseSync: syncOnce failed: $e\n$st');
    }
  }

  Future<void> _pushToPocketBase() async {
    final db = ArtikelDbService();
    final pending = await db.getPendingChanges();
    _logger.i('PocketBaseSync: pushing ${pending.length} pending changes');

    for (final artikel in pending) {
      try {
        // find existing record by uuid
        final filter = 'uuid = "${artikel.uuid}"';
        _logger.d('PocketBaseSync: searching for remote record with filter: $filter');
        final list = await PocketBaseService().client.collection(collectionName).getList(filter: filter);
        if (list.items.isNotEmpty) {
          final recId = list.items.first.id;
          final updated = await PocketBaseService().client.collection(collectionName).update(
            recId,
            body: artikel.toMap(),
          );
          // mark local as synced - use PocketBase record id as etag token
          await db.markSynced(artikel.uuid, updated.id);
          _logger.d('Updated PocketBase record ${updated.id} for uuid ${artikel.uuid}');
        } else {
          final created = await PocketBaseService().client.collection(collectionName).create(
            body: artikel.toMap(),
          );
          await db.markSynced(artikel.uuid, created.id);
          _logger.d('Created PocketBase record ${created.id} for uuid ${artikel.uuid}');
        }
      } catch (e, st) {
        _logger.e('PocketBase push failed for uuid=${artikel.uuid}: $e\n$st');
      }
    }
    _logger.i('PocketBaseSync: push phase completed');
  }

  Future<void> _pullFromPocketBase() async {
    final db = ArtikelDbService();
    _logger.i('PocketBaseSync: pulling remote records');

    try {
      final records = await PocketBaseService().client.collection(collectionName).getFullList();
      _logger.i('PocketBaseSync: fetched ${records.length} remote records');

      for (final r in records) {
        try {
          // build a JSON body comparable to Nextcloud payload for upsertFromRemote
          final Map<String, dynamic> data = Map<String, dynamic>.from(r.data);
          // ensure uuid exists in payload
          if (!data.containsKey('uuid')) data['uuid'] = data['uuid'] ?? data['id'] ?? r.id;
          // use record id as remote path and updated timestamp (if available) as etag
          final remotePath = '${r.id}.json';
          final etag = (r.updated != null) ? r.updated.toString() : r.id;
          final jsonBody = jsonEncode({...data, 'id': r.id});

          await db.upsertFromRemote(remotePath, etag, jsonBody);
          // mark as synced
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
