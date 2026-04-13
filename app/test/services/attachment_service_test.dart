// test/services/attachment_service_test.dart
//
// T-005: Unit-Tests für AttachmentService.
//
// Strategie:
// - PocketBaseService.overrideForTesting(FakePocketBase) injiziert Fake-Client
// - FakeAttachmentRecordService fängt alle collection('attachments')-Aufrufe ab
// - Kein Netzwerk, kein Dateisystem, kein sqflite
// - Reiner test()-Block (kein testWidgets nötig)
//
// Getestete Methoden:
//   - getForArtikel(artikelUuid)
//   - countForArtikel(artikelUuid)
//   - upload(...)
//   - updateMetadata(...)
//   - delete(attachmentId)
//   - deleteAllForArtikel(artikelUuid)

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import 'package:lager_app/models/attachment_model.dart';
import 'package:lager_app/services/attachment_service.dart';
import 'package:lager_app/services/pocketbase_service.dart';

// ══════════════════════════════════════════════════════════════════
// FAKE: RecordService für 'attachments' Collection
// ══════════════════════════════════════════════════════════════════

typedef GetListHandler = Future<ResultList<RecordModel>> Function({
  String? filter,
  String? sort,
  int? perPage,
  int? page,
});
typedef CreateHandler = Future<RecordModel> Function(
  Map<String, dynamic> body,
  List<http.MultipartFile> files,
);
typedef UpdateHandler = Future<RecordModel> Function(
  String id,
  Map<String, dynamic> body,
);
typedef DeleteHandler = Future<void> Function(String id);

class FakeAttachmentRecordService extends RecordService {
  GetListHandler? onGetList;
  CreateHandler? onCreate;
  UpdateHandler? onUpdate;
  DeleteHandler? onDelete;

  // Tracking
  final List<String> getListFilters = [];
  final List<Map<String, dynamic>> createBodies = [];
  final List<List<http.MultipartFile>> createFiles = [];
  final List<MapEntry<String, Map<String, dynamic>>> updateEntries = [];
  final List<String> deleteIds = [];

  FakeAttachmentRecordService() : super(PocketBase('http://fake'), 'fake');

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
    if (onGetList != null) {
      return onGetList!(
        filter: filter,
        sort: sort,
        perPage: perPage,
        page: page,
      );
    }
    return ResultList<RecordModel>(
      page: 1,
      perPage: perPage,
      totalItems: 0,
      totalPages: 0,
      items: [],
    );
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
    createFiles.add(List<http.MultipartFile>.from(files));
    if (onCreate != null) return onCreate!(body, files);
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
    createFiles.clear();
    updateEntries.clear();
    deleteIds.clear();
  }
}

// ══════════════════════════════════════════════════════════════════
// FAKE: PocketBase Client
// ══════════════════════════════════════════════════════════════════

class FakePocketBaseForAttachment extends PocketBase {
  final FakeAttachmentRecordService fakeRecordService;

  FakePocketBaseForAttachment(this.fakeRecordService)
      : super('http://fake-pb.test');

  @override
  RecordService collection(String collectionIdOrName) {
    return fakeRecordService;
  }
}

// ══════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════

/// Erstellt einen RecordModel der wie ein PocketBase-Attachment-Record aussieht.
RecordModel makeAttachmentRecord({
  required String id,
  String artikelUuid = 'artikel-uuid-001',
  String datei = 'rechnung_abc123.pdf',
  String bezeichnung = 'Rechnung',
  String? beschreibung,
  String? mimeType = 'application/pdf',
  int dateiGroesse = 1024,
  int sortOrder = 0,
  String created = '2026-01-15 10:30:00.000Z',
  String updated = '2026-01-15 10:30:00.000Z',
}) {
  final json = <String, dynamic>{
    'id': id,
    'artikel_uuid': artikelUuid,
    'datei': datei,
    'bezeichnung': bezeichnung,
    if (beschreibung != null) 'beschreibung': beschreibung,
    if (mimeType != null) 'mime_type': mimeType,
    'datei_groesse': dateiGroesse,
    'sort_order': sortOrder,
    'created': created,
    'updated': updated,
  };
  return RecordModel.fromJson(json);
}

