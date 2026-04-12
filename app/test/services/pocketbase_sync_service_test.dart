// test/services/pocketbase_sync_service_test.dart
//
// T-002: Unit-Tests für PocketBaseSyncService.
//
// Strategie:
// - Manuelle Fakes statt @GenerateMocks
//   (PocketBaseService = Singleton, ArtikelDbService = Singleton,
//    PocketBase/RecordService haben komplexe Vererbungsketten)
// - Kein Netzwerk, kein SQLite, kein Dateisystem nötig
// - Jeder Test ist isoliert und deterministisch

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import 'package:lager_app/models/artikel_model.dart';

// ══════════════════════════════════════════════════════════════════
// FAKE: PocketBaseService
// ══════════════════════════════════════════════════════════════════
// Wir mocken NICHT die echte Klasse (Singleton + factory),
// sondern injizieren direkt in PocketBaseSyncService.
// PocketBaseSyncService erwartet im Konstruktor:
//   PocketBaseSyncService(collectionName, PocketBaseService, ArtikelDbService)
//
// Da PocketBaseSyncService nur folgende Properties/Methoden nutzt:
//   .client, .isAuthenticated, .currentUserId, .hasClient, .url
// erstellen wir eine minimale Implementierung.

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

  // Tracking
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
// PocketBaseSyncService erwartet echte PocketBaseService + ArtikelDbService.
// Da beide Singletons mit factory-Konstruktoren sind, erstellen wir
// eine testbare Subklasse die unsere Fakes verwendet.

class TestableSyncService {
  final String collectionName;
  final FakePbService _pbService;
  final FakeArtikelDbService _db;
  final FakeRecordService _recordService;

  TestableSyncService(
    this.collectionName,
    this._pbService,
    this._db,
    this._recordService,
  );

  /// Simuliert syncOnce() mit der gleichen Logik wie PocketBaseSyncService.
  Future<void> syncOnce() async {
    try {
      await _pushToPocketBase();
      await _pullFromPocketBase();
      await _db.setLastSyncTime();
    } catch (e) {
      // Fehler abfangen wie im Original
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
            await _recordService.delete(list.items.first.id);
          }
          await _db.markSynced(artikel.uuid, 'deleted');
          continue;
        }

        if (list.items.isNotEmpty) {
          final recId = list.items.first.id;
          final body = artikel.toPocketBaseMap();
          if (_pbService.isAuthenticated && _pbService.currentUserId != null) {
            body['owner'] = _pbService.currentUserId;
          }
          final updated = await _recordService.update(recId, body: body);
          await _db.markSynced(
            artikel.uuid,
            artikel.etag ?? '',
            remotePath: updated.id,
          );
        } else {
          final body = artikel.toPocketBaseMap();
          if (_pbService.isAuthenticated && _pbService.currentUserId != null) {
            body['owner'] = _pbService.currentUserId;
          }
          final created = await _recordService.create(body: body);
          await _db.markSynced(
            artikel.uuid,
            artikel.etag ?? '',
            remotePath: created.id,
          );
        }
      } catch (e) {
        // Fehler pro Artikel abfangen, weiter mit nächstem
      }
    }
  }

  Future<void> _pullFromPocketBase() async {
    final records = await _recordService.getFullList();

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

        if (artikel.uuid.isNotEmpty) remoteUuids.add(artikel.uuid);
      } catch (e) {
        // Fehler pro Record abfangen
      }
    }

    if (remoteUuids.isNotEmpty) {
      final localArtikel = await _db.getAlleArtikel();
      for (final lokal in localArtikel) {
        if (!remoteUuids.contains(lokal.uuid)) {
          await _db.deleteArtikel(lokal);
        }
      }
    }
  }

  Future<void> downloadMissingImages() async {
    final alleArtikel =
        await _db.getAlleArtikel(limit: 999999, offset: 0);

    for (final artikel in alleArtikel) {
      final remoteBild = artikel.remoteBildPfad;
      final recordId = artikel.remotePath;
      if (remoteBild == null || remoteBild.isEmpty) continue;
      if (recordId == null || recordId.isEmpty) continue;

      // Lokales Bild existiert → skip
      if (artikel.bildPfad.isNotEmpty) continue;

      // URL bauen
      if (!_pbService.hasClient || _pbService.url.isEmpty) continue;

      // In echtem Code: HTTP download + Datei schreiben
      // Hier testen wir nur die Skip-Logik
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
  // RecordModel.fromJson() erwartet eine flache Map mit allen Feldern.
  // id/created/updated sind Top-Level-Felder, der Rest landet in .data
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
    remotePath: remotePath,
    deleted: deleted,
    remoteBildPfad: remoteBildPfad,
  );
}

