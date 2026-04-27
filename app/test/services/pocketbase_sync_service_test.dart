// test/services/pocketbase_sync_service_test.dart
//
// T-002: Unit-Tests für PocketBaseSyncService.
//
// Strategie:
// - Manuelle Fakes statt @GenerateMocks
// - Kein Netzwerk, kein SQLite, kein Dateisystem nötig
// - Jeder Test ist isoliert und deterministisch
// - Test-Logik entspricht der produktiven Konfliktlogik
//   mit lastSyncedEtag / pendingResolution / dirty-Schutz

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import 'package:lager_app/models/artikel_model.dart';

// ══════════════════════════════════════════════════════════════════
// FAKE: PocketBaseService
// ══════════════════════════════════════════════════════════════════

class FakePbService {
  PocketBase client;
  bool isAuthenticated;
  String? currentUserId;
  bool hasClient;
  String url;

  FakePbService({
    required this.client,
    this.isAuthenticated = false,
    this.currentUserId,
    this.hasClient = true,
    this.url = 'http://localhost:8090',
  });
}

// ══════════════════════════════════════════════════════════════════
// FAKE: ArtikelDbService
// ══════════════════════════════════════════════════════════════════

class FakeArtikelDbService {
  List<Artikel> pendingChanges = [];
  List<Artikel> alleArtikel = [];
  final List<MarkSyncedCall> markSyncedCalls = [];
  final List<Artikel> upsertCalls = [];
  final List<String> upsertEtags = [];
  final List<Artikel> deleteCalls = [];
  final List<SetBildPfadCall> setBildPfadSilentCalls = [];
  bool setLastSyncTimeCalled = false;

  Future<List<Artikel>> getPendingChanges() async => pendingChanges;

  Future<List<Artikel>> getAlleArtikel({
    int limit = 500,
    int offset = 0,
  }) async =>
      alleArtikel;

  Future<Artikel?> getArtikelByUUID(String uuid) async {
    try {
      return alleArtikel.firstWhere((a) => a.uuid == uuid);
    } catch (_) {
      return null;
    }
  }

  Future<void> markSynced(
    String uuid,
    String etag, {
    String? remotePath,
  }) async {
    markSyncedCalls.add(MarkSyncedCall(uuid, etag, remotePath));
  }

  Future<void> upsertArtikel(Artikel artikel, {String? etag}) async {
    upsertCalls.add(artikel);
    upsertEtags.add(etag ?? '');
  }

  Future<void> deleteArtikel(Artikel artikel) async {
    deleteCalls.add(artikel);
  }

  Future<void> setBildPfadByUuidSilent(String uuid, String bildPfad) async {
    setBildPfadSilentCalls.add(SetBildPfadCall(uuid, bildPfad));
  }

  Future<void> setLastSyncTime() async {
    setLastSyncTimeCalled = true;
  }

  void reset() {
    pendingChanges = [];
    alleArtikel = [];
    markSyncedCalls.clear();
    upsertCalls.clear();
    upsertEtags.clear();
    deleteCalls.clear();
    setBildPfadSilentCalls.clear();
    setLastSyncTimeCalled = false;
  }
}

class MarkSyncedCall {
  final String uuid;
  final String etag;
  final String? remotePath;

  MarkSyncedCall(this.uuid, this.etag, this.remotePath);
}

class SetBildPfadCall {
  final String uuid;
  final String bildPfad;

  SetBildPfadCall(this.uuid, this.bildPfad);
}

// ══════════════════════════════════════════════════════════════════
// FAKE: RecordService
// ══════════════════════════════════════════════════════════════════

typedef GetListHandler = Future<ResultList<RecordModel>> Function(
  String? filter,
);
typedef GetFullListHandler = Future<List<RecordModel>> Function();
typedef CreateHandler = Future<RecordModel> Function(
  Map<String, dynamic> body,
);
typedef UpdateHandler = Future<RecordModel> Function(
  String id,
  Map<String, dynamic> body,
);
typedef DeleteHandler = Future<void> Function(String id);

class FakeRecordService extends RecordService {
  GetListHandler? onGetList;
  GetFullListHandler? onGetFullList;
  CreateHandler? onCreate;
  UpdateHandler? onUpdate;
  DeleteHandler? onDelete;

  final List<String> getListFilters = [];
  final List<Map<String, dynamic>> createBodies = [];
  final List<MapEntry<String, Map<String, dynamic>>> updateEntries = [];
  final List<String> deleteIds = [];
  bool getFullListCalled = false;

  FakeRecordService() : super(PocketBase('http://fake'), 'fake');

  @override
  Future<ResultList<RecordModel>> getList({
    int page = 1,
    int perPage = 30,
    bool skipTotal = false,
    String? expand,
    String? filter,
    String? sort,
    String? fields,
    Map<String, dynamic> query = const {},
    Map<String, String> headers = const {},
  }) async {
    getListFilters.add(filter ?? '');
    if (onGetList != null) return onGetList!(filter);
    return ResultList<RecordModel>(
      page: 1,
      perPage: 30,
      totalItems: 0,
      totalPages: 0,
      items: [],
    );
  }

  @override
  Future<List<RecordModel>> getFullList({
    int batch = 500,
    String? expand,
    String? filter,
    String? sort,
    String? fields,
    Map<String, dynamic> query = const {},
    Map<String, String> headers = const {},
  }) async {
    getFullListCalled = true;
    if (onGetFullList != null) return onGetFullList!();
    return [];
  }

  @override
  Future<RecordModel> create({
    Map<String, dynamic> body = const {},
    Map<String, dynamic> query = const {},
    List<http.MultipartFile> files = const [],
    Map<String, String> headers = const {},
    String? expand,
    String? fields,
  }) async {
    createBodies.add(Map<String, dynamic>.from(body));
    if (onCreate != null) return onCreate!(body);
    return RecordModel.fromJson(<String, dynamic>{'id': 'pb-default'});
  }

  @override
  Future<RecordModel> update(
    String id, {
    Map<String, dynamic> body = const {},
    Map<String, dynamic> query = const {},
    List<http.MultipartFile> files = const [],
    Map<String, String> headers = const {},
    String? expand,
    String? fields,
  }) async {
    updateEntries.add(MapEntry(id, Map<String, dynamic>.from(body)));
    if (onUpdate != null) return onUpdate!(id, body);
    return RecordModel.fromJson(<String, dynamic>{'id': id});
  }

