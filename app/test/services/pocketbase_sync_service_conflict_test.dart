//lib/services/pocketbase_sync_service.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import 'package:lager_app/models/artikel_model.dart';
import 'package:lager_app/services/pocketbase_sync_contracts.dart';
import 'package:lager_app/services/pocketbase_sync_service.dart';

class FakePbService implements SyncPocketBaseService {
  @override
  final PocketBase client;

  @override
  bool isAuthenticated;

  @override
  String? currentUserId;

  @override
  bool hasClient;

  @override
  String url;

  FakePbService({
    required this.client,
    this.isAuthenticated = false,
    this.currentUserId,
    this.hasClient = true,
    this.url = 'http://localhost:8090',
  });
}

// -----------------------------------------------------------------------------
// Fake-DB-Service für Tests
// -----------------------------------------------------------------------------
class FakeArtikelDbService implements SyncArtikelDbService {
  List<Artikel> pendingChanges = [];
  List<Artikel> alleArtikel = [];
  final Map<String, Artikel> byUuid = {};

  final List<MarkSyncedCall> markSyncedCalls = [];
  final List<Artikel> upsertCalls = [];
  final List<String> upsertEtags = [];
  final List<Artikel> deleteCalls = [];
  final List<SetBildPfadCall> setBildPfadSilentCalls = [];
  bool setLastSyncTimeCalled = false;

  // ────────────────────────────────────────────────────────────────────────
  //  Neue Methode (Pflicht seit Interface-Erweiterung)
  // ────────────────────────────────────────────────────────────────────────
  @override
  Future<void> clearBildInfoByUuidSilent(String uuid) async {
    final a = byUuid[uuid];
    if (a != null) {
      byUuid[uuid] = a.copyWith(
        bildPfad: '',
        remoteBildPfad: null,
      );
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  //  Bereits vorhandene Methoden (evtl. leicht angepasst)
  // ────────────────────────────────────────────────────────────────────────
  @override
  Future<List<Artikel>> getPendingChanges() async => pendingChanges;

  @override
  Future<List<Artikel>> getAlleArtikel({
    int limit = 500,
    int offset = 0,
  }) async =>
      alleArtikel;

  @override
  Future<void> markSynced(
    String uuid,
    String etag, {
    String? remotePath,
    String? remoteBildPfad,   // ➊ NEU – optional
  }) async {
    markSyncedCalls.add(MarkSyncedCall(uuid, etag, remotePath));

    final existing = byUuid[uuid];
    if (existing == null) return;

    final synced = existing.copyWith(
      etag: etag == 'deleted' ? existing.etag : etag,
      lastSyncedEtag: etag == 'deleted' ? existing.lastSyncedEtag : etag,
      remotePath: remotePath ?? existing.remotePath,
      pendingResolution: null,
      deleted: etag == 'deleted' ? true : false,
    );

    byUuid[uuid] = synced;

    final idxAlle = alleArtikel.indexWhere((a) => a.uuid == uuid);
    if (idxAlle != -1) {
      alleArtikel[idxAlle] = synced;
    }

    final idxPending = pendingChanges.indexWhere((a) => a.uuid == uuid);
    if (idxPending != -1) {
      pendingChanges[idxPending] = synced;
    }
  }

  @override
  Future<void> upsertArtikel(Artikel artikel, {String? etag}) async {
    upsertCalls.add(artikel);
    upsertEtags.add(etag ?? '');
    byUuid[artikel.uuid] = artikel;
  }

  @override
  Future<void> deleteArtikel(Artikel artikel) async {
    deleteCalls.add(artikel);
  }

  @override
  Future<void> setBildPfadByUuidSilent(String uuid, String bildPfad) async {
    setBildPfadSilentCalls.add(SetBildPfadCall(uuid, bildPfad));
  }

  @override
  Future<void> setLastSyncTime() async {
    setLastSyncTimeCalled = true;
  }

  @override
  Future<Artikel?> getArtikelByUUID(String uuid) async => byUuid[uuid];
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
}

class FakePocketBase extends PocketBase {
  final FakeRecordService fakeRecordService;

  FakePocketBase(this.fakeRecordService) : super('http://fake');

  @override
  RecordService collection(String collectionIdOrName) => fakeRecordService;
}

class ConflictCapture {
  Artikel? local;
  Artikel? remote;
  int callCount = 0;

  Future<void> call(Artikel lokal, Artikel remoteArtikel) async {
    callCount++;
    local = lokal;
    remote = remoteArtikel;
  }
}

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
  required String uuid,
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
    uuid: uuid,
    etag: etag,
    lastSyncedEtag: lastSyncedEtag,
    pendingResolution: pendingResolution,
    remotePath: remotePath,
    deleted: deleted,
    remoteBildPfad: remoteBildPfad,
  );
}

