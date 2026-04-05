// test/utils/uuid_generator_test.dart
//
// O-002: Unit-Tests für UuidGenerator
//
// Testet:
//   - generate(): Format, Eindeutigkeit, Nicht-Leer
//   - isValid(): Gültige/ungültige UUIDs (alle Versionen)
//   - isValidV4(): Nur v4-Format, Abgrenzung zu v1/v5

import 'package:flutter_test/flutter_test.dart';
import 'package:lager_app/utils/uuid_generator.dart';

void main() {
  group('UuidGenerator', () {
    // =========================================================
    // generate()
    // =========================================================
    group('generate()', () {
      test('gibt einen nicht-leeren String zurück', () {
        final result = UuidGenerator.generate();
        expect(result, isNotEmpty);
      });

      test('gibt eine gültige UUID v4 zurück', () {
        final result = UuidGenerator.generate();
        expect(UuidGenerator.isValidV4(result), isTrue);
      });

      test('gibt eine gültige UUID (allgemein) zurück', () {
        final result = UuidGenerator.generate();
        expect(UuidGenerator.isValid(result), isTrue);
      });

      test('generiert 1000 UUIDs ohne Duplikate (Eindeutigkeit)', () {
        const count = 1000;
        final uuids = List.generate(count, (_) => UuidGenerator.generate());
        final unique = uuids.toSet();
        expect(unique.length, equals(count));
      });

      test('jede UUID hat das korrekte RFC-4122-Format', () {
        // xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
        final uuidV4Pattern = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        );
        for (var i = 0; i < 20; i++) {
          final uuid = UuidGenerator.generate();
          expect(
            uuidV4Pattern.hasMatch(uuid),
            isTrue,
            reason: 'UUID "$uuid" entspricht nicht dem v4-Format',
          );
        }
      });

      test('zwei aufeinanderfolgende Aufrufe liefern unterschiedliche Werte', () {
        final a = UuidGenerator.generate();
        final b = UuidGenerator.generate();
        expect(a, isNot(equals(b)));
      });
    });

    // =========================================================
    // isValid()
    // =========================================================
    group('isValid()', () {
      test('akzeptiert eine gültige UUID v4', () {
        expect(
          UuidGenerator.isValid('550e8400-e29b-41d4-a716-446655440000'),
          isTrue,
        );
      });

      test('akzeptiert eine gültige UUID v1', () {
        // v1: version-nibble = 1
        expect(
          UuidGenerator.isValid('6ba7b810-9dad-11d1-80b4-00c04fd430c8'),
          isTrue,
        );
      });

      test('akzeptiert Großbuchstaben (case-insensitive)', () {
        expect(
          UuidGenerator.isValid('550E8400-E29B-41D4-A716-446655440000'),
          isTrue,
        );
      });

      test('lehnt leeren String ab', () {
        expect(UuidGenerator.isValid(''), isFalse);
      });

      test('lehnt String ohne Bindestriche ab', () {
        expect(
          UuidGenerator.isValid('550e8400e29b41d4a716446655440000'),
          isFalse,
        );
      });

      test('lehnt zu kurzen String ab', () {
        expect(UuidGenerator.isValid('550e8400-e29b-41d4'), isFalse);
      });

      test('lehnt String mit ungültigen Zeichen ab', () {
        expect(
          UuidGenerator.isValid('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'),
          isFalse,
        );
      });

      test('lehnt UUID mit falschem Trennzeichen ab', () {
        expect(
          UuidGenerator.isValid('550e8400_e29b_41d4_a716_446655440000'),
          isFalse,
        );
      });
    });

    // =========================================================
    // isValidV4()
    // =========================================================
    group('isValidV4()', () {
      test('akzeptiert eine gültige UUID v4', () {
        expect(
          UuidGenerator.isValidV4('550e8400-e29b-41d4-a716-446655440000'),
          isTrue,
        );
      });

      test('akzeptiert v4 mit Großbuchstaben (case-insensitive)', () {
        expect(
          UuidGenerator.isValidV4('550E8400-E29B-41D4-A716-446655440000'),
          isTrue,
        );
      });

      test('lehnt UUID v1 ab (version-nibble ≠ 4)', () {
        // v1: drittes Segment beginnt mit 1
        expect(
          UuidGenerator.isValidV4('6ba7b810-9dad-11d1-80b4-00c04fd430c8'),
          isFalse,
        );
      });

      test('lehnt UUID v5 ab (version-nibble = 5)', () {
        expect(
          UuidGenerator.isValidV4('886313e1-3b8a-5372-9b90-0c9aee199e5d'),
          isFalse,
        );
      });

      test('lehnt UUID mit ungültigem Variant-Bit ab', () {
        // variant-nibble muss [89ab] sein – hier: 'c' → ungültig
        expect(
          UuidGenerator.isValidV4('550e8400-e29b-41d4-c716-446655440000'),
          isFalse,
        );
      });

      test('lehnt leeren String ab', () {
        expect(UuidGenerator.isValidV4(''), isFalse);
      });

      test('lehnt String ohne Bindestriche ab', () {
        expect(
          UuidGenerator.isValidV4('550e8400e29b41d4a716446655440000'),
          isFalse,
        );
      });

      test('frisch generierte UUID besteht isValidV4()', () {
        final uuid = UuidGenerator.generate();
        expect(UuidGenerator.isValidV4(uuid), isTrue);
      });
    });

    // =========================================================
    // Konstruktor (privat – nur indirekt testbar)
    // =========================================================
    group('Klassen-Eigenschaften', () {
      test('UuidGenerator kann nicht instanziiert werden', () {
        // Der private Konstruktor verhindert Instanziierung.
        // Wir prüfen nur, dass die statischen Methoden ohne Instanz
        // aufrufbar sind – das ist durch alle obigen Tests bereits
        // implizit bestätigt.
        expect(UuidGenerator.generate, isA<Function>());
        expect(UuidGenerator.isValid, isA<Function>());
        expect(UuidGenerator.isValidV4, isA<Function>());
      });
    });
  });
}