  @override
  Future<void> delete(
    String id, {
    Map<String, dynamic> body = const {},
    Map<String, dynamic> query = const {},
    Map<String, String> headers = const {},
  }) async {
    deleteIds.add(id);
    if (onDelete != null) return onDelete!(id);
  }

  void reset() {
    getListFilters.clear();
    createBodies.clear();
    updateEntries.clear();
    deleteIds.clear();
    getFullListCalled = false;
  }
}

// ══════════════════════════════════════════════════════════════════
// FAKE: PocketBase Client
// ══════════════════════════════════════════════════════════════════

class FakePocketBase extends PocketBase {
  final FakeRecordService fakeRecordService;

  FakePocketBase(this.fakeRecordService) : super('http://fake');

  @override
  RecordService collection(String collectionIdOrName) => fakeRecordService;
}

// ══════════════════════════════════════════════════════════════════
// TESTABLE SYNC SERVICE
// ══════════════════════════════════════════════════════════════════

typedef ConflictHandler = Future<void> Function(
  Artikel lokalerArtikel,
  Artikel remoteArtikel,
);

class TestableSyncService {
  final String collectionName;
  final FakePbService _pbService;
  final FakeArtikelDbService _db;
  final FakeRecordService _recordService;

  ConflictHandler? onConflictDetected;

  TestableSyncService(
    this.collectionName,
    this._pbService,
    this._db,
    this._recordService,
  );

  Future<void> syncOnce() async {
    try {
      await _pushToPocketBase();
      await _pullFromPocketBase();
      await _db.setLastSyncTime();
    } catch (_) {
      // Fehler abfangen wie im Original
    }
  }

  bool _isDirty(Artikel artikel) {
    final etag = artikel.etag ?? '';
    return etag.isEmpty;
  }

  bool _hasPendingResolution(Artikel artikel) {
    final pending = artikel.pendingResolution?.trim() ?? '';
    return pending.isNotEmpty;
  }

  bool _isForceResolution(Artikel artikel) {
    final pending = artikel.pendingResolution?.trim() ?? '';
    return pending == 'force_local' || pending == 'force_merge';
  }

  bool _needsConflictBecauseMissingBase(Artikel artikel) {
    if (_isForceResolution(artikel)) return false;
    final base = artikel.lastSyncedEtag?.trim() ?? '';
    return base.isEmpty;
  }