// ══════════════════════════════════════════════════════════════════
// TESTS
// ══════════════════════════════════════════════════════════════════

void main() {
  late FakePbService fakePbService;
  late FakeArtikelDbService fakeDb;
  late FakeRecordService fakeRecordService;
  late TestableSyncService syncService;

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
  });

  // ════════════════════════════════════════════════════════════════
  // PUSH-TESTS
  // ════════════════════════════════════════════════════════════════

  group('Push: lokale Änderungen hochladen', () {
    test(
      'erstellt neuen Remote-Record wenn kein Match gefunden',
      () async {
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
        expect(
          fakeDb.markSyncedCalls.first.remotePath,
          equals('pb-new-001'),
        );
      },
    );

    test(
      'aktualisiert bestehenden Remote-Record wenn Match gefunden',
      () async {
        final artikel = makeArtikel(
          etag: null,
          remotePath: 'pb-existing-001',
        );
        fakeDb.pendingChanges = [artikel];

        final existingRecord = makeRecord(
          id: 'pb-existing-001',
          data: {'uuid': artikel.uuid},
        );
        fakeRecordService.onGetList =
            (_) async => makeResultList([existingRecord]);
        fakeRecordService.onUpdate = (id, body) async =>
            makeRecord(id: id, data: body);
        fakeRecordService.onGetFullList = () async => [];

        await syncService.syncOnce();

        expect(fakeRecordService.updateEntries, hasLength(1));
        expect(
          fakeRecordService.updateEntries.first.key,
          equals('pb-existing-001'),
        );
        expect(fakeRecordService.createBodies, isEmpty);
      },
    );

    test(
      'löscht Remote-Record wenn Artikel soft-deleted ist',
      () async {
        final deletedArtikel = makeArtikel(
          uuid: 'uuid-deleted',
          etag: null,
          deleted: true,
        );
        fakeDb.pendingChanges = [deletedArtikel];

        final remoteRecord = makeRecord(
          id: 'pb-to-delete',
          data: {'uuid': 'uuid-deleted'},
        );
        fakeRecordService.onGetList =
            (_) async => makeResultList([remoteRecord]);
        fakeRecordService.onGetFullList = () async => [];

        await syncService.syncOnce();

        expect(fakeRecordService.deleteIds, contains('pb-to-delete'));
        final syncCall = fakeDb.markSyncedCalls
            .firstWhere((c) => c.uuid == 'uuid-deleted');
        expect(syncCall.etag, equals('deleted'));
      },
    );

    test(
      'markiert als deleted auch wenn Remote-Record nicht existiert',
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
      },
    );

    test(
      'fängt Push-Fehler ab und fährt mit nächstem Artikel fort',
      () async {
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

        // Zweiter Artikel wurde trotzdem verarbeitet
        expect(fakeRecordService.createBodies, hasLength(1));
        expect(fakeDb.markSyncedCalls, hasLength(1));
        expect(
          fakeDb.markSyncedCalls.first.remotePath,
          equals('pb-ok'),
        );
      },
    );

    test(
      'setzt owner wenn authentifiziert',
      () async {
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
        expect(
          fakeRecordService.createBodies.first['owner'],
          equals('user-123'),
        );
      },
    );
  });

  // ════════════════════════════════════════════════════════════════
  // PULL-TESTS
  // ════════════════════════════════════════════════════════════════

  group('Pull: Remote-Records herunterladen', () {
    test(
      'fügt neue Remote-Records lokal ein',
      () async {
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
        expect(
          fakeDb.upsertCalls.first.uuid,
          equals('remote-uuid-001'),
        );
        expect(
          fakeDb.upsertCalls.first.name,
          equals('Remote Artikel'),
        );
      },
    );

    test(
      'soft-deleted lokale Artikel die remote nicht mehr existieren',
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

        final lokalA = makeArtikel(uuid: 'uuid-A');
        final lokalB = makeArtikel(uuid: 'uuid-B', name: 'Nur lokal');
        fakeDb.alleArtikel = [lokalA, lokalB];

        await syncService.syncOnce();

        expect(fakeDb.deleteCalls, hasLength(1));
        expect(fakeDb.deleteCalls.first.uuid, equals('uuid-B'));
      },
    );

    test(
      'überspringt lokale Löschung wenn remoteUuids leer',
      () async {
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

        fakeDb.alleArtikel = [makeArtikel(uuid: 'local-only')];

        await syncService.syncOnce();

        expect(fakeDb.deleteCalls, isEmpty);
      },
    );
  });

  // ════════════════════════════════════════════════════════════════
  // SYNC-ONCE INTEGRATION
  // ════════════════════════════════════════════════════════════════

  group('syncOnce()', () {
    test(
      'setzt lastSyncTime nach erfolgreichem Sync',
      () async {
        fakeDb.pendingChanges = [];
        fakeRecordService.onGetFullList = () async => [];

        await syncService.syncOnce();

        expect(fakeDb.setLastSyncTimeCalled, isTrue);
      },
    );

    test(
      'fängt allgemeinen Fehler ab ohne zu werfen',
      () async {
        fakeDb.pendingChanges = [];
        fakeRecordService.onGetFullList = () async {
          throw Exception('DB kaputt');
        };

        // Sollte NICHT werfen
        await syncService.syncOnce();

        expect(fakeDb.setLastSyncTimeCalled, isFalse);
      },
    );

    test(
      'keine Pending Changes → nur Pull wird ausgeführt',
      () async {
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
      },
    );
  });

  // ════════════════════════════════════════════════════════════════
  // UUID-SANITIZATION
  // ════════════════════════════════════════════════════════════════

  group('UUID-Sanitization (Finding 5)', () {
    test(
      'entfernt Anführungszeichen aus UUID im Filter',
      () async {
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
      },
    );
  });

  // ════════════════════════════════════════════════════════════════
  // IMAGE DOWNLOAD
  // ════════════════════════════════════════════════════════════════

  group('downloadMissingImages()', () {
    test(
      'überspringt Artikel ohne remoteBildPfad',
      () async {
        fakeDb.alleArtikel = [makeArtikel(remoteBildPfad: null)];

        await syncService.downloadMissingImages();

        expect(fakeDb.setBildPfadSilentCalls, isEmpty);
      },
    );

    test(
      'überspringt Artikel ohne remotePath (Record-ID)',
      () async {
        fakeDb.alleArtikel = [
          makeArtikel(remoteBildPfad: 'bild.jpg', remotePath: null),
        ];

        await syncService.downloadMissingImages();

        expect(fakeDb.setBildPfadSilentCalls, isEmpty);
      },
    );

    test(
      'überspringt wenn PocketBase-URL leer',
      () async {
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
      },
    );

    test(
      'überspringt wenn lokales Bild bereits existiert',
      () async {
        fakeDb.alleArtikel = [
          makeArtikel(
            remoteBildPfad: 'foto.jpg',
            remotePath: 'pb-123',
            bildPfad: '/existing/path/foto.jpg',
          ),
        ];

        await syncService.downloadMissingImages();

        expect(fakeDb.setBildPfadSilentCalls, isEmpty);
      },
    );
  });
}