import 'package:flutter_test/flutter_test.dart';

import 'package:lager_app/models/artikel_model.dart';
import 'package:lager_app/services/conflict_resolution_utils.dart';

Artikel _makeArtikel({
  String uuid = 'uuid-1',
  String name = 'Testartikel',
  String? etag,
  String? lastSyncedEtag,
}) {
  return Artikel(
    name: name,
    artikelnummer: 1001,
    menge: 10,
    ort: 'Regal A',
    fach: '1',
    beschreibung: 'Testbeschreibung',
    bildPfad: '',
    remoteBildPfad: null,
    erstelltAm: DateTime(2026, 1, 1),
    aktualisiertAm: DateTime(2026, 4, 1),
    uuid: uuid,
    updatedAt: DateTime(2026, 4, 1).millisecondsSinceEpoch,
    deleted: false,
    deviceId: 'device-test',
    etag: etag,
    lastSyncedEtag: lastSyncedEtag,
  );
}

void main() {
  group('requireRemoteBaselineEtag', () {
    test('returns etag when etag is present', () {
      final artikel = _makeArtikel(
        etag: 'etag-123',
        lastSyncedEtag: 'last-456',
      );

      final result = requireRemoteBaselineEtag(artikel);

      expect(result, 'etag-123');
    });

    test('falls back to lastSyncedEtag when etag is null', () {
      final artikel = _makeArtikel(
        etag: null,
        lastSyncedEtag: 'last-456',
      );

      final result = requireRemoteBaselineEtag(artikel);

      expect(result, 'last-456');
    });

    test('falls back to lastSyncedEtag when etag is empty', () {
      final artikel = _makeArtikel(
        etag: '',
        lastSyncedEtag: 'last-456',
      );

      final result = requireRemoteBaselineEtag(artikel);

      expect(result, 'last-456');
    });

    test('trims etag before returning it', () {
      final artikel = _makeArtikel(
        etag: '  etag-123  ',
        lastSyncedEtag: 'last-456',
      );

      final result = requireRemoteBaselineEtag(artikel);

      expect(result, 'etag-123');
    });

    test('trims lastSyncedEtag before returning it', () {
      final artikel = _makeArtikel(
        etag: '   ',
        lastSyncedEtag: '  last-456  ',
      );

      final result = requireRemoteBaselineEtag(artikel);

      expect(result, 'last-456');
    });

    test('throws StateError when etag and lastSyncedEtag are null', () {
      final artikel = _makeArtikel(
        etag: null,
        lastSyncedEtag: null,
      );

      expect(
        () => requireRemoteBaselineEtag(artikel),
        throwsA(isA<StateError>()),
      );
    });

    test('throws StateError when etag and lastSyncedEtag are empty', () {
      final artikel = _makeArtikel(
        etag: '',
        lastSyncedEtag: '',
      );

      expect(
        () => requireRemoteBaselineEtag(artikel),
        throwsA(isA<StateError>()),
      );
    });

    test('throws StateError when etag and lastSyncedEtag are whitespace only',
        () {
      final artikel = _makeArtikel(
        etag: '   ',
        lastSyncedEtag: '   ',
      );

      expect(
        () => requireRemoteBaselineEtag(artikel),
        throwsA(isA<StateError>()),
      );
    });
  });
}