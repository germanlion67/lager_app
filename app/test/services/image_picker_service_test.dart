// test/services/image_picker_service_test.dart
//
// O-006: Tests für ImagePickerService nach P-001
//
// P-001 hat geändert:
// - pickImageCamera() öffnet KEINEN automatischen Crop-Dialog mehr
// - openCropDialog() ist jetzt public static (optionaler Crop on-demand)
// - ensureTargetFormat() wird mit crop: false aufgerufen
//
// Strategie:
// - FakeImagePicker subclassed ImagePicker, überschreibt pickImage()
// - overrideImagePicker (@visibleForTesting) injiziert Fake ohne Singleton-Problem
// - debugDefaultTargetPlatformOverride steuert isCameraAvailable
// - tester.runAsync() für pickImageCamera()-Pfade die compute() nutzen


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:lager_app/services/image_picker.dart';

// ── FakeImagePicker ────────────────────────────────────────────────────────────

/// Subclass von ImagePicker, der pickImage() ohne Plattformkanal umsetzt.
/// returnValue wird direkt zurückgegeben — kein Kamera-Aufruf.
class FakeImagePicker extends ImagePicker {
  final XFile? returnValue;

  FakeImagePicker({this.returnValue});

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    bool requestFullMetadata = true,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async =>
      returnValue;
}

// ── Fixture ────────────────────────────────────────────────────────────────────

/// Minimal-JPEG (SOI + EOI, 4 Bytes).
///
/// ensureTargetFormat() kann dies nicht dekodieren → gibt null zurück.
/// pickImageCamera() fällt auf Original-Bytes zurück (processedBytes ?? bytes)
/// → hasImage bleibt true. Damit wird verifiziert, dass der crop: false
/// Pfad durchlaufen wurde (kein Crop-Dialog ist aufgetaucht).
final Uint8List kMinimalJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

// ── Hilfsfunktion ──────────────────────────────────────────────────────────────

/// Baut ein minimales Widget-Tree und gibt den BuildContext zurück.
Future<BuildContext> buildTestContext(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: SizedBox())),
  );
  return tester.element(find.byType(SizedBox));
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    ImagePickerService.overrideImagePicker = null;
    debugDefaultTargetPlatformOverride = null;
  });

  tearDown(() {
    ImagePickerService.overrideImagePicker = null;
    debugDefaultTargetPlatformOverride = null;
  });

  // ── PickedImage Datenklasse ──────────────────────────────────────────────────

  group('PickedImage', () {
    test('empty.hasImage ist false', () {
      expect(PickedImage.empty.hasImage, isFalse);
    });

    test('hasImage ist true wenn bytes gesetzt und nicht leer', () {
      final image = PickedImage(bytes: Uint8List.fromList([1, 2, 3]));
      expect(image.hasImage, isTrue);
    });

    test('hasImage ist false wenn bytes null', () {
      const image = PickedImage();
      expect(image.hasImage, isFalse);
    });

    test('hasImage ist false wenn bytes leer', () {
      final image = PickedImage(bytes: Uint8List(0));
      expect(image.hasImage, isFalse);
    });
  });

  // ── isCameraAvailable ────────────────────────────────────────────────────────

  group('isCameraAvailable', () {
    test('false auf Linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(ImagePickerService.isCameraAvailable, isFalse);
    });

    test('false auf Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(ImagePickerService.isCameraAvailable, isFalse);
    });

    test('false auf macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(ImagePickerService.isCameraAvailable, isFalse);
    });

    test('true auf Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(ImagePickerService.isCameraAvailable, isTrue);
    });

    test('true auf iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(ImagePickerService.isCameraAvailable, isTrue);
    });
  });

  // ── openCropDialog() public API ──────────────────────────────────────────────

  group('openCropDialog()', () {
    testWidgets('gibt null zurück bei null bytes — kein Dialog', (tester) async {
      final context = await buildTestContext(tester);

      final result = await ImagePickerService.openCropDialog(context, null);

      expect(result, isNull);
    });

    testWidgets('gibt null zurück bei leeren bytes — kein Dialog', (tester) async {
      final context = await buildTestContext(tester);

      final result = await ImagePickerService.openCropDialog(
        context,
        Uint8List(0),
      );

      expect(result, isNull);
    });
  });

  // ── pickImageCamera() ────────────────────────────────────────────────────────

  group('pickImageCamera()', () {
    testWidgets(
      'gibt PickedImage.empty zurück bei Datei zu groß',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        ImagePickerService.maxFileSizeBytesOverride = 100;
        final oversizedBytes = Uint8List(101);
        ImagePickerService.overrideImagePicker = FakeImagePicker(
          // XFile.fromData statt XFile(path, bytes:)
          // → garantiert In-Memory auf dart:io, kein Dateipfad-Zugriff
          returnValue: XFile.fromData(oversizedBytes, name: 'big.jpg'),
        );
        try {
          final context = await buildTestContext(tester);

          // tester.runAsync() → verlässt FakeAsync für readAsBytes()
          final result = await tester.runAsync(
            () => ImagePickerService.pickImageCamera(context),
          );

          expect(result, isNotNull);
          expect(result!.hasImage, isFalse);
        } finally {
          debugDefaultTargetPlatformOverride = null;
          ImagePickerService.maxFileSizeBytesOverride = null;
        }
      },
    );

    testWidgets(
      'gibt PickedImage.empty zurück wenn Picker null zurückgibt — Nutzer bricht ab',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        ImagePickerService.overrideImagePicker = FakeImagePicker(
          returnValue: null,
        );
        try {
          final context = await buildTestContext(tester);

          final result = await ImagePickerService.pickImageCamera(context);

          expect(result.hasImage, isFalse);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      'gibt PickedImage.empty zurück bei Datei > 10 MB',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final hugeBytes = Uint8List(10 * 1024 * 1024 + 1);
        ImagePickerService.overrideImagePicker = FakeImagePicker(
          // Fix 1: XFile.fromData statt XFile(path, bytes:)
          // → garantiert In-Memory, kein Dateisystem-Zugriff
          returnValue: XFile.fromData(hugeBytes, name: 'huge.jpg'),
        );
        try {
          final context = await buildTestContext(tester);

          // Fix 2: tester.runAsync() wie beim Happy-Path
          // → verlässt FakeAsync, erlaubt echte Async-Ausführung
          final result = await tester.runAsync(
            () => ImagePickerService.pickImageCamera(context),
          );

          expect(result, isNotNull);
          expect(result!.hasImage, isFalse);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      'gibt PickedImage mit bytes zurück — kein Crop-Dialog, ensureTargetFormat crop: false',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        ImagePickerService.overrideImagePicker = FakeImagePicker(
          returnValue: XFile.fromData(kMinimalJpeg, name: 'camera.jpg'),
        );
        try {
          final context = await buildTestContext(tester);

          final result = await tester.runAsync(
            () => ImagePickerService.pickImageCamera(context),
          );

          expect(result, isNotNull);
          expect(result!.hasImage, isTrue);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });
}