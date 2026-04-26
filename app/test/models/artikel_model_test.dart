// test/models/artikel_model_test.dart
//
// O-002: Unit-Tests für Artikel
//
// Testet:
//   - Konstruktor: Pflichtfelder, Auto-UUID, Auto-updatedAt
//   - isValid(): Gültige und ungültige Kombinationen
//   - toMap(): Alle Felder, bool→int, id-Conditional
//   - fromMap(): Normalfall, Null-Handling, Typ-Koercion,
//                snake_case ↔ camelCase Fallbacks, UTC-Normalisierung
//   - Roundtrip: fromMap() → toMap() → fromMap()
//   - copyWith(): Nullable Felder via _Undefined-Sentinel
//   - ==, hashCode, toString()

import 'package:flutter_test/flutter_test.dart';
import 'package:lager_app/models/artikel_model.dart';
import 'package:lager_app/utils/uuid_generator.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

// ✅ FIX: final statt const — aber NICHT als Default-Parameter verwenden
final _fixedDate = DateTime.utc(2025, 1, 15, 10, 30, 0);
final _fixedDateStr = '2025-01-15T10:30:00.000Z';

// ✅ Getter statt Variable — wird bei jedem Zugriff neu berechnet,
//    aber immer deterministisch (basiert auf _fixedDate)
int get _fixedMillis => _fixedDate.millisecondsSinceEpoch;

// ✅ const ist erlaubt als Default-Parameter
const _fixedUuid = '550e8400-e29b-41d4-a716-446655440000';

/// Erstellt einen vollständigen, gültigen Artikel für Tests.
///
/// FIX: updatedAt und uuid nutzen null als Sentinel statt
/// non-const Expressions als Default-Werte.
/// - updatedAt: null  → _fixedMillis wird im Body gesetzt
/// - updatedAt: -1    → null wird durchgereicht (Konstruktor-Default greift)
/// - uuid: null       → Konstruktor generiert neue UUID
Artikel _makeArtikel({
  int? id = 1,
  String name = 'Widerstand 10kΩ',
  int? artikelnummer = 1001,
  int menge = 50,
  String ort = 'Regal A',
  String fach = 'Fach 3',
  String beschreibung = 'SMD 0805',
  String bildPfad = '/images/r10k.jpg',
  String? thumbnailPfad = '/images/r10k_thumb.jpg',
  String? thumbnailEtag,
  String? remoteBildPfad,
  String? uuid = _fixedUuid,
  int? updatedAt = -1,
  bool deleted = false,
  String? etag,
  String? lastSyncedEtag,
  String? pendingResolution,
  String? remotePath,
  String? deviceId,
}) {
  final resolvedUpdatedAt = updatedAt == -1 ? _fixedMillis : updatedAt;

  return Artikel(
    id: id,
    name: name,
    artikelnummer: artikelnummer,
    menge: menge,
    ort: ort,
    fach: fach,
    beschreibung: beschreibung,
    bildPfad: bildPfad,
    thumbnailPfad: thumbnailPfad,
    thumbnailEtag: thumbnailEtag,
    erstelltAm: _fixedDate,
    aktualisiertAm: _fixedDate,
    remoteBildPfad: remoteBildPfad,
    uuid: uuid,
    updatedAt: resolvedUpdatedAt,
    deleted: deleted,
    etag: etag,
    lastSyncedEtag: lastSyncedEtag,
    pendingResolution: pendingResolution,
    remotePath: remotePath,
    deviceId: deviceId,
  );
}

