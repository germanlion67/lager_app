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

  Future<void> markSynced(
    String uuid,
    String etag, {
    String? remotePath,
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
}