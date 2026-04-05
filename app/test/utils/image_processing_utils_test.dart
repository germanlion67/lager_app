// test/utils/image_processing_utils_test.dart
//
// O-002: Unit-Tests für ImageProcessingUtils
//
// Strategie:
//   - compute() benötigt TestWidgetsFlutterBinding
//   - Echter JPEG/PNG-Byte-Payload als Fixture (minimal, valide)
//   - AppLogService.logger läuft durch — kein Mock nötig (nur ConsoleOutput)
//   - Isolate-interne Funktionen (_processImage etc.) werden indirekt
//     über die public API getestet
//
// Fehlerverhalten bei nicht-decodierbaren Bytes:
//   - ensureTargetFormat(): catch → return sourceBytes  (nie null)
//   - generateThumbnail():  catch → return null         (kein Fallback)
//   - rotateClockwise():    catch → return sourceBytes  (nie null)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lager_app/utils/image_processing_utils.dart';

// ---------------------------------------------------------------------------
// Test-Fixtures
// ---------------------------------------------------------------------------

/// Erstellt ein minimales JPEG-Bild als Uint8List.
Uint8List _makeJpeg({
  int width = 800,
  int height = 600,
  int r = 128,
  int g = 128,
  int b = 128,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodeJpg(image, quality: 85));
}

/// Erstellt ein minimales PNG-Bild mit Alpha-Kanal als Uint8List.
Uint8List _makePng({
  int width = 400,
  int height = 400,
}) {
  // ✅ numChannels: 4 → RGBA → hasAlpha = true → _encode() wählt PNG
  final image = img.Image(width: width, height: height, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(100, 150, 200, 255));
  return Uint8List.fromList(img.encodePng(image));
}

/// Prüft ob Bytes mit JPEG-Magic-Bytes beginnen (FF D8 FF).
bool _isJpeg(Uint8List bytes) =>
    bytes.length >= 3 &&
    bytes[0] == 0xFF &&
    bytes[1] == 0xD8 &&
    bytes[2] == 0xFF;