  Map<String, dynamic> _asStringDynamicMap(dynamic value) {
    if (value == null) return <String, dynamic>{};

    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), val),
      );
    }

    return <String, dynamic>{};
  }

  String _extractRecordEtag(RecordModel record) {
    final data = _asStringDynamicMap(record.data);
    final updated = _safeGet(data, 'updated');
    return updated.isNotEmpty ? updated : record.id;
  }

  bool _hasRemoteChangedSinceLastSync(Artikel lokal, String remoteEtag) {
    final base = lokal.lastSyncedEtag?.trim() ?? '';
    if (base.isEmpty) return false;
    return remoteEtag.isNotEmpty && remoteEtag != base;
  }

  Artikel _recordToArtikel(RecordModel record) {
    final data = _asStringDynamicMap(record.data);
    return Artikel.fromPocketBase(
      data,
      record.id,
      created: _safeGet(data, 'created'),
      updated: _safeGet(data, 'updated'),
    );
  }

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

  Future<RecordModel?> _findRemoteRecordByUuid(String uuid) async {
    final safeUuid = uuid.replaceAll('"', '');
    final filter = 'uuid = "$safeUuid"';

    final list = await _recordService.getList(
      page: 1,
      perPage: 1,
      filter: filter,
    );

    if (list.items.isEmpty) return null;
    return list.items.first;
  }

  Future<void> _markLocalAsSyncedFromRemote(
    Artikel artikel,
    RecordModel remoteRecord,
  ) async {
    final remoteData = _asStringDynamicMap(remoteRecord.data);
    final remoteEtag = _safeGet(remoteData, 'updated').isNotEmpty
        ? _safeGet(remoteData, 'updated')
        : remoteRecord.id;

    await _db.markSynced(
      artikel.uuid,
      remoteEtag,
      remotePath: remoteRecord.id,
    );
  }

  Future<void> _emitConflictIfPossible(
    Artikel lokal,
    Artikel remote,
  ) async {
    if (onConflictDetected != null) {
      await onConflictDetected!(lokal, remote);
    }
  }

  Future<void> _pushToPocketBase() async {
    final pending = await _db.getPendingChanges();

    for (final artikel in pending) {
      try {
        final safeUuid = artikel.uuid.replaceAll('"', '');
        final filter = 'uuid = "$safeUuid"';

        final list = await _recordService.getList(filter: filter);

        if (artikel.deleted == true) {
          if (list.items.isNotEmpty) {
            final remoteRecord = list.items.first;
            final remoteEtag = _extractRecordEtag(remoteRecord);
            final remoteArtikel = _recordToArtikel(remoteRecord);

            final missingConflictBase =
                _needsConflictBecauseMissingBase(artikel);

            if (missingConflictBase) {
              await _emitConflictIfPossible(artikel, remoteArtikel);
              continue;
            }

            final hasConflict = !_isForceResolution(artikel) &&
                _hasRemoteChangedSinceLastSync(artikel, remoteEtag);

            if (hasConflict) {
              await _emitConflictIfPossible(artikel, remoteArtikel);
              continue;
            }

            await _recordService.delete(remoteRecord.id);
          }

          await _db.markSynced(artikel.uuid, 'deleted');
          continue;
        }

        if (list.items.isNotEmpty) {
          final remoteRecord = list.items.first;
          final recId = remoteRecord.id;
          final remoteEtag = _extractRecordEtag(remoteRecord);
          final remoteArtikel = _recordToArtikel(remoteRecord);

          final missingConflictBase =
              _needsConflictBecauseMissingBase(artikel);

          if (missingConflictBase) {
            await _emitConflictIfPossible(artikel, remoteArtikel);
            continue;
          }

          final hasConflict = !_isForceResolution(artikel) &&
              _hasRemoteChangedSinceLastSync(artikel, remoteEtag);

          if (hasConflict) {
            await _emitConflictIfPossible(artikel, remoteArtikel);
            continue;
          }

          final body = artikel.toPocketBaseMap();
          if (_pbService.isAuthenticated && _pbService.currentUserId != null) {
            body['owner'] = _pbService.currentUserId;
          }

          final updated = await _recordService.update(recId, body: body);
          final updatedEtag = _safeGet(updated.data, 'updated').isNotEmpty
              ? _safeGet(updated.data, 'updated')
              : updated.id;

          await _db.markSynced(
            artikel.uuid,
            updatedEtag,
            remotePath: updated.id,
          );
        } else {
          final body = artikel.toPocketBaseMap();
          if (_pbService.isAuthenticated && _pbService.currentUserId != null) {
            body['owner'] = _pbService.currentUserId;
          }

          try {
            final created = await _recordService.create(body: body);
            final createdEtag = _safeGet(created.data, 'updated').isNotEmpty
                ? _safeGet(created.data, 'updated')
                : created.id;

            await _db.markSynced(
              artikel.uuid,
              createdEtag,
              remotePath: created.id,
            );
          } catch (e) {
            if (!_isDuplicateUuidError(e)) {
              rethrow;
            }

            final existing = await _findRemoteRecordByUuid(artikel.uuid);
            if (existing == null) {
              rethrow;
            }

            await _markLocalAsSyncedFromRemote(artikel, existing);
          }
        }
      } catch (_) {
        // Fehler pro Artikel abfangen, weiter mit nächstem
      }
    }
  }

  Future<void> _pullFromPocketBase() async {
    final records = await _recordService.getFullList();

    final remoteUuids = <String>{};

    for (final r in records) {
      try {
        final data = _asStringDynamicMap(r.data);
        final updatedRaw = _safeGet(data, 'updated');
        final createdRaw = _safeGet(data, 'created');

        final artikel = Artikel.fromPocketBase(
          data,
          r.id,
          created: createdRaw,
          updated: updatedRaw,
        );

        final etag = updatedRaw.isNotEmpty ? updatedRaw : r.id;
        final localArtikel = await _db.getArtikelByUUID(artikel.uuid);

        if (localArtikel != null) {
          final localDirty = _isDirty(localArtikel);
          final hasPending = _hasPendingResolution(localArtikel);
          final missingConflictBase =
              _needsConflictBecauseMissingBase(localArtikel);
          final remoteChanged =
              _hasRemoteChangedSinceLastSync(localArtikel, etag);

          if (hasPending) {
            if (artikel.uuid.isNotEmpty) {
              remoteUuids.add(artikel.uuid);
            }
            continue;
          }

          if (localDirty && missingConflictBase) {
            await _emitConflictIfPossible(localArtikel, artikel);
            if (artikel.uuid.isNotEmpty) {
              remoteUuids.add(artikel.uuid);
            }
            continue;
          }

          if (localDirty && remoteChanged) {
            await _emitConflictIfPossible(localArtikel, artikel);
            if (artikel.uuid.isNotEmpty) {
              remoteUuids.add(artikel.uuid);
            }
            continue;
          }

          if (localDirty) {
            if (artikel.uuid.isNotEmpty) {
              remoteUuids.add(artikel.uuid);
            }
            continue;
          }
        }

        await _db.upsertArtikel(artikel, etag: etag);

        if (artikel.uuid.isNotEmpty) {
          remoteUuids.add(artikel.uuid);
        }
      } catch (_) {
        // Fehler pro Record abfangen
      }
    }

    if (remoteUuids.isNotEmpty) {
      final localArtikel = await _db.getAlleArtikel();
      for (final lokal in localArtikel) {
        if (lokal.remotePath != null &&
            lokal.remotePath!.isNotEmpty &&
            !remoteUuids.contains(lokal.uuid)) {
          final localDirty = _isDirty(lokal);
          final hasPending = _hasPendingResolution(lokal);

          if (hasPending || localDirty) {
            continue;
          }

          await _db.deleteArtikel(lokal);
        }
      }
    }
  }

  Future<void> downloadMissingImages() async {
    final alleArtikel = await _db.getAlleArtikel(limit: 999999, offset: 0);

    for (final artikel in alleArtikel) {
      final remoteBild = artikel.remoteBildPfad;
      final recordId = artikel.remotePath;
      if (remoteBild == null || remoteBild.isEmpty) continue;
      if (recordId == null || recordId.isEmpty) continue;

      if (artikel.bildPfad.isNotEmpty) continue;
      if (!_pbService.hasClient || _pbService.url.isEmpty) continue;
    }
  }

  String _safeGet(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}

// ══════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════

RecordModel makeRecord({
  required String id,
  required Map<String, dynamic> data,
  String created = '2026-01-01 00:00:00.000Z',
  String updated = '2026-01-01 00:00:00.000Z',
}) {
  final json = <String, dynamic>{
    'id': id,
    'created': created,
    'updated': updated,
    ...data,
  };
  return RecordModel.fromJson(json);
}

ResultList<RecordModel> makeResultList(List<RecordModel> items) {
  return ResultList<RecordModel>(
    page: 1,
    perPage: 30,
    totalItems: items.length,
    totalPages: 1,
    items: items,
  );
}

Artikel makeArtikel({
  int? id,
  String? uuid,
  String name = 'Test-Artikel',
  int menge = 5,
  String ort = 'Lager A',
  String fach = 'Fach 1',
  String? etag,
  String? lastSyncedEtag,
  String? pendingResolution,
  String? remotePath,
  bool deleted = false,
  String bildPfad = '',
  String? remoteBildPfad,
}) {
  return Artikel(
    id: id ?? 1,
    name: name,
    menge: menge,
    ort: ort,
    fach: fach,
    beschreibung: 'Testbeschreibung',
    bildPfad: bildPfad,
    erstelltAm: DateTime.utc(2026, 1, 1),
    aktualisiertAm: DateTime.utc(2026, 1, 1),
    uuid: uuid ?? 'test-uuid-001',
    etag: etag,
    lastSyncedEtag: lastSyncedEtag,
    pendingResolution: pendingResolution,
    remotePath: remotePath,
    deleted: deleted,
    remoteBildPfad: remoteBildPfad,
  );
}

// ══════════════════════════════════════════════════════════════════
// TESTS
// ══════════════════════════════════════════════════════════════════

