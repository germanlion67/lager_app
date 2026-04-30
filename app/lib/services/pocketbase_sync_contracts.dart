//lib/services/pocketbase_sync_contracts.dart

import 'package:pocketbase/pocketbase.dart';

import '../models/artikel_model.dart';

abstract class SyncPocketBaseService {
  PocketBase get client;
  bool get isAuthenticated;
  String? get currentUserId;
  bool get hasClient;
  String get url;
}

abstract class SyncArtikelDbService {
  Future<List<Artikel>> getPendingChanges();

  /// Löscht bildPfad und remoteBildPfad ohne Dirty-Flag.
  Future<void> clearBildInfoByUuidSilent(String uuid);

  Future<void> markSynced(
    String uuid,
    String etag, {
    String? remotePath,
    String? remoteBildPfad,   // ➊ NEU – optional
  });

  Future<Artikel?> getArtikelByUUID(String uuid);

  Future<void> upsertArtikel(Artikel artikel, {String? etag});

  Future<List<Artikel>> getAlleArtikel({
    int limit = 500,
    int offset = 0,
  });

  Future<void> deleteArtikel(Artikel artikel);

  Future<void> setBildPfadByUuidSilent(String uuid, String bildPfad);

  Future<void> setLastSyncTime();

  Future<void> saveRemoteConflictSnapshot({
  required String uuid,
  required Artikel remoteArtikel,
  });

  Future<Artikel?> loadRemoteConflictSnapshot(String uuid);

}