void main() {
  late FakePbService fakePbService;
  late FakeArtikelDbService fakeDb;
  late FakeRecordService fakeRecordService;
  late PocketBaseSyncService syncService;

  setUp(() {
    fakeRecordService = FakeRecordService();
    final fakePb = FakePocketBase(fakeRecordService);

    fakePbService = FakePbService(client: fakePb);
    fakeDb = FakeArtikelDbService();

    syncService = PocketBaseSyncService(
      'artikel',
      fakePbService,
      fakeDb,
    );
  });

  group('PocketBaseSyncService Konflikte', () {
    test(
      'T-001.10: übersprungener Konflikt erscheint beim nächsten Sync erneut',
      () async {
        final lokal = makeArtikel(
          uuid: 'uuid-skip-repeat',
          etag: '2026-01-15 10:00:00.000Z',
          lastSyncedEtag: '2026-01-15 10:00:00.000Z',
          pendingResolution: null,
          remotePath: 'pb-skip-1',
        );

        fakeDb.pendingChanges = [lokal];
        fakeDb.alleArtikel = [lokal];
        fakeDb.byUuid[lokal.uuid] = lokal;

        final remoteRecord = makeRecord(
          id: 'pb-skip-1',
          updated: '2026-01-15 11:00:00.000Z',
          data: {
            'uuid': lokal.uuid,
            'name': 'Remote geändert',
            'menge': 10,
            'ort': 'Remote Lager',
            'fach': 'R1',
            'beschreibung': 'remote',
            'deleted': false,
          },
        );

        fakeRecordService.onGetList =
            (_) async => makeResultList([remoteRecord]);
        fakeRecordService.onGetFullList = () async => [];

        final capture = ConflictCapture();
        syncService.onConflictDetected = capture.call;

        await syncService.syncOnce();
        await syncService.syncOnce();

        expect(
          capture.callCount,
          equals(2),
        );
        expect(
          fakeDb.markSyncedCalls,
          isEmpty,
        );
        expect(
          fakeRecordService.updateEntries,
          isEmpty,
        );
        expect(
          fakeRecordService.deleteIds,
          isEmpty,
        );
      },
    );

      test(
        'T-001.12: soft-delete lokal plus remote edit löst Konflikt aus statt Remote-Löschung',
        () async {
          final lokal = makeArtikel(
            uuid: 'uuid-delete-vs-edit',
            etag: '2026-01-15 10:00:00.000Z',
            deleted: true,
            lastSyncedEtag: '2026-01-15 10:00:00.000Z',
            pendingResolution: null,
            remotePath: 'pb-del-edit-1',
          );

          fakeDb.pendingChanges = [lokal];
          fakeDb.alleArtikel = [lokal];
          fakeDb.byUuid[lokal.uuid] = lokal;

          final remoteRecord = makeRecord(
            id: 'pb-del-edit-1',
            updated: '2026-01-15 11:00:00.000Z',
            data: {
              'uuid': lokal.uuid,
              'name': 'Remote geändert nach lokalem Delete',
              'menge': 42,
              'ort': 'Lager B',
              'fach': 'Fach 9',
              'beschreibung': 'remote edit',
              'deleted': false,
            },
          );

          fakeRecordService.onGetList =
              (_) async => makeResultList([remoteRecord]);
          fakeRecordService.onGetFullList = () async => [];

          final capture = ConflictCapture();
          syncService.onConflictDetected = capture.call;

          await syncService.syncOnce();

          expect(capture.callCount, equals(1));
          expect(capture.local, isNotNull);
          expect(capture.remote, isNotNull);
          expect(capture.local!.uuid, equals('uuid-delete-vs-edit'));
          expect(capture.remote!.uuid, equals('uuid-delete-vs-edit'));
          
          expect(fakeRecordService.deleteIds, isEmpty);
          expect(fakeDb.markSyncedCalls, isEmpty);
        },
      );
    test(
      'T-001.13: pull überschreibt force_local-Datensatz nicht mit Remote-Version',
      () async {
        final lokal = makeArtikel(
          uuid: 'uuid-pull-force-local',
          etag: '2026-01-15 10:00:00.000Z',
          lastSyncedEtag: '2026-01-15 10:00:00.000Z',
          pendingResolution: 'force_local',
          remotePath: 'pb-force-local-1',
          name: 'Lokale bewusste Entscheidung',
          menge: 5,
        );

        fakeDb.pendingChanges = [];
        fakeDb.alleArtikel = [lokal];
        fakeDb.byUuid[lokal.uuid] = lokal;

        final remoteRecord = makeRecord(
          id: 'pb-force-local-1',
          updated: '2026-01-15 11:00:00.000Z',
          data: {
            'uuid': lokal.uuid,
            'name': 'Remote geändert',
            'menge': 99,
            'ort': 'Remote Lager',
            'fach': 'R9',
            'beschreibung': 'remote',
            'deleted': false,
          },
        );

        fakeRecordService.onGetFullList = () async => [remoteRecord];
        final capture = ConflictCapture();
        syncService.onConflictDetected = capture.call;

        await syncService.syncOnce();

        expect(capture.callCount, equals(0));
        expect(fakeDb.upsertCalls, isEmpty);
        expect(fakeDb.deleteCalls, isEmpty);
        expect(fakeDb.markSyncedCalls, isEmpty);
      },
    );

    test(
      'T-001.14: pull überschreibt force_merge-Datensatz nicht mit Remote-Version',
      () async {
        final lokal = makeArtikel(
          uuid: 'uuid-pull-force-merge',
          etag: '2026-01-15 10:00:00.000Z',
          lastSyncedEtag: '2026-01-15 10:00:00.000Z',
          pendingResolution: 'force_merge',
          remotePath: 'pb-force-merge-1',
          name: 'Gemergte lokale Entscheidung',
          menge: 12,
        );

        fakeDb.pendingChanges = [];
        fakeDb.alleArtikel = [lokal];
        fakeDb.byUuid[lokal.uuid] = lokal;

        final remoteRecord = makeRecord(
          id: 'pb-force-merge-1',
          updated: '2026-01-15 11:00:00.000Z',
          data: {
            'uuid': lokal.uuid,
            'name': 'Remote überschreibt sonst',
            'menge': 77,
            'ort': 'Remote Lager',
            'fach': 'R8',
            'beschreibung': 'remote',
            'deleted': false,
          },
        );

        fakeRecordService.onGetFullList = () async => [remoteRecord];
        final capture = ConflictCapture();
        syncService.onConflictDetected = capture.call;

        await syncService.syncOnce();

        expect(capture.callCount, equals(0));
        expect(fakeDb.upsertCalls, isEmpty);
        expect(fakeDb.deleteCalls, isEmpty);
        expect(fakeDb.markSyncedCalls, isEmpty);
      },
    );
    test(
      'T-001.15: remote-fehlender sauberer Datensatz wird bei validem Pull lokal gelöscht',
      () async {
        final lokalZuBehalten = makeArtikel(
          uuid: 'uuid-remote-still-exists',
          etag: '2026-01-15 10:00:00.000Z',
          lastSyncedEtag: '2026-01-15 10:00:00.000Z',
          pendingResolution: null,
          remotePath: 'pb-keep-1',
          name: 'Existiert remote weiter',
        );

        final lokalZuLoeschen = makeArtikel(
          uuid: 'uuid-clean-delete',
          etag: '2026-01-15 10:00:00.000Z',
          lastSyncedEtag: '2026-01-15 10:00:00.000Z',
          pendingResolution: null,
          remotePath: 'pb-clean-delete-1',
          name: 'Fehlt remote',
          menge: 3,
        );

        fakeDb.pendingChanges = [];
        fakeDb.alleArtikel = [lokalZuBehalten, lokalZuLoeschen];
        fakeDb.byUuid[lokalZuBehalten.uuid] = lokalZuBehalten;
        fakeDb.byUuid[lokalZuLoeschen.uuid] = lokalZuLoeschen;

        final remoteRecord = makeRecord(
          id: 'pb-keep-1',
          updated: '2026-01-15 11:00:00.000Z',
          data: {
            'uuid': 'uuid-remote-still-exists',
            'name': 'Existiert remote weiter',
            'menge': 8,
            'ort': 'Remote Lager',
            'fach': 'R2',
            'beschreibung': 'remote ok',
            'deleted': false,
          },
        );

        fakeRecordService.onGetFullList = () async => [remoteRecord];

        final capture = ConflictCapture();
        syncService.onConflictDetected = capture.call;

        await syncService.syncOnce();

        expect(capture.callCount, equals(0));
        expect(fakeDb.deleteCalls, hasLength(1));
        expect(fakeDb.deleteCalls.first.uuid, equals('uuid-clean-delete'));
      },
    );
    test(
      'T-001.16: erfolgreicher force_local-Push bereinigt pendingResolution lokal',
      () async {
        final lokal = makeArtikel(
          uuid: 'uuid-force-local-cleared',
          etag: '2026-01-15 10:00:00.000Z',
          lastSyncedEtag: '2026-01-15 10:00:00.000Z',
          pendingResolution: 'force_local',
          remotePath: 'pb-force-local-clear-1',
          name: 'Lokale Entscheidung',
        );

        fakeDb.pendingChanges = [lokal];
        fakeDb.alleArtikel = [lokal];
        fakeDb.byUuid[lokal.uuid] = lokal;

        final remoteRecord = makeRecord(
          id: 'pb-force-local-clear-1',
          updated: '2026-01-15 11:00:00.000Z',
          data: {
            'uuid': lokal.uuid,
            'name': 'Remote Altstand',
            'menge': 7,
            'ort': 'Remote',
            'fach': 'R1',
            'beschreibung': 'remote',
            'deleted': false,
          },
        );

        fakeRecordService.onGetList =
            (_) async => makeResultList([remoteRecord]);

        fakeRecordService.onUpdate = (id, body) async => makeRecord(
              id: id,
              updated: '2026-01-15 12:00:00.000Z',
              data: {
                ...body,
                'updated': '2026-01-15 12:00:00.000Z',
              },
            );

        fakeRecordService.onGetFullList = () async => [];

        await syncService.syncOnce();

        expect(fakeRecordService.updateEntries, hasLength(1));
        expect(fakeDb.markSyncedCalls, hasLength(1));
        expect(fakeDb.byUuid[lokal.uuid], isNotNull);
        expect(
          fakeDb.byUuid[lokal.uuid]!.pendingResolution,
          isNull,
        );
      },
    );

    test(
      'T-001.17: erfolgreicher force_merge-Push bereinigt pendingResolution lokal',
      () async {
        final lokal = makeArtikel(
          uuid: 'uuid-force-merge-cleared',
          etag: '2026-01-15 10:00:00.000Z',
          lastSyncedEtag: '2026-01-15 10:00:00.000Z',
          pendingResolution: 'force_merge',
          remotePath: 'pb-force-merge-clear-1',
          name: 'Gemergte Entscheidung',
        );

        fakeDb.pendingChanges = [lokal];
        fakeDb.alleArtikel = [lokal];
        fakeDb.byUuid[lokal.uuid] = lokal;

        final remoteRecord = makeRecord(
          id: 'pb-force-merge-clear-1',
          updated: '2026-01-15 11:00:00.000Z',
          data: {
            'uuid': lokal.uuid,
            'name': 'Remote Altstand',
            'menge': 9,
            'ort': 'Remote',
            'fach': 'R2',
            'beschreibung': 'remote',
            'deleted': false,
          },
        );

        fakeRecordService.onGetList =
            (_) async => makeResultList([remoteRecord]);

        fakeRecordService.onUpdate = (id, body) async => makeRecord(
              id: id,
              updated: '2026-01-15 12:00:00.000Z',
              data: {
                ...body,
                'updated': '2026-01-15 12:00:00.000Z',
              },
            );

        fakeRecordService.onGetFullList = () async => [];

        await syncService.syncOnce();

        expect(fakeRecordService.updateEntries, hasLength(1));
        expect(fakeDb.markSyncedCalls, hasLength(1));
        expect(fakeDb.byUuid[lokal.uuid], isNotNull);
        expect(
          fakeDb.byUuid[lokal.uuid]!.pendingResolution,
          isNull,
        );
      },
    );

  });
}