/// Baut eine ResultList aus einer Liste von RecordModels.
ResultList<RecordModel> makeResultList(
  List<RecordModel> items, {
  int? totalItems,
}) {
  return ResultList<RecordModel>(
    page: 1,
    perPage: 30,
    totalItems: totalItems ?? items.length,
    totalPages: 1,
    items: items,
  );
}

/// Erzeugt eine ClientException (PocketBase SDK hat keinen message-Parameter).
ClientException fakeClientException(String description, {int statusCode = 0}) {
  return ClientException(
    originalError: description,
    statusCode: statusCode,
  );
}

// ══════════════════════════════════════════════════════════════════
// TESTS
// ══════════════════════════════════════════════════════════════════

void main() {
  late FakeAttachmentRecordService fakeRecordService;
  late FakePocketBaseForAttachment fakePb;
  late AttachmentService service;

  setUp(() {
    fakeRecordService = FakeAttachmentRecordService();
    fakePb = FakePocketBaseForAttachment(fakeRecordService);

    // Injiziert den Fake-Client in den echten PocketBaseService-Singleton
    PocketBaseService.overrideForTesting(fakePb);

    // AttachmentService ist ein Singleton — nutzt intern PocketBaseService().client
    service = AttachmentService();
  });

  tearDown(() {
    PocketBaseService.dispose();
  });

  // ════════════════════════════════════════════════════════════════
  // getForArtikel()
  // ════════════════════════════════════════════════════════════════

  group('getForArtikel()', () {
    test('gibt leere Liste zurück wenn keine Anhänge vorhanden', () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        return makeResultList([]);
      };

      final result = await service.getForArtikel('artikel-uuid-leer');

      expect(result, isEmpty);
      expect(fakeRecordService.getListFilters, hasLength(1));
      expect(
        fakeRecordService.getListFilters.first,
        contains('artikel-uuid-leer'),
      );
    });

    test('gibt Liste mit 3 AttachmentModels zurück', () async {
      final records = [
        makeAttachmentRecord(
          id: 'att-001',
          bezeichnung: 'Rechnung',
          datei: 'rechnung.pdf',
          sortOrder: 0,
        ),
        makeAttachmentRecord(
          id: 'att-002',
          bezeichnung: 'Lieferschein',
          datei: 'lieferschein.pdf',
          sortOrder: 1,
        ),
        makeAttachmentRecord(
          id: 'att-003',
          bezeichnung: 'Foto',
          datei: 'foto.jpg',
          mimeType: 'image/jpeg',
          sortOrder: 2,
        ),
      ];

      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        return makeResultList(records);
      };

      final result = await service.getForArtikel('artikel-uuid-001');

      expect(result, hasLength(3));
      expect(result[0].id, 'att-001');
      expect(result[0].bezeichnung, 'Rechnung');
      expect(result[1].id, 'att-002');
      expect(result[1].bezeichnung, 'Lieferschein');
      expect(result[2].id, 'att-003');
      expect(result[2].mimeType, 'image/jpeg');
    });

    test('setzt korrekten Filter mit artikelUuid', () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        expect(filter, contains('artikel_uuid'));
        expect(filter, contains('test-uuid-filter'));
        return makeResultList([]);
      };

      await service.getForArtikel('test-uuid-filter');

      expect(fakeRecordService.getListFilters, hasLength(1));
    });

    test('setzt perPage auf kMaxAttachmentsPerArtikel', () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        expect(perPage, kMaxAttachmentsPerArtikel);
        return makeResultList([]);
      };

      await service.getForArtikel('artikel-uuid-limit');
    });

    test('gibt leere Liste zurück bei PocketBase-Fehler', () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        throw fakeClientException('Connection refused');
      };

      final result = await service.getForArtikel('artikel-uuid-error');

      expect(result, isEmpty);
    });

    test('behandelt Record ohne datei-Feld graceful', () async {
      final record = RecordModel.fromJson(<String, dynamic>{
        'id': 'att-no-datei',
        'artikel_uuid': 'uuid-test',
        'bezeichnung': 'Ohne Datei',
        'created': '2026-01-15 10:30:00.000Z',
      });

      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        return makeResultList([record]);
      };

      final result = await service.getForArtikel('uuid-test');

      expect(result, hasLength(1));
      expect(result.first.dateiName, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // countForArtikel()
  // ════════════════════════════════════════════════════════════════

  group('countForArtikel()', () {
    test('gibt 0 zurück wenn keine Anhänge vorhanden', () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        return makeResultList([], totalItems: 0);
      };

      final count = await service.countForArtikel('uuid-leer');

      expect(count, 0);
    });

    test('gibt korrekte Anzahl zurück', () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        return makeResultList(
          [makeAttachmentRecord(id: 'att-1')],
          totalItems: 7,
        );
      };

      final count = await service.countForArtikel('uuid-sieben');

      expect(count, 7);
    });

    test('gibt 0 zurück bei PocketBase-Fehler', () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        throw fakeClientException('Timeout');
      };

      final count = await service.countForArtikel('uuid-error');

      expect(count, 0);
    });

    test('verwendet perPage=1 und page=1 für effizienten COUNT', () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        expect(perPage, 1);
        expect(page, 1);
        return makeResultList([], totalItems: 5);
      };

      await service.countForArtikel('uuid-efficient');
    });
  });

  // ════════════════════════════════════════════════════════════════
  // upload()
  // ════════════════════════════════════════════════════════════════

  group('upload()', () {
    test('erstellt Anhang bei gültiger Datei', () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        return makeResultList([], totalItems: 0);
      };

      fakeRecordService.onCreate = (body, files) async {
        return makeAttachmentRecord(
          id: 'att-new-001',
          artikelUuid: body['artikel_uuid'] as String,
          bezeichnung: body['bezeichnung'] as String,
          datei: 'rechnung_uploaded.pdf',
          dateiGroesse: 5000,
          mimeType: 'application/pdf',
        );
      };

      final result = await service.upload(
        artikelUuid: 'artikel-uuid-upload',
        bytes: List<int>.filled(5000, 0),
        dateiName: 'rechnung.pdf',
        bezeichnung: 'Rechnung Q1',
        beschreibung: 'Quartalsbericht',
        mimeType: 'application/pdf',
      );

      expect(result, isNotNull);
      expect(result!.id, 'att-new-001');
      expect(result.bezeichnung, 'Rechnung Q1');
      expect(fakeRecordService.createBodies, hasLength(1));
      expect(fakeRecordService.createFiles, hasLength(1));
      expect(fakeRecordService.createFiles.first, hasLength(1));
    });

    test('sendet korrekte Body-Felder an PocketBase', () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        return makeResultList([], totalItems: 2);
      };

      fakeRecordService.onCreate = (body, files) async {
        return makeAttachmentRecord(id: 'att-body-check');
      };

      await service.upload(
        artikelUuid: 'uuid-body-test',
        bytes: [1, 2, 3, 4, 5],
        dateiName: 'test.pdf',
        bezeichnung: '  Bezeichnung mit Spaces  ',
        beschreibung: '  Beschreibung  ',
        mimeType: 'application/pdf',
      );

      final body = fakeRecordService.createBodies.first;
      expect(body['artikel_uuid'], 'uuid-body-test');
      expect(body['bezeichnung'], 'Bezeichnung mit Spaces'); // trimmed
      expect(body['beschreibung'], 'Beschreibung'); // trimmed
      expect(body['mime_type'], 'application/pdf');
      expect(body['datei_groesse'], 5);
      expect(body['sort_order'], 2); // count war 2
      expect(body['uuid'], isNotNull);
      expect(body['uuid'], isNotEmpty);
    });

    test('gibt null zurück wenn Limit erreicht (kMaxAttachmentsPerArtikel)',
        () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        return makeResultList([], totalItems: kMaxAttachmentsPerArtikel);
      };

      final result = await service.upload(
        artikelUuid: 'uuid-limit-reached',
        bytes: [1, 2, 3],
        dateiName: 'overflow.pdf',
        bezeichnung: 'Zu viel',
        mimeType: 'application/pdf',
      );

      expect(result, isNull);
      expect(fakeRecordService.createBodies, isEmpty);
    });

    test('gibt null zurück wenn Limit überschritten', () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        return makeResultList([], totalItems: kMaxAttachmentsPerArtikel + 5);
      };

      final result = await service.upload(
        artikelUuid: 'uuid-over-limit',
        bytes: [1, 2, 3],
        dateiName: 'too-many.pdf',
        bezeichnung: 'Überschritten',
      );

      expect(result, isNull);
      expect(fakeRecordService.createBodies, isEmpty);
    });

    test('gibt null zurück bei PocketBase-Fehler während create', () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        return makeResultList([], totalItems: 0);
      };

      fakeRecordService.onCreate = (body, files) async {
        throw fakeClientException('Server Error', statusCode: 500);
      };

      final result = await service.upload(
        artikelUuid: 'uuid-create-error',
        bytes: [1, 2, 3],
        dateiName: 'error.pdf',
        bezeichnung: 'Fehler',
      );

      expect(result, isNull);
    });

    test('crasht nicht bei PocketBase-Fehler während countForArtikel',
        () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        throw fakeClientException('Network Error');
      };

      // countForArtikel fängt den Fehler ab und gibt 0 zurück,
      // dann wird create aufgerufen — was ebenfalls fehlschlägt
      // weil onGetList immer wirft. Wichtig: Kein Crash!
      await service.upload(
        artikelUuid: 'uuid-count-error',
        bytes: [1, 2, 3],
        dateiName: 'error.pdf',
        bezeichnung: 'Count Fehler',
      );

      // Kein Crash = Erfolg. Ergebnis kann null oder Model sein,
      // je nachdem ob create den Default-Handler nutzt.
      expect(true, isTrue);
    });

    test('lässt beschreibung weg wenn null', () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        return makeResultList([], totalItems: 0);
      };

      fakeRecordService.onCreate = (body, files) async {
        return makeAttachmentRecord(id: 'att-no-desc');
      };

      await service.upload(
        artikelUuid: 'uuid-no-desc',
        bytes: [1, 2, 3],
        dateiName: 'test.pdf',
        bezeichnung: 'Ohne Beschreibung',
        beschreibung: null,
      );

      final body = fakeRecordService.createBodies.first;
      expect(body.containsKey('beschreibung'), isFalse);
    });

    test('lässt beschreibung weg wenn nur Whitespace', () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        return makeResultList([], totalItems: 0);
      };

      fakeRecordService.onCreate = (body, files) async {
        return makeAttachmentRecord(id: 'att-empty-desc');
      };

      await service.upload(
        artikelUuid: 'uuid-whitespace-desc',
        bytes: [1, 2, 3],
        dateiName: 'test.pdf',
        bezeichnung: 'Whitespace Desc',
        beschreibung: '   ',
      );

      final body = fakeRecordService.createBodies.first;
      expect(body.containsKey('beschreibung'), isFalse);
    });

    test('lässt mimeType weg wenn null', () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        return makeResultList([], totalItems: 0);
      };

      fakeRecordService.onCreate = (body, files) async {
        return makeAttachmentRecord(id: 'att-no-mime');
      };

      await service.upload(
        artikelUuid: 'uuid-no-mime',
        bytes: [1, 2, 3],
        dateiName: 'unknown.bin',
        bezeichnung: 'Ohne MIME',
        mimeType: null,
      );

      final body = fakeRecordService.createBodies.first;
      expect(body.containsKey('mime_type'), isFalse);
    });

    test('MultipartFile hat korrekten Feldnamen und Dateinamen', () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        return makeResultList([], totalItems: 0);
      };

      fakeRecordService.onCreate = (body, files) async {
        expect(files, hasLength(1));
        expect(files.first.field, 'datei');
        expect(files.first.filename, 'mein_dokument.pdf');
        return makeAttachmentRecord(id: 'att-filename');
      };

      await service.upload(
        artikelUuid: 'uuid-filename',
        bytes: [0xFF, 0xD8, 0xFF, 0xD9],
        dateiName: 'mein_dokument.pdf',
        bezeichnung: 'Dokument',
      );
    });
  });

  // ════════════════════════════════════════════════════════════════
  // updateMetadata()
  // ════════════════════════════════════════════════════════════════

  group('updateMetadata()', () {
    test('gibt true zurück bei erfolgreichem Update', () async {
      fakeRecordService.onUpdate = (id, body) async {
        return makeAttachmentRecord(id: id, bezeichnung: 'Aktualisiert');
      };

      final result = await service.updateMetadata(
        attachmentId: 'att-update-001',
        bezeichnung: 'Neue Bezeichnung',
        beschreibung: 'Neue Beschreibung',
      );

      expect(result, isTrue);
      expect(fakeRecordService.updateEntries, hasLength(1));
      expect(fakeRecordService.updateEntries.first.key, 'att-update-001');
    });

    test('sendet getrimmte Werte', () async {
      fakeRecordService.onUpdate = (id, body) async {
        return makeAttachmentRecord(id: id);
      };

      await service.updateMetadata(
        attachmentId: 'att-trim',
        bezeichnung: '  Spaces vorne und hinten  ',
        beschreibung: '  Auch hier  ',
      );

      final body = fakeRecordService.updateEntries.first.value;
      expect(body['bezeichnung'], 'Spaces vorne und hinten');
      expect(body['beschreibung'], 'Auch hier');
    });

    test('sendet leeren String wenn beschreibung null', () async {
      fakeRecordService.onUpdate = (id, body) async {
        return makeAttachmentRecord(id: id);
      };

      await service.updateMetadata(
        attachmentId: 'att-null-desc',
        bezeichnung: 'Test',
        beschreibung: null,
      );

      final body = fakeRecordService.updateEntries.first.value;
      expect(body['beschreibung'], '');
    });

    test('gibt false zurück bei PocketBase-Fehler', () async {
      fakeRecordService.onUpdate = (id, body) async {
        throw fakeClientException('Not Found', statusCode: 404);
      };

      final result = await service.updateMetadata(
        attachmentId: 'att-not-found',
        bezeichnung: 'Egal',
      );

      expect(result, isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // delete()
  // ════════════════════════════════════════════════════════════════

  group('delete()', () {
    test('gibt true zurück bei erfolgreichem Delete', () async {
      final result = await service.delete('att-delete-001');

      expect(result, isTrue);
      expect(fakeRecordService.deleteIds, contains('att-delete-001'));
    });

    test('ruft PocketBase delete() mit korrekter ID auf', () async {
      await service.delete('att-specific-id');

      expect(fakeRecordService.deleteIds, hasLength(1));
      expect(fakeRecordService.deleteIds.first, 'att-specific-id');
    });

    test('gibt false zurück bei PocketBase-Fehler', () async {
      fakeRecordService.onDelete = (id) async {
        throw fakeClientException('Record not found', statusCode: 404);
      };

      final result = await service.delete('att-not-existing');

      expect(result, isFalse);
    });

    test('gibt false zurück bei Netzwerkfehler', () async {
      fakeRecordService.onDelete = (id) async {
        throw fakeClientException('Connection refused');
      };

      final result = await service.delete('att-network-error');

      expect(result, isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // deleteAllForArtikel()
  // ════════════════════════════════════════════════════════════════

  group('deleteAllForArtikel()', () {
    test('löscht alle Anhänge und gibt Anzahl zurück', () async {
      final records = [
        makeAttachmentRecord(id: 'att-del-1', sortOrder: 0),
        makeAttachmentRecord(id: 'att-del-2', sortOrder: 1),
        makeAttachmentRecord(id: 'att-del-3', sortOrder: 2),
      ];

      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        return makeResultList(records);
      };

      final deleted = await service.deleteAllForArtikel('uuid-delete-all');

      expect(deleted, 3);
      expect(fakeRecordService.deleteIds, hasLength(3));
      expect(fakeRecordService.deleteIds, contains('att-del-1'));
      expect(fakeRecordService.deleteIds, contains('att-del-2'));
      expect(fakeRecordService.deleteIds, contains('att-del-3'));
    });

    test('gibt 0 zurück wenn keine Anhänge vorhanden', () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        return makeResultList([]);
      };

      final deleted = await service.deleteAllForArtikel('uuid-empty');

      expect(deleted, 0);
      expect(fakeRecordService.deleteIds, isEmpty);
    });

    test('zählt nur erfolgreich gelöschte Anhänge', () async {
      final records = [
        makeAttachmentRecord(id: 'att-ok-1'),
        makeAttachmentRecord(id: 'att-fail'),
        makeAttachmentRecord(id: 'att-ok-2'),
      ];

      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        return makeResultList(records);
      };

      fakeRecordService.onDelete = (id) async {
        if (id == 'att-fail') {
          throw fakeClientException('Delete failed', statusCode: 500);
        }
      };

      final deleted = await service.deleteAllForArtikel('uuid-partial');

      expect(deleted, 2);
    });

    test('gibt 0 zurück bei Fehler in getForArtikel', () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        throw fakeClientException('Server down');
      };

      final deleted = await service.deleteAllForArtikel('uuid-get-error');

      expect(deleted, 0);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // Integrations-Szenarien
  // ════════════════════════════════════════════════════════════════

  group('Integrations-Szenarien', () {
    test('Upload → getForArtikel zeigt neuen Anhang', () async {
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        // countForArtikel: perPage=1
        if (perPage == 1) return makeResultList([], totalItems: 0);
        // getForArtikel: nach Upload 1 Anhang
        return makeResultList([
          makeAttachmentRecord(
            id: 'att-integrated',
            bezeichnung: 'Integrationstest',
            datei: 'test.pdf',
          ),
        ]);
      };

      fakeRecordService.onCreate = (body, files) async {
        return makeAttachmentRecord(
          id: 'att-integrated',
          bezeichnung: body['bezeichnung'] as String,
        );
      };

      final uploaded = await service.upload(
        artikelUuid: 'uuid-integration',
        bytes: [1, 2, 3],
        dateiName: 'test.pdf',
        bezeichnung: 'Integrationstest',
      );

      expect(uploaded, isNotNull);

      // Phase 2: Abrufen
      final attachments = await service.getForArtikel('uuid-integration');

      expect(attachments, hasLength(1));
      expect(attachments.first.bezeichnung, 'Integrationstest');
    });

    test('Upload bei Limit=19 gelingt, bei Limit=20 scheitert', () async {
      // Test 1: 19 vorhanden → Upload OK
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        return makeResultList([], totalItems: 19);
      };

      fakeRecordService.onCreate = (body, files) async {
        return makeAttachmentRecord(id: 'att-19');
      };

      final result19 = await service.upload(
        artikelUuid: 'uuid-limit-19',
        bytes: [1],
        dateiName: 'ok.pdf',
        bezeichnung: 'Noch Platz',
      );

      expect(result19, isNotNull);

      // Reset für nächsten Test
      fakeRecordService.reset();

      // Test 2: 20 vorhanden → Upload abgelehnt
      fakeRecordService.onGetList = ({filter, sort, perPage, page}) async {
        return makeResultList([], totalItems: 20);
      };

      final result20 = await service.upload(
        artikelUuid: 'uuid-limit-20',
        bytes: [1],
        dateiName: 'nope.pdf',
        bezeichnung: 'Kein Platz',
      );

      expect(result20, isNull);
      expect(fakeRecordService.createBodies, isEmpty);
    });
  });
}