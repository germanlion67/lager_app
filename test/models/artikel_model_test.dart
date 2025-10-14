import 'package:flutter_test/flutter_test.dart';
import 'package:elektronik_verwaltung/models/artikel_model.dart';

void main() {
  group('Artikel Model Tests', () {
    test('should create valid Artikel with all required fields', () {
      final artikel = Artikel(
        id: 1,
        name: 'Test Artikel',
        menge: 5,
        ort: 'Lager A',
        fach: 'Fach 1',
        beschreibung: 'Test Beschreibung',
        bildPfad: '/path/to/image.jpg',
        erstelltAm: DateTime.now(),
        aktualisiertAm: DateTime.now(),
        uuid: 'test-uuid',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        deleted: false,
      );

      expect(artikel.name, 'Test Artikel');
      expect(artikel.menge, 5);
      expect(artikel.ort, 'Lager A');
      expect(artikel.fach, 'Fach 1');
      expect(artikel.deleted, false);
    });

    test('isValid should return false for empty required fields', () {
      final invalidArtikel = Artikel(
        name: '',  // leer = invalid
        menge: 0,
        ort: '',   // leer = invalid
        fach: 'Fach 1',
        beschreibung: '',
        bildPfad: '',
        erstelltAm: DateTime.now(),
        aktualisiertAm: DateTime.now(),
        uuid: 'test-uuid',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        deleted: false,
      );

      expect(invalidArtikel.isValid(), false);
    });

    test('isValid should return true for valid artikel', () {
      final validArtikel = Artikel(
        name: 'Gültiger Artikel',
        menge: 10,
        ort: 'Lager B',
        fach: 'Fach 2',
        beschreibung: 'Gültige Beschreibung',
        bildPfad: '/path/to/valid.jpg',
        erstelltAm: DateTime.now(),
        aktualisiertAm: DateTime.now(),
        uuid: 'valid-uuid',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        deleted: false,
      );

      expect(validArtikel.isValid(), true);
    });

    test('toMap should contain all required fields', () {
      final artikel = Artikel(
        id: 42,
        name: 'Map Test',
        menge: 7,
        ort: 'Test Ort',
        fach: 'Test Fach',
        beschreibung: 'Test Desc',
        bildPfad: '/test/path.jpg',
        erstelltAm: DateTime.parse('2025-01-01'),
        aktualisiertAm: DateTime.parse('2025-01-02'),
        uuid: 'map-test-uuid',
        updatedAt: 1704067200000, // 2025-01-01 00:00:00 UTC
        deleted: false,
      );

      final map = artikel.toMap();

      expect(map['id'], 42);
      expect(map['name'], 'Map Test');
      expect(map['menge'], 7);
      expect(map['ort'], 'Test Ort');
      expect(map['fach'], 'Test Fach');
      expect(map['uuid'], 'map-test-uuid');
      expect(map['deleted'], 0); // SQLite boolean als int
    });

    test('fromMap should recreate Artikel correctly', () {
      final map = {
        'id': 99,
        'name': 'FromMap Test',
        'menge': 3,
        'ort': 'FromMap Ort',
        'fach': 'FromMap Fach',
        'beschreibung': 'FromMap Desc',
        'bildPfad': '/frommap/path.jpg',
        'erstelltAm': '2025-01-15T10:30:00.000',
        'aktualisiertAm': '2025-01-15T11:00:00.000',
        'uuid': 'frommap-uuid',
        'updatedAt': 1705312200000,
        'deleted': 0,
      };

      final artikel = Artikel.fromMap(map);

      expect(artikel.id, 99);
      expect(artikel.name, 'FromMap Test');
      expect(artikel.menge, 3);
      expect(artikel.ort, 'FromMap Ort');
      expect(artikel.fach, 'FromMap Fach');
      expect(artikel.uuid, 'frommap-uuid');
      expect(artikel.deleted, false);
    });
  });
}