/// Prüft ob Bytes mit PNG-Magic-Bytes beginnen (89 50 4E 47).
bool _isPng(Uint8List bytes) =>
    bytes.length >= 4 &&
    bytes[0] == 0x89 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x4E &&
    bytes[3] == 0x47;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ✅ compute() benötigt Flutter-Binding
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('ImageProcessingUtils', () {
    // =======================================================================
    // Konstanten
    // =======================================================================
    group('Konstanten', () {
      test('targetAspectRatio ist 16/9', () {
        expect(
          ImageProcessingUtils.targetAspectRatio,
          closeTo(16 / 9, 0.0001),
        );
      });

      test('thumbnailWidth ist 120', () {
        expect(ImageProcessingUtils.thumbnailWidth, equals(120));
      });

      test('thumbnailHeight ist 120', () {
        expect(ImageProcessingUtils.thumbnailHeight, equals(120));
      });
    });

    // =======================================================================
    // ensureTargetFormat()
    // =======================================================================
    group('ensureTargetFormat()', () {
      group('Null- und Leer-Handling', () {
        test('gibt null zurück wenn sourceBytes null ist', () async {
          final result = await ImageProcessingUtils.ensureTargetFormat(null);
          expect(result, isNull);
        });

        test('gibt leeres Uint8List zurück wenn sourceBytes leer ist', () async {
          final result = await ImageProcessingUtils.ensureTargetFormat(
            Uint8List(0),
          );
          // ✅ sourceBytes.isEmpty → return sourceBytes (leer, nicht null)
          expect(result, isNotNull);
          expect(result!.isEmpty, isTrue);
        });

        test('gibt sourceBytes zurück wenn Bild nicht decodierbar ist', () async {
          // ✅ RangeError in Isolate → catch in ensureTargetFormat()
          //    → return sourceBytes (Fallback, nie null)
          final garbage = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
          final result = await ImageProcessingUtils.ensureTargetFormat(garbage);
          expect(result, isNotNull);
          expect(result, equals(garbage));
        });
      });

      group('Output-Format', () {
        test('gibt valide Bytes zurück (JPEG für RGB-Bild)', () async {
          final source = _makeJpeg(width: 800, height: 600);
          final result = await ImageProcessingUtils.ensureTargetFormat(source);

          expect(result, isNotNull);
          expect(result!.isNotEmpty, isTrue);
          // ✅ RGB ohne Alpha → JPEG-Output
          expect(_isJpeg(result), isTrue);
        });

        test('gibt PNG zurück für Bild mit Alpha-Kanal', () async {
          final source = _makePng(width: 400, height: 400);
          final result = await ImageProcessingUtils.ensureTargetFormat(source);

          expect(result, isNotNull);
          expect(result!.isNotEmpty, isTrue);
          // ✅ RGBA (numChannels > 3) → PNG-Output via _encode()
          expect(_isPng(result), isTrue);
        });

        test('Output ist kleiner oder gleich dem Input bei großem Bild', () async {
          final source = _makeJpeg(width: 2400, height: 1800);
          final result = await ImageProcessingUtils.ensureTargetFormat(
            source,
            crop: false,
          );

          expect(result, isNotNull);
          expect(result!.length, lessThanOrEqualTo(source.length));
        });
      });

      group('Resize (_resizeIfNeeded)', () {
        test('skaliert Bild herunter wenn größte Seite > 1600px', () async {
          // 2400×1800 → scale=1600/2400 → 1600×1200
          final source = _makeJpeg(width: 2400, height: 1800);
          final result = await ImageProcessingUtils.ensureTargetFormat(
            source,
            crop: false,
          );

          expect(result, isNotNull);
          final decoded = img.decodeImage(result!);
          expect(decoded, isNotNull);
          expect(decoded!.width, lessThanOrEqualTo(1600));
          expect(decoded.height, lessThanOrEqualTo(1600));
        });

        test('verändert Bild nicht wenn größte Seite <= 1600px', () async {
          // 800×600 → max=800 <= 1600 → kein Resize
          final source = _makeJpeg(width: 800, height: 600);
          final result = await ImageProcessingUtils.ensureTargetFormat(
            source,
            crop: false,
          );

          expect(result, isNotNull);
          final decoded = img.decodeImage(result!);
          expect(decoded, isNotNull);
          expect(decoded!.width, equals(800));
          expect(decoded.height, equals(600));
        });

        test('behält Seitenverhältnis beim Resize bei', () async {
          // 3200×2400 → scale=0.5 → 1600×1200 → ratio=4/3
          final source = _makeJpeg(width: 3200, height: 2400);
          final result = await ImageProcessingUtils.ensureTargetFormat(
            source,
            crop: false,
          );

          expect(result, isNotNull);
          final decoded = img.decodeImage(result!);
          expect(decoded, isNotNull);
          final ratio = decoded!.width / decoded.height;
          // ✅ Toleranz für JPEG-Rundungsfehler
          expect(ratio, closeTo(4 / 3, 0.02));
        });
      });

      group('Crop (_cropToAspectRatio)', () {
        test('croppt breites Bild auf 16:9 (crop: true)', () async {
          // 1600×600 → aspect=2.667 > 16/9 → zu breit → crop width
          final source = _makeJpeg(width: 1600, height: 600);
          final result = await ImageProcessingUtils.ensureTargetFormat(
            source,
            crop: true,
          );

          expect(result, isNotNull);
          final decoded = img.decodeImage(result!);
          expect(decoded, isNotNull);
          expect(decoded!.width / decoded.height, closeTo(16 / 9, 0.05));
        });

        test('croppt hohes Bild auf 16:9 (crop: true)', () async {
          // 800×900 → aspect=0.889 < 16/9 → zu hoch → crop height
          final source = _makeJpeg(width: 800, height: 900);
          final result = await ImageProcessingUtils.ensureTargetFormat(
            source,
            crop: true,
          );

          expect(result, isNotNull);
          final decoded = img.decodeImage(result!);
          expect(decoded, isNotNull);
          expect(decoded!.width / decoded.height, closeTo(16 / 9, 0.05));
        });

        test('überspringt Crop wenn Bild bereits 16:9 ist', () async {
          // 1600×900 → aspect ≈ 16/9 → kein Crop
          final source = _makeJpeg(width: 1600, height: 900);
          final result = await ImageProcessingUtils.ensureTargetFormat(
            source,
            crop: true,
          );

          expect(result, isNotNull);
          final decoded = img.decodeImage(result!);
          expect(decoded, isNotNull);
          expect(decoded!.width, equals(1600));
          expect(decoded.height, equals(900));
        });

        test('kein Crop wenn crop: false übergeben wird', () async {
          // 800×900 → ohne Crop bleibt Seitenverhältnis 8:9 erhalten
          final source = _makeJpeg(width: 800, height: 900);
          final result = await ImageProcessingUtils.ensureTargetFormat(
            source,
            crop: false,
          );

          expect(result, isNotNull);
          final decoded = img.decodeImage(result!);
          expect(decoded, isNotNull);
          // ✅ Ratio ist NICHT 16:9
          expect(
            decoded!.width / decoded.height,
            isNot(closeTo(16 / 9, 0.05)),
          );
        });
      });
    });

    // =======================================================================
    // generateThumbnail()
    // =======================================================================
    group('generateThumbnail()', () {
      group('Null- und Leer-Handling', () {
        test('gibt null zurück wenn sourceBytes null ist', () async {
          final result = await ImageProcessingUtils.generateThumbnail(null);
          expect(result, isNull);
        });

        test('gibt null zurück wenn sourceBytes leer ist', () async {
          final result = await ImageProcessingUtils.generateThumbnail(
            Uint8List(0),
          );
          expect(result, isNull);
        });

        test('gibt null zurück wenn Bild nicht decodierbar ist', () async {
          // ✅ FIX: _generateThumbnailIsolate hat keinen try/catch →
          //    RangeError propagiert → compute() wirft →
          //    generateThumbnail() catch-Block → return null.
          //    Anders als ensureTargetFormat() gibt es hier KEINEN
          //    sourceBytes-Fallback — null ist das korrekte Verhalten.
          final garbage = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
          final result = await ImageProcessingUtils.generateThumbnail(garbage);
          expect(result, isNull);
        });
      });

      group('Dimensionen', () {
        test('generiert Thumbnail mit exakt 120×120px (quadratisch)', () async {
          final source = _makeJpeg(width: 800, height: 600);
          final result = await ImageProcessingUtils.generateThumbnail(source);

          expect(result, isNotNull);
          final decoded = img.decodeImage(result!);
          expect(decoded, isNotNull);
          expect(decoded!.width, equals(ImageProcessingUtils.thumbnailWidth));
          expect(decoded.height, equals(ImageProcessingUtils.thumbnailHeight));
        });

        test('generiert 120×120 Thumbnail aus quadratischem Input', () async {
          final source = _makeJpeg(width: 500, height: 500);
          final result = await ImageProcessingUtils.generateThumbnail(source);

          expect(result, isNotNull);
          final decoded = img.decodeImage(result!);
          expect(decoded, isNotNull);
          expect(decoded!.width, equals(120));
          expect(decoded.height, equals(120));
        });

        test('generiert 120×120 Thumbnail aus hochformatigem Input', () async {
          // ✅ Center-Crop auf Quadrat → dann resize auf 120×120
          final source = _makeJpeg(width: 400, height: 800);
          final result = await ImageProcessingUtils.generateThumbnail(source);

          expect(result, isNotNull);
          final decoded = img.decodeImage(result!);
          expect(decoded, isNotNull);
          expect(decoded!.width, equals(120));
          expect(decoded.height, equals(120));
        });

        test('generiert 120×120 Thumbnail aus querformatigem Input', () async {
          final source = _makeJpeg(width: 1200, height: 400);
          final result = await ImageProcessingUtils.generateThumbnail(source);

          expect(result, isNotNull);
          final decoded = img.decodeImage(result!);
          expect(decoded, isNotNull);
          expect(decoded!.width, equals(120));
          expect(decoded.height, equals(120));
        });
      });

      group('Output-Format', () {
        test('Thumbnail ist JPEG (nicht PNG)', () async {
          // ✅ _generateThumbnailIsolate() nutzt immer encodeJpg()
          final source = _makeJpeg(width: 800, height: 600);
          final result = await ImageProcessingUtils.generateThumbnail(source);

          expect(result, isNotNull);
          expect(_isJpeg(result!), isTrue);
        });

        test('Thumbnail ist kleiner als Original', () async {
          final source = _makeJpeg(width: 1600, height: 900);
          final result = await ImageProcessingUtils.generateThumbnail(source);

          expect(result, isNotNull);
          expect(result!.length, lessThan(source.length));
        });

        test('Thumbnail aus PNG-Input ist JPEG', () async {
          // ✅ generateThumbnail() nutzt immer encodeJpg() — unabhängig vom Input
          final source = _makePng(width: 400, height: 400);
          final result = await ImageProcessingUtils.generateThumbnail(source);

          expect(result, isNotNull);
          expect(_isJpeg(result!), isTrue);
        });
      });
    });

    // =======================================================================
    // rotateClockwise()
    // =======================================================================
    group('rotateClockwise()', () {
      test('tauscht Breite und Höhe nach 90°-Rotation', () async {
        // 800×600 → 90° → 600×800
        final source = _makeJpeg(width: 800, height: 600);
        final result = await ImageProcessingUtils.rotateClockwise(source);

        final decoded = img.decodeImage(result);
        expect(decoded, isNotNull);
        expect(decoded!.width, equals(600));
        expect(decoded.height, equals(800));
      });

      test('gibt valide Bytes zurück nach Rotation', () async {
        final source = _makeJpeg(width: 400, height: 300);
        final result = await ImageProcessingUtils.rotateClockwise(source);

        expect(result.isNotEmpty, isTrue);
        expect(img.decodeImage(result), isNotNull);
      });

      test('gibt sourceBytes zurück wenn Bild nicht decodierbar ist', () async {
        // ✅ RangeError → catch in rotateClockwise() → return sourceBytes
        final garbage = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
        final result = await ImageProcessingUtils.rotateClockwise(garbage);
        expect(result, equals(garbage));
      });

      test('quadratisches Bild hat nach Rotation gleiche Dimensionen', () async {
        // ✅ 500×500 → 90° → 500×500 (symmetrisch)
        final source = _makeJpeg(width: 500, height: 500);
        final result = await ImageProcessingUtils.rotateClockwise(source);

        final decoded = img.decodeImage(result);
        expect(decoded, isNotNull);
        expect(decoded!.width, equals(500));
        expect(decoded.height, equals(500));
      });
    });
  });
}