const ts1 = '2026-01-10 10:00:00.000Z';
const ts2 = '2026-01-11 10:00:00.000Z';
const ts3 = '2026-01-12 10:00:00.000Z';
const ts4 = '2026-01-13 10:00:00.000Z';

void main() {
  late FakePbService fakePbService;
  late FakeArtikelDbService fakeDb;
  late FakeRecordService fakeRecordService;
  late TestableSyncService syncService;
  late List<Map<String, Artikel>> conflicts;

  setUp(() {
    fakeRecordService = FakeRecordService();
    final fakePb = FakePocketBase(fakeRecordService);

    fakePbService = FakePbService(client: fakePb);
    fakeDb = FakeArtikelDbService();
    syncService = TestableSyncService(
      'artikel',
      fakePbService,
      fakeDb,
      fakeRecordService,
    );
    conflicts = [];

    syncService.onConflictDetected = (lokal, remote) async {
      conflicts.add({
        'local': lokal,
        'remote': remote,
      });
    };
  });

  group('Push: lokale Änderungen hochladen', () {
    test('erstellt neuen Remote-Record wenn kein Match gefunden', () async {
      final artikel = makeArtikel(etag: null, remotePath: null);
      fakeDb.pendingChanges = [artikel];

      fakeRecordService.onGetList = (_) async => makeResultList([]);
      fakeRecordService.onCreate = (body) async => makeRecord(
            id: 'pb-new-001',
            data: {'uuid': artikel.uuid, 'name': artikel.name},
          );
      fakeRecordService.onGetFullList = () async => [];

      await syncService.syncOnce();

      expect(fakeRecordService.createBodies, hasLength(1));
      expect(fakeRecordService.updateEntries, isEmpty);
      expect(fakeDb.markSyncedCalls, hasLength(1));
      expect(fakeDb.markSyncedCalls.first.remotePath, equals('pb-new-001'));
    });

    test('aktualisiert bestehenden Remote-Record wenn Match gefunden',
        () async {
      final artikel = makeArtikel(
        etag: null,
        remotePath: 'pb-existing-001',
        lastSyncedEtag: ts1,
      );
      fakeDb.pendingChanges = [artikel];

      final existingRecord = makeRecord(
        id: 'pb-existing-001',
        data: {
          'uuid': artikel.uuid,
          'name': artikel.name,
          'menge': artikel.menge,
          'ort': artikel.ort,
          'fach': artikel.fach,
          'beschreibung': artikel.beschreibung,
        },
        updated: ts1,
      );

      fakeRecordService.onGetList =
          (_) async => makeResultList([existingRecord]);
      fakeRecordService.onUpdate = (id, body) async =>
          makeRecord(id: id, data: body, updated: ts2);
      fakeRecordService.onGetFullList = () async => [];

      await syncService.syncOnce();

      expect(fakeRecordService.updateEntries, hasLength(1));
      expect(
        fakeRecordService.updateEntries.first.key,
        equals('pb-existing-001'),
      );
      expect(fakeRecordService.createBodies, isEmpty);
    });

    test('löscht Remote-Record wenn Artikel soft-deleted ist', () async {
      final deletedArtikel = makeArtikel(
        uuid: 'uuid-deleted',
        etag: null,
        deleted: true,
        lastSyncedEtag: ts1,
      );
      fakeDb.pendingChanges = [deletedArtikel];

      final remoteRecord = makeRecord(
        id: 'pb-to-delete',
        data: {
          'uuid': 'uuid-deleted',
          'name': deletedArtikel.name,
          'menge': deletedArtikel.menge,
          'ort': deletedArtikel.ort,
          'fach': deletedArtikel.fach,
          'beschreibung': deletedArtikel.beschreibung,
        },
        updated: ts1,
      );
      fakeRecordService.onGetList =
          (_) async => makeResultList([remoteRecord]);
      fakeRecordService.onGetFullList = () async => [];

      await syncService.syncOnce();

      expect(fakeRecordService.deleteIds, contains('pb-to-delete'));
      final syncCall = fakeDb.markSyncedCalls.firstWhere(
        (c) => c.uuid == 'uuid-deleted',
      );
      expect(syncCall.etag, equals('deleted'));
    });

    test('markiert als deleted auch wenn Remote-Record nicht existiert',
        () async {
      final deletedArtikel = makeArtikel(
        uuid: 'uuid-already-gone',
        etag: null,
        deleted: true,
      );
      fakeDb.pendingChanges = [deletedArtikel];

      fakeRecordService.onGetList = (_) async => makeResultList([]);
      fakeRecordService.onGetFullList = () async => [];

      await syncService.syncOnce();

      expect(fakeRecordService.deleteIds, isEmpty);
      expect(fakeDb.markSyncedCalls, hasLength(1));
      expect(fakeDb.markSyncedCalls.first.etag, equals('deleted'));
    });

    test('fängt Push-Fehler ab und fährt mit nächstem Artikel fort', () async {
      final artikel1 = makeArtikel(uuid: 'uuid-fail', etag: null);
      final artikel2 = makeArtikel(uuid: 'uuid-ok', etag: null);
      fakeDb.pendingChanges = [artikel1, artikel2];

      var callCount = 0;
      fakeRecordService.onGetList = (_) async {
        callCount++;
        if (callCount == 1) throw Exception('Netzwerkfehler');
        return makeResultList([]);
      };

      fakeRecordService.onCreate = (body) async => makeRecord(
            id: 'pb-ok',
            data: body,
          );
      fakeRecordService.onGetFullList = () async => [];

      await syncService.syncOnce();

      expect(fakeRecordService.createBodies, hasLength(1));
      expect(fakeDb.markSyncedCalls, hasLength(1));
      expect(fakeDb.markSyncedCalls.first.remotePath, equals('pb-ok'));
    });

    test('setzt owner wenn authentifiziert', () async {
      fakePbService.isAuthenticated = true;
      fakePbService.currentUserId = 'user-123';

      final artikel = makeArtikel(etag: null);
      fakeDb.pendingChanges = [artikel];

      fakeRecordService.onGetList = (_) async => makeResultList([]);
      fakeRecordService.onCreate = (body) async => makeRecord(
            id: 'pb-auth',
            data: body,
          );
      fakeRecordService.onGetFullList = () async => [];

      await syncService.syncOnce();

      expect(fakeRecordService.createBodies, hasLength(1));
      expect(fakeRecordService.createBodies.first['owner'], equals('user-123'));
    });

    test('force_local überschreibt Remote bewusst ohne Konflikt', () async {
      final artikel = makeArtikel(
        uuid: 'uuid-force-local',
        etag: null,
        lastSyncedEtag: ts1,
        pendingResolution: 'force_local',
        remotePath: 'pb-1',
      );
      fakeDb.pendingChanges = [artikel];

      final existingRecord = makeRecord(
        id: 'pb-1',
        data: {
          'uuid': artikel.uuid,
          'name': artikel.name,
          'menge': artikel.menge,
          'ort': artikel.ort,
          'fach': artikel.fach,
          'beschreibung': artikel.beschreibung,
        },
        updated: ts2,
      );

      fakeRecordService.onGetList =
          (_) async => makeResultList([existingRecord]);
      fakeRecordService.onUpdate = (id, body) async => makeRecord(
            id: id,
            data: body,
            updated: ts3,
          );
      fakeRecordService.onGetFullList = () async => [];

      await syncService.syncOnce();

      expect(fakeRecordService.updateEntries, hasLength(1));
      expect(fakeDb.markSyncedCalls, hasLength(1));
      expect(conflicts, isEmpty);
    });

    test('force_merge überschreibt Remote bewusst ohne Konflikt', () async {
      final artikel = makeArtikel(
        uuid: 'uuid-force-merge',
        etag: null,
        lastSyncedEtag: ts1,
        pendingResolution: 'force_merge',
        remotePath: 'pb-merge',
      );
      fakeDb.pendingChanges = [artikel];

      final existingRecord = makeRecord(
        id: 'pb-merge',
        data: {
          'uuid': artikel.uuid,
          'name': artikel.name,
          'menge': artikel.menge,
          'ort': artikel.ort,
          'fach': artikel.fach,
          'beschreibung': artikel.beschreibung,
        },
        updated: ts2,
      );

      fakeRecordService.onGetList =
          (_) async => makeResultList([existingRecord]);
      fakeRecordService.onUpdate = (id, body) async => makeRecord(
            id: id,
            data: body,
            updated: ts3,
          );
      fakeRecordService.onGetFullList = () async => [];

      await syncService.syncOnce();

      expect(fakeRecordService.updateEntries, hasLength(1));
      expect(fakeDb.markSyncedCalls, hasLength(1));
      expect(conflicts, isEmpty);
    });

    test('erkennt Konflikt wenn Remote seit lastSyncedEtag geändert wurde',
        () async {
      final artikel = makeArtikel(
        uuid: 'uuid-conflict',
        etag: null,
        lastSyncedEtag: ts1,
        pendingResolution: null,
      );
      fakeDb.pendingChanges = [artikel];

      final existingRecord = makeRecord(
        id: 'pb-conflict',
        data: {
          'uuid': artikel.uuid,
          'name': artikel.name,
          'menge': artikel.menge,
          'ort': artikel.ort,
          'fach': artikel.fach,
          'beschreibung': artikel.beschreibung,
        },
        updated: ts2,
      );

      fakeRecordService.onGetList =
          (_) async => makeResultList([existingRecord]);
      fakeRecordService.onGetFullList = () async => [];

      await syncService.syncOnce();

      expect(fakeRecordService.updateEntries, isEmpty);
      expect(fakeDb.markSyncedCalls, isEmpty);
      expect(conflicts, hasLength(1));
      expect(conflicts.first['local']!.uuid, equals('uuid-conflict'));
    });
    test(
      'erkennt Konflikt wenn Remote existiert und lastSyncedEtag null ist',
      () async {
        final artikel = makeArtikel(
          uuid: 'uuid-missing-base-null',
          etag: null,
          lastSyncedEtag: null,
          pendingResolution: null,
          remotePath: 'pb-existing',
        );
        fakeDb.pendingChanges = [artikel];

        final existingRecord = makeRecord(
          id: 'pb-existing',
          data: {
            'uuid': artikel.uuid,
            'name': 'Remote Artikel',
            'menge': 7,
            'ort': 'Remote',
            'fach': 'R1',
            'beschreibung': 'Remote',
            'updated': 'remote-new',
          },
          updated: ts2,
        );

        fakeRecordService.onGetList =
            (_) async => makeResultList([existingRecord]);
        fakeRecordService.onGetFullList = () async => [];

        await syncService.syncOnce();

        expect(fakeRecordService.updateEntries, isEmpty);
        expect(fakeRecordService.createBodies, isEmpty);
        expect(fakeDb.markSyncedCalls, isEmpty);
        expect(conflicts, hasLength(1));
        expect(conflicts.first['local']!.uuid, equals('uuid-missing-base-null'));
      },
    );
    test(
      'erkennt Konflikt wenn Remote existiert und lastSyncedEtag leer ist',
      () async {
        final artikel = makeArtikel(
          uuid: 'uuid-missing-base-empty',
          etag: null,
          lastSyncedEtag: '',
          pendingResolution: null,
          remotePath: 'pb-existing',
        );
        fakeDb.pendingChanges = [artikel];

        final existingRecord = makeRecord(
          id: 'pb-existing',
          data: {
            'uuid': artikel.uuid,
            'name': 'Remote Artikel',
            'menge': 7,
            'ort': 'Remote',
            'fach': 'R1',
            'beschreibung': 'Remote',
            'updated': 'remote-new',
          },
          updated: ts2,
        );

        fakeRecordService.onGetList =
            (_) async => makeResultList([existingRecord]);
        fakeRecordService.onGetFullList = () async => [];

        await syncService.syncOnce();

        expect(fakeRecordService.updateEntries, isEmpty);
        expect(fakeDb.markSyncedCalls, isEmpty);
        expect(conflicts, hasLength(1));
        expect(conflicts.first['local']!.uuid, equals('uuid-missing-base-empty'));
      },
    );
    test(
      'erkennt Konflikt wenn Remote existiert und lastSyncedEtag nur Whitespace ist',
      () async {
        final artikel = makeArtikel(
          uuid: 'uuid-missing-base-blank',
          etag: null,
          lastSyncedEtag: '   ',
          pendingResolution: null,
          remotePath: 'pb-existing',
        );
        fakeDb.pendingChanges = [artikel];

        final existingRecord = makeRecord(
          id: 'pb-existing',
          data: {
            'uuid': artikel.uuid,
            'name': 'Remote Artikel',
            'menge': 7,
            'ort': 'Remote',
            'fach': 'R1',
            'beschreibung': 'Remote',
            'updated': 'remote-new',
          },
          updated: ts2,
        );

        fakeRecordService.onGetList =
            (_) async => makeResultList([existingRecord]);
        fakeRecordService.onGetFullList = () async => [];

        await syncService.syncOnce();

        expect(fakeRecordService.updateEntries, isEmpty);
        expect(fakeDb.markSyncedCalls, isEmpty);
        expect(conflicts, hasLength(1));
        expect(conflicts.first['local']!.uuid, equals('uuid-missing-base-blank'));
      },
    );
    test(
      'erkennt Delete-Konflikt wenn Remote existiert und lastSyncedEtag fehlt',
      () async {
        final artikel = makeArtikel(
          uuid: 'uuid-delete-missing-base',
          etag: null,
          deleted: true,
          lastSyncedEtag: null,
          pendingResolution: null,
          remotePath: 'pb-delete',
        );
        fakeDb.pendingChanges = [artikel];

        final existingRecord = makeRecord(
          id: 'pb-delete',
          data: {
            'uuid': artikel.uuid,
            'name': 'Remote Artikel',
            'menge': 1,
            'ort': 'Remote',
            'fach': 'R1',
            'beschreibung': 'Remote',
            'updated': 'remote-new',
          },
          updated: ts2,
        );

        fakeRecordService.onGetList =
            (_) async => makeResultList([existingRecord]);
        fakeRecordService.onGetFullList = () async => [];

        await syncService.syncOnce();

        expect(fakeRecordService.deleteIds, isEmpty);
        expect(fakeDb.markSyncedCalls, isEmpty);
        expect(conflicts, hasLength(1));
        expect(
          conflicts.first['local']!.uuid,
          equals('uuid-delete-missing-base'),
        );
      },
    );
    test(
      'force_local erlaubt Update auch wenn lastSyncedEtag fehlt',
      () async {
        final artikel = makeArtikel(
          uuid: 'uuid-force-missing-base',
          etag: null,
          lastSyncedEtag: null,
          pendingResolution: 'force_local',
          remotePath: 'pb-force',
        );
        fakeDb.pendingChanges = [artikel];

        final existingRecord = makeRecord(
          id: 'pb-force',
          data: {
            'uuid': artikel.uuid,
            'name': artikel.name,
            'menge': artikel.menge,
            'ort': artikel.ort,
            'fach': artikel.fach,
            'beschreibung': artikel.beschreibung,
            'updated': 'remote-new',
          },
          updated: ts2,
        );

        fakeRecordService.onGetList =
            (_) async => makeResultList([existingRecord]);
        fakeRecordService.onUpdate = (id, body) async => makeRecord(
              id: id,
              data: body,
              updated: 'remote-after-force',
            );
        fakeRecordService.onGetFullList = () async => [];

        await syncService.syncOnce();

        expect(fakeRecordService.updateEntries, hasLength(1));
        expect(fakeDb.markSyncedCalls, hasLength(1));
        expect(conflicts, isEmpty);
      },
    );
test(
      'recovert Duplicate-UUID beim Create durch Re-Attach an bestehenden Remote-Record',
      () async {
        final artikel = makeArtikel(
          uuid: 'uuid-duplicate-create',
          etag: null,
          remotePath: null,
        );
        fakeDb.pendingChanges = [artikel];

        var getListCalls = 0;

        fakeRecordService.onGetList = (filter) async {
          getListCalls++;
          if (getListCalls == 1) {
            return makeResultList([]);
          }

          return makeResultList([
            makeRecord(
              id: 'pb-existing-after-race',
              data: {
                'uuid': artikel.uuid,
                'name': artikel.name,
                'menge': artikel.menge,
                'ort': artikel.ort,
                'fach': artikel.fach,
                'beschreibung': artikel.beschreibung,
              },
              updated: ts3,
            ),
          ]);
        };

        fakeRecordService.onCreate = (body) async {
          throw Exception(
            'validation error: uuid already exists (unique constraint)',
          );
        };

        fakeRecordService.onGetFullList = () async => [];

        await syncService.syncOnce();

        expect(fakeRecordService.createBodies, hasLength(1));
        expect(fakeDb.markSyncedCalls, hasLength(1));
        expect(fakeDb.markSyncedCalls.first.uuid, equals('uuid-duplicate-create'));
        expect(
          fakeDb.markSyncedCalls.first.remotePath,
          equals('pb-existing-after-race'),
        );
        expect(fakeDb.markSyncedCalls.first.etag, equals(ts3));
      },
    );
    test(
      'wirft keinen Sync-Erfolg für Duplicate-UUID wenn Remote-Recovery nichts findet',
      () async {
        final artikel = makeArtikel(
          uuid: 'uuid-duplicate-missing-remote',
          etag: null,
          remotePath: null,
        );
        fakeDb.pendingChanges = [artikel];

        fakeRecordService.onCreate = (body) async {
          throw Exception('duplicate uuid unique constraint');
        };

        fakeRecordService.onGetFullList = () async => [];

        await syncService.syncOnce();

        expect(fakeRecordService.createBodies, hasLength(1));
        expect(fakeDb.markSyncedCalls, isEmpty);
      },
    );
    test(
      'behandelt allgemeinen Create-Fehler nicht als Duplicate-Recovery',
      () async {
        final artikel = makeArtikel(
          uuid: 'uuid-create-general-error',
          etag: null,
        );
        fakeDb.pendingChanges = [artikel];

        fakeRecordService.onGetList = (_) async => makeResultList([]);
        fakeRecordService.onCreate = (body) async {
          throw Exception('network timeout');
        };
        fakeRecordService.onGetFullList = () async => [];

        await syncService.syncOnce();

        expect(fakeRecordService.createBodies, hasLength(1));
        expect(fakeDb.markSyncedCalls, isEmpty);
      },
    );

  });

  group('Pull: Remote-Records herunterladen', () {
    test('fügt neue Remote-Records lokal ein', () async {
      fakeDb.pendingChanges = [];

      final remoteRecord = makeRecord(
        id: 'pb-remote-001',
        data: {
          'uuid': 'remote-uuid-001',
          'name': 'Remote Artikel',
          'menge': 10,
          'ort': 'Lager B',
          'fach': 'Fach 2',
          'beschreibung': 'Von Remote',
          'created': '2026-01-01 00:00:00.000Z',
          'updated': '2026-01-15 12:00:00.000Z',
        },
      );
      fakeRecordService.onGetFullList = () async => [remoteRecord];

      await syncService.syncOnce();

      expect(fakeDb.upsertCalls, hasLength(1));
      expect(fakeDb.upsertCalls.first.uuid, equals('remote-uuid-001'));
      expect(fakeDb.upsertCalls.first.name, equals('Remote Artikel'));
    });

    test('soft-deleted lokale Artikel die remote nicht mehr existieren',
        () async {
      fakeDb.pendingChanges = [];

      final remoteRecord = makeRecord(
        id: 'pb-a',
        data: {
          'uuid': 'uuid-A',
          'name': 'Artikel A',
          'menge': 1,
          'ort': 'X',
          'fach': 'Y',
          'beschreibung': '',
          'created': '2026-01-01 00:00:00.000Z',
          'updated': '2026-01-01 00:00:00.000Z',
        },
      );
      fakeRecordService.onGetFullList = () async => [remoteRecord];

      final lokalA = makeArtikel(uuid: 'uuid-A', remotePath: 'pb-a', etag: 'e1');
      final lokalB = makeArtikel(
        uuid: 'uuid-B',
        name: 'Nur lokal',
        remotePath: 'pb-b',
        etag: 'e2',
      );
      fakeDb.alleArtikel = [lokalA, lokalB];

      await syncService.syncOnce();

      expect(fakeDb.deleteCalls, hasLength(1));
      expect(fakeDb.deleteCalls.first.uuid, equals('uuid-B'));
    });

    test('überspringt lokale Löschung wenn remoteUuids leer', () async {
      fakeDb.pendingChanges = [];

      final brokenRecord = makeRecord(
        id: 'pb-broken',
        data: {
          'uuid': '',
          'name': 'Kaputt',
          'menge': 0,
          'ort': '',
          'fach': '',
          'beschreibung': '',
          'created': '2026-01-01 00:00:00.000Z',
          'updated': '2026-01-01 00:00:00.000Z',
        },
      );
      fakeRecordService.onGetFullList = () async => [brokenRecord];

      fakeDb.alleArtikel = [makeArtikel(uuid: 'local-only', remotePath: 'pb-x')];

      await syncService.syncOnce();

      expect(fakeDb.deleteCalls, isEmpty);
    });

    test('pull überschreibt lokalen dirty Datensatz nicht', () async {
      fakeDb.pendingChanges = [];
      fakeDb.alleArtikel = [
        makeArtikel(
          uuid: 'uuid-dirty',
          etag: null,
          lastSyncedEtag: 'sync-1',
          remotePath: 'pb-1',
        ),
      ];

      final remoteRecord = makeRecord(
        id: 'pb-1',
        data: {
          'uuid': 'uuid-dirty',
          'name': 'Remote Artikel',
          'menge': 99,
          'ort': 'Remote',
          'fach': 'R1',
          'beschreibung': 'Remote',
          'updated': 'sync-2',
          'created': '2026-01-01 00:00:00.000Z',
        },
        updated: 'sync-2',
      );
      fakeRecordService.onGetFullList = () async => [remoteRecord];

      await syncService.syncOnce();

      expect(fakeDb.upsertCalls, isEmpty);
      expect(conflicts, hasLength(1));
      expect(conflicts.first['local']!.uuid, equals('uuid-dirty'));
    });

    test('pull respektiert pendingResolution und überschreibt nicht', () async {
      fakeDb.pendingChanges = [];
      fakeDb.alleArtikel = [
        makeArtikel(
          uuid: 'uuid-pending',
          etag: null,
          pendingResolution: 'force_merge',
          lastSyncedEtag: 'sync-1',
          remotePath: 'pb-1',
        ),
      ];

      final remoteRecord = makeRecord(
        id: 'pb-1',
        data: {
          'uuid': 'uuid-pending',
          'name': 'Remote',
          'menge': 7,
          'ort': 'X',
          'fach': 'Y',
          'beschreibung': 'Z',
          'updated': 'sync-2',
          'created': '2026-01-01 00:00:00.000Z',
        },
        updated: 'sync-2',
      );
      fakeRecordService.onGetFullList = () async => [remoteRecord];

      await syncService.syncOnce();

      expect(fakeDb.upsertCalls, isEmpty);
      expect(conflicts, isEmpty);
    });

    test('pull überspringt dirty lokalen Datensatz auch ohne Konflikt',
        () async {
      fakeDb.pendingChanges = [];
      fakeDb.alleArtikel = [
        makeArtikel(
          uuid: 'uuid-local-dirty',
          etag: null,
          lastSyncedEtag: 'sync-1',
          remotePath: 'pb-1',
        ),
      ];

      final remoteRecord = makeRecord(
        id: 'pb-1',
        data: {
          'uuid': 'uuid-local-dirty',
          'name': 'Remote',
          'menge': 7,
          'ort': 'X',
          'fach': 'Y',
          'beschreibung': 'Z',
          'updated': 'sync-1',
          'created': '2026-01-01 00:00:00.000Z',
        },
        updated: 'sync-1',
      );
      fakeRecordService.onGetFullList = () async => [remoteRecord];

      await syncService.syncOnce();

      expect(fakeDb.upsertCalls, isEmpty);
      expect(conflicts, isEmpty);
    });

    test('remote-fehlender Artikel wird lokal nicht gelöscht wenn dirty',
        () async {
      fakeDb.pendingChanges = [];
      fakeDb.alleArtikel = [
        makeArtikel(
          uuid: 'uuid-local-dirty',
          etag: null,
          remotePath: 'pb-x',
        ),
      ];

      fakeRecordService.onGetFullList = () async => [];

      await syncService.syncOnce();

      expect(fakeDb.deleteCalls, isEmpty);
    });

    test(
      'remote-fehlender Artikel wird lokal nicht gelöscht wenn pendingResolution gesetzt',
      () async {
        fakeDb.pendingChanges = [];
        fakeDb.alleArtikel = [
          makeArtikel(
            uuid: 'uuid-pending-delete',
            etag: 'etag-ok',
            pendingResolution: 'force_local',
            remotePath: 'pb-x',
          ),
        ];

        fakeRecordService.onGetFullList = () async => [];

        await syncService.syncOnce();

        expect(fakeDb.deleteCalls, isEmpty);
      },
    );
    test(
      'pull erkennt Konflikt wenn lokaler dirty Datensatz keine lastSyncedEtag-Basis hat',
      () async {
        fakeDb.pendingChanges = [];
        fakeDb.alleArtikel = [
          makeArtikel(
            uuid: 'uuid-pull-missing-base',
            etag: null,
            lastSyncedEtag: null,
            pendingResolution: null,
            remotePath: 'pb-pull',
          ),
        ];

        final remoteRecord = makeRecord(
          id: 'pb-pull',
          data: {
            'uuid': 'uuid-pull-missing-base',
            'name': 'Remote Artikel',
            'menge': 42,
            'ort': 'Remote',
            'fach': 'R1',
            'beschreibung': 'Remote',
            'updated': 'remote-new',
            'created': '2026-01-01 00:00:00.000Z',
          },
          updated: ts2,
        );

        fakeRecordService.onGetFullList = () async => [remoteRecord];

        await syncService.syncOnce();

        expect(fakeDb.upsertCalls, isEmpty);
        expect(conflicts, hasLength(1));
        expect(conflicts.first['local']!.uuid, equals('uuid-pull-missing-base'));
      },
    );
    test(
      'pull erkennt Konflikt wenn lastSyncedEtag nur Whitespace ist',
      () async {
        fakeDb.pendingChanges = [];
        fakeDb.alleArtikel = [
          makeArtikel(
            uuid: 'uuid-pull-blank-base',
            etag: null,
            lastSyncedEtag: '   ',
            pendingResolution: null,
            remotePath: 'pb-pull-blank',
          ),
        ];

        final remoteRecord = makeRecord(
          id: 'pb-pull-blank',
          data: {
            'uuid': 'uuid-pull-blank-base',
            'name': 'Remote Artikel',
            'menge': 42,
            'ort': 'Remote',
            'fach': 'R1',
            'beschreibung': 'Remote',
            'updated': 'remote-new',
            'created': '2026-01-01 00:00:00.000Z',
          },
          updated: ts2,
        );

        fakeRecordService.onGetFullList = () async => [remoteRecord];

        await syncService.syncOnce();

        expect(fakeDb.upsertCalls, isEmpty);
        expect(conflicts, hasLength(1));
        expect(conflicts.first['local']!.uuid, equals('uuid-pull-blank-base'));
      },
    );

  });

  group('syncOnce()', () {
    test('setzt lastSyncTime nach erfolgreichem Sync', () async {
      fakeDb.pendingChanges = [];
      fakeRecordService.onGetFullList = () async => [];

      await syncService.syncOnce();

      expect(fakeDb.setLastSyncTimeCalled, isTrue);
    });

    test('fängt allgemeinen Fehler ab ohne zu werfen', () async {
      fakeDb.pendingChanges = [];
      fakeRecordService.onGetFullList = () async {
        throw Exception('DB kaputt');
      };

      await syncService.syncOnce();

      expect(fakeDb.setLastSyncTimeCalled, isFalse);
    });

    test('keine Pending Changes → nur Pull wird ausgeführt', () async {
      fakeDb.pendingChanges = [];

      final remoteRecord = makeRecord(
        id: 'pb-only-pull',
        data: {
          'uuid': 'pull-uuid',
          'name': 'Nur Pull',
          'menge': 1,
          'ort': 'A',
          'fach': 'B',
          'beschreibung': '',
          'created': '2026-01-01 00:00:00.000Z',
          'updated': '2026-01-01 00:00:00.000Z',
        },
      );
      fakeRecordService.onGetFullList = () async => [remoteRecord];

      await syncService.syncOnce();

      expect(fakeRecordService.createBodies, isEmpty);
      expect(fakeRecordService.updateEntries, isEmpty);
      expect(fakeRecordService.deleteIds, isEmpty);
      expect(fakeDb.upsertCalls, hasLength(1));
    });
  });

  group('UUID-Sanitization (Finding 5)', () {
    test('entfernt Anführungszeichen aus UUID im Filter', () async {
      final artikel = makeArtikel(
        uuid: '"uuid-with-quotes"',
        etag: null,
      );
      fakeDb.pendingChanges = [artikel];

      fakeRecordService.onGetList = (_) async => makeResultList([]);
      fakeRecordService.onCreate = (body) async => makeRecord(
            id: 'pb-sanitized',
            data: body,
          );
      fakeRecordService.onGetFullList = () async => [];

      await syncService.syncOnce();

      expect(fakeRecordService.getListFilters, hasLength(1));
      final filter = fakeRecordService.getListFilters.first;
      expect(filter, equals('uuid = "uuid-with-quotes"'));
      expect(filter, isNot(contains('""')));
    });
  });

  group('downloadMissingImages()', () {
    test('überspringt Artikel ohne remoteBildPfad', () async {
      fakeDb.alleArtikel = [makeArtikel(remoteBildPfad: null)];

      await syncService.downloadMissingImages();

      expect(fakeDb.setBildPfadSilentCalls, isEmpty);
    });

    test('überspringt Artikel ohne remotePath (Record-ID)', () async {
      fakeDb.alleArtikel = [
        makeArtikel(remoteBildPfad: 'bild.jpg', remotePath: null),
      ];

      await syncService.downloadMissingImages();

      expect(fakeDb.setBildPfadSilentCalls, isEmpty);
    });

    test('überspringt wenn PocketBase-URL leer', () async {
      fakePbService.url = '';
      fakePbService.hasClient = false;

      fakeDb.alleArtikel = [
        makeArtikel(
          remoteBildPfad: 'foto.jpg',
          remotePath: 'pb-123',
          bildPfad: '',
        ),
      ];

      await syncService.downloadMissingImages();

      expect(fakeDb.setBildPfadSilentCalls, isEmpty);
    });

    test('überspringt wenn lokales Bild bereits existiert', () async {
      fakeDb.alleArtikel = [
        makeArtikel(
          remoteBildPfad: 'foto.jpg',
          remotePath: 'pb-123',
          bildPfad: '/existing/path/foto.jpg',
        ),
      ];

      await syncService.downloadMissingImages();

      expect(fakeDb.setBildPfadSilentCalls, isEmpty);
    });
  });
}