/// Erstellt eine vollständige SQLite-Map (snake_case).
Map<String, dynamic> _makeMap({
  dynamic id = 1,
  String name = 'Kondensator 100nF',
  dynamic artikelnummer = 1002,
  dynamic menge = 25,
  String ort = 'Regal B',
  String fach = 'Fach 1',
  String beschreibung = 'Keramik X7R',
  String bildPfad = '/images/c100n.jpg',
  String? thumbnailPfad = '/images/c100n_thumb.jpg',
  String? thumbnailEtag,
  // ✅ const String ist erlaubt als Default
  String erstelltAm = '2025-01-15T10:30:00.000Z',
  String aktualisiertAm = '2025-01-15T10:30:00.000Z',
  String? remoteBildPfad,
  String uuid = _fixedUuid,
  // ✅ FIX: Sentinel -1 = "nutze _fixedMillis"
  dynamic updatedAt = -1,
  dynamic deleted = 0,
  String? etag,
  String? lastSyncedEtag,
  String? pendingResolution,
  String? remotePath,
  String? deviceId,

}) {
  // ✅ Sentinel auflösen im Body
  final resolvedUpdatedAt = updatedAt == -1 ? _fixedMillis : updatedAt;

  return {
    'id': id,
    'name': name,
    'artikelnummer': artikelnummer,
    'menge': menge,
    'ort': ort,
    'fach': fach,
    'beschreibung': beschreibung,
    'bildPfad': bildPfad,
    'thumbnailPfad': thumbnailPfad,
    'thumbnailEtag': thumbnailEtag,
    'erstelltAm': erstelltAm,
    'aktualisiertAm': aktualisiertAm,
    'remoteBildPfad': remoteBildPfad,
    'uuid': uuid,
    'updated_at': resolvedUpdatedAt,
    'deleted': deleted,
    'etag': etag,
    'last_synced_etag': lastSyncedEtag,
    'pending_resolution': pendingResolution,    
    'remote_path': remotePath,
    'device_id': deviceId,

  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Artikel Model Tests', () {
    // =======================================================================
    // Konstruktor
    // =======================================================================
    group('Konstruktor', () {
      test('should create valid Artikel with all required fields', () {
        final artikel = _makeArtikel();

        expect(artikel.name, equals('Widerstand 10kΩ'));
        expect(artikel.menge, equals(50));
        expect(artikel.ort, equals('Regal A'));
        expect(artikel.fach, equals('Fach 3'));
        expect(artikel.deleted, isFalse);
      });

      test('generiert UUID automatisch wenn keine übergeben wird', () {
        final artikel = _makeArtikel(uuid: null);

        expect(artikel.uuid, isNotEmpty);
        expect(UuidGenerator.isValidV4(artikel.uuid), isTrue);
      });

      test('nutzt übergebene UUID wenn vorhanden', () {
        final artikel = _makeArtikel(uuid: _fixedUuid);
        expect(artikel.uuid, equals(_fixedUuid));
      });

      test('setzt updatedAt automatisch auf UTC-Millisekunden wenn null', () {
        // ✅ Sentinel null → Konstruktor-Default (DateTime.now().toUtc()) greift
        final before = DateTime.now().toUtc().millisecondsSinceEpoch;
        final artikel = _makeArtikel(updatedAt: null);
        final after = DateTime.now().toUtc().millisecondsSinceEpoch;

        expect(artikel.updatedAt, greaterThanOrEqualTo(before));
        expect(artikel.updatedAt, lessThanOrEqualTo(after));
      });

      test('optionale Felder sind null wenn nicht gesetzt', () {
        final artikel = _makeArtikel(
          id: null,
          artikelnummer: null,
          thumbnailPfad: null,
          thumbnailEtag: null,
          remoteBildPfad: null,
          etag: null,
          lastSyncedEtag: null,
          pendingResolution: null,
          remotePath: null,
          deviceId: null,
        );

        expect(artikel.id, isNull);
        expect(artikel.artikelnummer, isNull);
        expect(artikel.thumbnailPfad, isNull);
        expect(artikel.thumbnailEtag, isNull);
        expect(artikel.remoteBildPfad, isNull);
        expect(artikel.etag, isNull);
        expect(artikel.lastSyncedEtag, isNull);
        expect(artikel.pendingResolution, isNull);
        expect(artikel.remotePath, isNull);
        expect(artikel.deviceId, isNull);
      });

      test('setzt neue Sync-Felder wenn angegeben', () {
        final artikel = _makeArtikel(
          etag: 'etag-1',
          lastSyncedEtag: 'etag-0',
          pendingResolution: 'force_local',
        );

        expect(artikel.etag, equals('etag-1'));
        expect(artikel.lastSyncedEtag, equals('etag-0'));
        expect(artikel.pendingResolution, equals('force_local'));
      });
    });

    // =======================================================================
    // isValid()
    // =======================================================================
    group('isValid()', () {
      test('isValid should return true for valid artikel', () {
        expect(_makeArtikel().isValid(), isTrue);
      });

      test('isValid should return false for empty required fields', () {
        expect(_makeArtikel(name: '', ort: '').isValid(), isFalse);
      });

      test('gibt false zurück wenn name nur Whitespace enthält', () {
        expect(_makeArtikel(name: '   ').isValid(), isFalse);
      });

      test('gibt false zurück wenn ort nur Whitespace enthält', () {
        expect(_makeArtikel(ort: '   ').isValid(), isFalse);
      });

      test('gibt false zurück wenn fach leer ist', () {
        expect(_makeArtikel(fach: '').isValid(), isFalse);
      });

      test('gibt false zurück wenn menge negativ ist', () {
        expect(_makeArtikel(menge: -1).isValid(), isFalse);
      });

      test('gibt true zurück wenn menge 0 ist (Grenzwert)', () {
        // ✅ menge >= 0 laut isValid() — 0 ist erlaubt
        expect(_makeArtikel(menge: 0).isValid(), isTrue);
      });

      test('gibt true zurück wenn menge maximal ist (999999)', () {
        expect(_makeArtikel(menge: 999999).isValid(), isTrue);
      });

      test('gibt true zurück wenn beschreibung leer ist (optional)', () {
        expect(_makeArtikel(beschreibung: '').isValid(), isTrue);
      });

      test('gibt true zurück wenn bildPfad leer ist (optional)', () {
        expect(_makeArtikel(bildPfad: '').isValid(), isTrue);
      });
    });

    // =======================================================================
    // toMap()
    // =======================================================================
    group('toMap()', () {
      test('toMap should contain all required fields', () {
        final map = _makeArtikel(id: 42, uuid: 'map-test-uuid').toMap();

        expect(map['id'], equals(42));
        expect(map['name'], equals('Widerstand 10kΩ'));
        expect(map['menge'], equals(50));
        expect(map['ort'], equals('Regal A'));
        expect(map['fach'], equals('Fach 3'));
        expect(map['uuid'], equals('map-test-uuid'));
        expect(map['deleted'], equals(0));
      });

      test('serialisiert deleted=true als int 1', () {
        expect(_makeArtikel(deleted: true).toMap()['deleted'], equals(1));
      });

      test('serialisiert deleted=false als int 0', () {
        expect(_makeArtikel(deleted: false).toMap()['deleted'], equals(0));
      });

      test('enthält id-Key nur wenn id nicht null ist', () {
        final mapMitId = _makeArtikel(id: 5).toMap();
        final mapOhneId = _makeArtikel(id: null).toMap();

        expect(mapMitId.containsKey('id'), isTrue);
        expect(mapMitId['id'], equals(5));
        expect(mapOhneId.containsKey('id'), isFalse);
      });

      test('serialisiert erstelltAm als UTC ISO-8601 String (FIX #8)', () {
        final map = _makeArtikel().toMap();
        final parsed = DateTime.parse(map['erstelltAm'] as String);
        expect(parsed.isUtc, isTrue);
        expect(parsed.year, equals(2025));
        expect(parsed.month, equals(1));
        expect(parsed.day, equals(15));
      });

      test('serialisiert aktualisiertAm als UTC ISO-8601 String (FIX #8)', () {
        final parsed = DateTime.parse(
          _makeArtikel().toMap()['aktualisiertAm'] as String,
        );
        expect(parsed.isUtc, isTrue);
      });

      test('serialisiert null-Felder korrekt als null', () {
        final map = _makeArtikel(
          artikelnummer: null,
          thumbnailPfad: null,
          remoteBildPfad: null,
          etag: null,
          remotePath: null,
          deviceId: null,
        ).toMap();

        expect(map['artikelnummer'], isNull);
        expect(map['thumbnailPfad'], isNull);
        expect(map['remoteBildPfad'], isNull);
        expect(map['etag'], isNull);
        expect(map['remote_path'], isNull);
        expect(map['device_id'], isNull);
      });

      test('nutzt snake_case Keys für SQLite-Felder', () {
        final map = _makeArtikel().toMap();

        expect(map.containsKey('updated_at'), isTrue);
        expect(map.containsKey('remote_path'), isTrue);
        expect(map.containsKey('device_id'), isTrue);
        expect(map.containsKey('updatedAt'), isFalse);
        expect(map.containsKey('remotePath'), isFalse);
        expect(map.containsKey('deviceId'), isFalse);
        expect(map.containsKey('last_synced_etag'), isTrue);
        expect(map.containsKey('pending_resolution'), isTrue);
        expect(map.containsKey('lastSyncedEtag'), isFalse);
        expect(map.containsKey('pendingResolution'), isFalse);
      });
      test('serialisiert lastSyncedEtag und pendingResolution in snake_case', () {
        final map = _makeArtikel(
          lastSyncedEtag: 'etag-base',
          pendingResolution: 'force_merge',
        ).toMap();

        expect(map['last_synced_etag'], equals('etag-base'));
        expect(map['pending_resolution'], equals('force_merge'));
      });

      test('serialisiert neue Sync-Felder als null wenn nicht gesetzt', () {
        final map = _makeArtikel(
          lastSyncedEtag: null,
          pendingResolution: null,
        ).toMap();

        expect(map['last_synced_etag'], isNull);
        expect(map['pending_resolution'], isNull);
      });

    });

    // =======================================================================
    // toPocketBaseMap()
    // =======================================================================
    group('toPocketBaseMap()', () {
      test('enthält die bewusst freigegebenen PB-Felder', () {
        final map = _makeArtikel(
          deviceId: 'dev-1',
          updatedAt: 123456789,
          etag: 'etag-local',
          lastSyncedEtag: 'etag-base',
          pendingResolution: 'force_local',
          remotePath: 'rec_local',
        ).toPocketBaseMap();

        expect(map['device_id'], equals('dev-1'));
        expect(map['updated_at'], equals(123456789));

        expect(map.containsKey('etag'), isFalse);
        expect(map.containsKey('last_synced_etag'), isFalse);
        expect(map.containsKey('pending_resolution'), isFalse);
        expect(map.containsKey('remote_path'), isFalse);
      });
    });

    // =======================================================================
    // fromMap()
    // =======================================================================
    group('fromMap()', () {
      test('fromMap should recreate Artikel correctly', () {
        // ✅ _makeMap() Default uuid = _fixedUuid
        final artikel = Artikel.fromMap(_makeMap());

        expect(artikel.id, equals(1));
        expect(artikel.name, equals('Kondensator 100nF'));
        expect(artikel.menge, equals(25));
        expect(artikel.ort, equals('Regal B'));
        expect(artikel.fach, equals('Fach 1'));
        expect(artikel.uuid, equals(_fixedUuid));
        expect(artikel.deleted, isFalse);
        expect(artikel.updatedAt, equals(_fixedMillis));
      });

      test('parst id als String korrekt zu int (Typ-Koercion)', () {
        expect(Artikel.fromMap(_makeMap(id: '42')).id, equals(42));
      });

      test('parst menge als String korrekt zu int', () {
        expect(Artikel.fromMap(_makeMap(menge: '15')).menge, equals(15));
      });

      test('setzt menge auf 0 wenn Wert nicht parsbar ist', () {
        expect(Artikel.fromMap(_makeMap(menge: 'ungültig')).menge, equals(0));
      });

      test('parst deleted=1 (SQLite int) als true', () {
        expect(Artikel.fromMap(_makeMap(deleted: 1)).deleted, isTrue);
      });

      test('parst deleted=true (PocketBase bool) als true', () {
        expect(Artikel.fromMap(_makeMap(deleted: true)).deleted, isTrue);
      });

      test('parst deleted=0 als false', () {
        expect(Artikel.fromMap(_makeMap(deleted: 0)).deleted, isFalse);
      });

      test('parst erstelltAm immer als UTC (FIX #8)', () {
        final artikel = Artikel.fromMap(_makeMap(erstelltAm: _fixedDateStr));
        expect(artikel.erstelltAm.isUtc, isTrue);
        expect(artikel.erstelltAm.year, equals(2025));
        expect(artikel.erstelltAm.month, equals(1));
        expect(artikel.erstelltAm.day, equals(15));
      });

      test('liest last_synced_etag und pending_resolution aus SQLite-Map', () {
        final artikel = Artikel.fromMap(
          _makeMap(
            lastSyncedEtag: 'etag-base',
            pendingResolution: 'force_local',
          ),
        );

        expect(artikel.lastSyncedEtag, equals('etag-base'));
        expect(artikel.pendingResolution, equals('force_local'));
      });      

    // =======================================================================
    // fromPocketBase()
    // =======================================================================
    group('fromPocketBase()', () {
      test('setzt etag und lastSyncedEtag aus updated', () {
        final artikel = Artikel.fromPocketBase(
          {
            'uuid': _fixedUuid,
            'name': 'Remote Artikel',
            'artikelnummer': 2001,
            'menge': 7,
            'ort': 'Remote Regal',
            'fach': 'Remote Fach',
            'beschreibung': 'Von PocketBase',
            'deleted': false,
            'updated': '2025-02-01T12:00:00.000Z',
            'created': '2025-02-01T11:00:00.000Z',
          },
          'rec_001',
        );

        expect(artikel.etag, equals('2025-02-01T12:00:00.000Z'));
        expect(artikel.lastSyncedEtag, equals('2025-02-01T12:00:00.000Z'));
        expect(artikel.pendingResolution, isNull);
        expect(artikel.remotePath, equals('rec_001'));
      });

      test('fällt auf recordId zurück wenn updated leer ist', () {
        final artikel = Artikel.fromPocketBase(
          {
            'uuid': _fixedUuid,
            'name': 'Remote Artikel',
            'menge': 7,
            'ort': 'Remote Regal',
            'fach': 'Remote Fach',
            'beschreibung': 'Von PocketBase',
            'deleted': false,
            'created': '2025-02-01T11:00:00.000Z',
          },
          'rec_fallback',
        );

        expect(artikel.etag, equals('rec_fallback'));
        expect(artikel.lastSyncedEtag, equals('rec_fallback'));
        expect(artikel.remotePath, equals('rec_fallback'));
      });

      test('übernimmt bild-Feld als remoteBildPfad', () {
        final artikel = Artikel.fromPocketBase(
          {
            'uuid': _fixedUuid,
            'name': 'Remote Artikel',
            'menge': 7,
            'ort': 'Remote Regal',
            'fach': 'Remote Fach',
            'beschreibung': 'Von PocketBase',
            'bild': 'bild_abc123.jpg',
            'created': '2025-02-01T11:00:00.000Z',
            'updated': '2025-02-01T12:00:00.000Z',
          },
          'rec_img',
        );

        expect(artikel.remoteBildPfad, equals('bild_abc123.jpg'));
      });

      test('liest device_id und deviceId robust', () {
        final artikelSnake = Artikel.fromPocketBase(
          {
            'uuid': 'uuid-snake',
            'name': 'Snake',
            'menge': 1,
            'ort': 'A',
            'fach': '1',
            'beschreibung': '',
            'device_id': 'dev-snake',
            'created': '2025-02-01T11:00:00.000Z',
            'updated': '2025-02-01T12:00:00.000Z',
          },
          'rec_snake',
        );

        final artikelCamel = Artikel.fromPocketBase(
          {
            'uuid': 'uuid-camel',
            'name': 'Camel',
            'menge': 1,
            'ort': 'A',
            'fach': '1',
            'beschreibung': '',
            'deviceId': 'dev-camel',
            'created': '2025-02-01T11:00:00.000Z',
            'updated': '2025-02-01T12:00:00.000Z',
          },
          'rec_camel',
        );

        expect(artikelSnake.deviceId, equals('dev-snake'));
        expect(artikelCamel.deviceId, equals('dev-camel'));
      });
    });

      // -----------------------------------------------------------------------
      // Null-Handling
      // -----------------------------------------------------------------------
      group('Null-Handling', () {
        test('setzt name auf leeren String wenn null', () {
          final map = _makeMap()..['name'] = null;
          expect(Artikel.fromMap(map).name, equals(''));
        });

        test('setzt ort auf leeren String wenn null', () {
          final map = _makeMap()..['ort'] = null;
          expect(Artikel.fromMap(map).ort, equals(''));
        });

        test('setzt fach auf leeren String wenn null', () {
          final map = _makeMap()..['fach'] = null;
          expect(Artikel.fromMap(map).fach, equals(''));
        });

        test('setzt beschreibung auf leeren String wenn null', () {
          final map = _makeMap()..['beschreibung'] = null;
          expect(Artikel.fromMap(map).beschreibung, equals(''));
        });

        test('setzt bildPfad auf leeren String wenn null', () {
          final map = _makeMap()..['bildPfad'] = null;
          expect(Artikel.fromMap(map).bildPfad, equals(''));
        });

        test('lässt artikelnummer null (M-007 Abwärtskompatibilität)', () {
          final map = _makeMap()..['artikelnummer'] = null;
          expect(Artikel.fromMap(map).artikelnummer, isNull);
        });

        test('lässt thumbnailPfad null wenn nicht vorhanden', () {
          expect(
            Artikel.fromMap(_makeMap(thumbnailPfad: null)).thumbnailPfad,
            isNull,
          );
        });

        test('lässt etag null wenn nicht vorhanden', () {
          final map = _makeMap()..['etag'] = null;
          expect(Artikel.fromMap(map).etag, isNull);
        });

        test('generiert neue UUID wenn uuid in Map null ist', () {
          final map = _makeMap()..['uuid'] = null;
          final artikel = Artikel.fromMap(map);
          expect(artikel.uuid, isNotEmpty);
          expect(UuidGenerator.isValidV4(artikel.uuid), isTrue);
        });

        test('setzt updatedAt auf 0 wenn updated_at null ist', () {
          final map = _makeMap()..['updated_at'] = null;
          // ✅ _parseInt(null) → 0
          expect(Artikel.fromMap(map).updatedAt, equals(0));
        });

        test('setzt erstelltAm auf aktuelles UTC-Datum wenn null', () {
          final map = _makeMap()..['erstelltAm'] = null;
          final before = DateTime.now().toUtc();
          final artikel = Artikel.fromMap(map);
          final after = DateTime.now().toUtc();

          expect(
            artikel.erstelltAm.millisecondsSinceEpoch,
            greaterThanOrEqualTo(
              before
                  .subtract(const Duration(seconds: 1))
                  .millisecondsSinceEpoch,
            ),
          );
          expect(
            artikel.erstelltAm.millisecondsSinceEpoch,
            lessThanOrEqualTo(
              after.add(const Duration(seconds: 1)).millisecondsSinceEpoch,
            ),
          );
        });
      });

      // -----------------------------------------------------------------------
      // snake_case ↔ camelCase Fallbacks
      // -----------------------------------------------------------------------
      group('Key-Fallbacks (SQLite snake_case ↔ PocketBase camelCase)', () {
        test('liest remote_path (SQLite snake_case)', () {
          final map = _makeMap()..['remote_path'] = 'pb_record_abc123';
          expect(
            Artikel.fromMap(map).remotePath,
            equals('pb_record_abc123'),
          );
        });

        test('liest remotePath (PocketBase camelCase) als Fallback', () {
          final map = _makeMap();
          map.remove('remote_path');
          map['remotePath'] = 'pb_record_xyz789';
          expect(
            Artikel.fromMap(map).remotePath,
            equals('pb_record_xyz789'),
          );
        });

        test('liest device_id (SQLite snake_case)', () {
          final map = _makeMap()..['device_id'] = 'device-001';
          expect(Artikel.fromMap(map).deviceId, equals('device-001'));
        });

        test('liest deviceId (PocketBase camelCase) als Fallback', () {
          final map = _makeMap();
          map.remove('device_id');
          map['deviceId'] = 'device-002';
          expect(Artikel.fromMap(map).deviceId, equals('device-002'));
        });

        test('liest created (PocketBase) wenn erstelltAm fehlt', () {
          final map = _makeMap();
          map.remove('erstelltAm');
          map['created'] = '2024-03-15T08:30:00.000Z';
          final artikel = Artikel.fromMap(map);
          expect(artikel.erstelltAm.year, equals(2024));
          expect(artikel.erstelltAm.month, equals(3));
          expect(artikel.erstelltAm.day, equals(15));
        });

        test('liest updated (PocketBase) wenn aktualisiertAm fehlt', () {
          final map = _makeMap();
          map.remove('aktualisiertAm');
          map['updated'] = '2024-09-20T16:45:00.000Z';
          final artikel = Artikel.fromMap(map);
          expect(artikel.aktualisiertAm.year, equals(2024));
          expect(artikel.aktualisiertAm.month, equals(9));
          expect(artikel.aktualisiertAm.day, equals(20));
        });
        test('liest lastSyncedEtag (camelCase) als Fallback', () {
          final map = _makeMap();
          map.remove('last_synced_etag');
          map['lastSyncedEtag'] = 'etag-camel';

          expect(
            Artikel.fromMap(map).lastSyncedEtag,
            equals('etag-camel'),
          );
        });

        test('liest pendingResolution (camelCase) als Fallback', () {
          final map = _makeMap();
          map.remove('pending_resolution');
          map['pendingResolution'] = 'force_merge';

          expect(
            Artikel.fromMap(map).pendingResolution,
            equals('force_merge'),
          );
        });
        test('liest updated_at (snake_case) korrekt', () {
          expect(
            Artikel.fromMap(_makeMap(updatedAt: 1705312200000)).updatedAt,
            equals(1705312200000),
          );
        });
      });
    });

    // =======================================================================
    // Roundtrip
    // =======================================================================
    group('Roundtrip fromMap() ↔ toMap()', () {
      test('Artikel bleibt nach Roundtrip identisch (alle Felder)', () {
        final original = _makeArtikel(
          id: 7,
          name: 'LED rot 5mm',
          artikelnummer: 1042,
          menge: 200,
          ort: 'Regal C',
          fach: 'Fach 2',
          beschreibung: 'Vorwärtsspannung 2V',
          bildPfad: '/images/led_rot.jpg',
          thumbnailPfad: '/images/led_rot_thumb.jpg',
          deleted: false,
          etag: 'etag-abc',
          remotePath: 'rec_xyz',
          deviceId: 'dev-001',
        );

        final roundtripped = Artikel.fromMap(original.toMap());

        expect(roundtripped.uuid, equals(original.uuid));
        expect(roundtripped.name, equals(original.name));
        expect(roundtripped.artikelnummer, equals(original.artikelnummer));
        expect(roundtripped.menge, equals(original.menge));
        expect(roundtripped.ort, equals(original.ort));
        expect(roundtripped.fach, equals(original.fach));
        expect(roundtripped.beschreibung, equals(original.beschreibung));
        expect(roundtripped.bildPfad, equals(original.bildPfad));
        expect(roundtripped.thumbnailPfad, equals(original.thumbnailPfad));
        expect(roundtripped.deleted, equals(original.deleted));
        expect(roundtripped.etag, equals(original.etag));
        expect(roundtripped.remotePath, equals(original.remotePath));
        expect(roundtripped.deviceId, equals(original.deviceId));
        expect(roundtripped.updatedAt, equals(original.updatedAt));
        expect(
          roundtripped.erstelltAm.millisecondsSinceEpoch,
          equals(original.erstelltAm.millisecondsSinceEpoch),
        );
        expect(
          roundtripped.aktualisiertAm.millisecondsSinceEpoch,
          equals(original.aktualisiertAm.millisecondsSinceEpoch),
        );
      });

      test('deleted=true überlebt Roundtrip korrekt', () {
        final original = _makeArtikel(deleted: true);
        expect(Artikel.fromMap(original.toMap()).deleted, isTrue);
      });

      test('null-Felder überleben Roundtrip korrekt', () {
        final original = _makeArtikel(
          artikelnummer: null,
          thumbnailPfad: null,
          etag: null,
          remotePath: null,
          deviceId: null,
        );
        final roundtripped = Artikel.fromMap(original.toMap());

        expect(roundtripped.artikelnummer, isNull);
        expect(roundtripped.thumbnailPfad, isNull);
        expect(roundtripped.etag, isNull);
        expect(roundtripped.remotePath, isNull);
        expect(roundtripped.deviceId, isNull);
      });
      test('neue Sync-Felder überleben Roundtrip korrekt', () {
        final original = _makeArtikel(
          etag: 'etag-current',
          lastSyncedEtag: 'etag-base',
          pendingResolution: 'force_local',
          remotePath: 'rec_123',
        );

        final roundtripped = Artikel.fromMap(original.toMap());

        expect(roundtripped.etag, equals('etag-current'));
        expect(roundtripped.lastSyncedEtag, equals('etag-base'));
        expect(roundtripped.pendingResolution, equals('force_local'));
        expect(roundtripped.remotePath, equals('rec_123'));
      });

    });

    // =======================================================================
    // copyWith()
    // =======================================================================
    group('copyWith()', () {
      test('gibt identischen Artikel zurück wenn keine Felder geändert werden', () {
        final original = _makeArtikel();
        final copy = original.copyWith();

        expect(copy.uuid, equals(original.uuid));
        expect(copy.name, equals(original.name));
        expect(copy.menge, equals(original.menge));
        expect(copy.deleted, equals(original.deleted));
      });

      test('ändert nur das angegebene Feld', () {
        final original = _makeArtikel(menge: 10);
        final copy = original.copyWith(menge: 99);

        expect(copy.menge, equals(99));
        expect(copy.uuid, equals(original.uuid));
        expect(copy.name, equals(original.name));
        expect(copy.ort, equals(original.ort));
      });

      test('kann nullable Felder auf null setzen (_Undefined-Sentinel)', () {
        final original = _makeArtikel(etag: 'etag-123', remotePath: 'rec-abc');
        final copy = original.copyWith(etag: null, remotePath: null);

        expect(copy.etag, isNull);
        expect(copy.remotePath, isNull);
        expect(copy.uuid, equals(original.uuid));
      });

      test('kann artikelnummer auf null setzen', () {
        final original = _makeArtikel(artikelnummer: 1001);
        expect(original.copyWith(artikelnummer: null).artikelnummer, isNull);
      });

      test('kann deleted auf true setzen', () {
        final original = _makeArtikel(deleted: false);
        final copy = original.copyWith(deleted: true);

        expect(copy.deleted, isTrue);
        expect(original.deleted, isFalse);
      });

      test('kann thumbnailPfad auf null setzen', () {
        final original = _makeArtikel(thumbnailPfad: '/thumb.jpg');
        expect(original.copyWith(thumbnailPfad: null).thumbnailPfad, isNull);
      });
      test('kann lastSyncedEtag und pendingResolution ändern', () {
        final original = _makeArtikel(
          lastSyncedEtag: 'etag-old',
          pendingResolution: 'force_local',
        );

        final copy = original.copyWith(
          lastSyncedEtag: 'etag-new',
          pendingResolution: 'force_merge',
        );

        expect(copy.lastSyncedEtag, equals('etag-new'));
        expect(copy.pendingResolution, equals('force_merge'));
      });

      test('kann lastSyncedEtag und pendingResolution auf null setzen', () {
        final original = _makeArtikel(
          lastSyncedEtag: 'etag-old',
          pendingResolution: 'force_local',
        );

        final copy = original.copyWith(
          lastSyncedEtag: null,
          pendingResolution: null,
        );

        expect(copy.lastSyncedEtag, isNull);
        expect(copy.pendingResolution, isNull);
      });

    });

    // =======================================================================
    // Equality & hashCode
    // =======================================================================
    group('Equality & hashCode', () {
      test('zwei Artikel mit gleicher UUID sind gleich', () {
        final a = _makeArtikel(uuid: _fixedUuid, name: 'Artikel A');
        final b = _makeArtikel(uuid: _fixedUuid, name: 'Artikel B');
        expect(a, equals(b));
      });

      test('zwei Artikel mit verschiedener UUID sind ungleich', () {
        final a = _makeArtikel(uuid: _fixedUuid);
        final b = _makeArtikel(uuid: null);
        expect(a, isNot(equals(b)));
      });

      test('hashCode ist gleich für gleiche UUID', () {
        final a = _makeArtikel(uuid: _fixedUuid);
        final b = _makeArtikel(uuid: _fixedUuid);
        expect(a.hashCode, equals(b.hashCode));
      });

      test('hashCode ist verschieden für verschiedene UUIDs', () {
        final a = _makeArtikel(uuid: _fixedUuid);
        final b = _makeArtikel(uuid: null);
        expect(a.hashCode, isNot(equals(b.hashCode)));
      });

      test('identical gibt true für dasselbe Objekt zurück', () {
        final artikel = _makeArtikel();
        expect(identical(artikel, artikel), isTrue);
      });
    });

    // =======================================================================
    // toString()
    // =======================================================================
    group('toString()', () {
      test('enthält uuid, name, menge, ort, fach, deleted', () {
        final artikel = _makeArtikel(
          uuid: _fixedUuid,
          name: 'Widerstand',
          menge: 50,
          ort: 'Regal A',
          fach: 'Fach 3',
          deleted: false,
        );
        final str = artikel.toString();

        expect(str, contains(_fixedUuid));
        expect(str, contains('Widerstand'));
        expect(str, contains('50'));
        expect(str, contains('Regal A'));
        expect(str, contains('Fach 3'));
        expect(str, contains('false'));
      });
      test('enthält lastSyncedEtag und pendingResolution', () {
        final artikel = _makeArtikel(
          etag: 'etag-current',
          lastSyncedEtag: 'etag-base',
          pendingResolution: 'force_merge',
        );

        final str = artikel.toString();

        expect(str, contains('etag-current'));
        expect(str, contains('etag-base'));
        expect(str, contains('force_merge'));
      });

    });
  });
}