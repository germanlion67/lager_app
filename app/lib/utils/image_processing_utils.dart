// lib/utils/image_processing_utils.dart

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageProcessingUtils {
  // Fix: private Konstruktor — reine Utility-Klasse, nicht instanziierbar
  ImageProcessingUtils._();

  static const int _maxDimension = 1600;
  static const int _jpegQuality = 85;
  static const double _targetAspectRatio = 16 / 9;

  // Fix: Toleranz als benannte Konstante statt Magic Number
  static const double _aspectRatioTolerance = 0.01;

  static double get targetAspectRatio => _targetAspectRatio;

  static Future<Uint8List?> ensureTargetFormat(
    Uint8List? sourceBytes, {
    bool crop = true,
  }) async {
    if (sourceBytes == null || sourceBytes.isEmpty) return sourceBytes;

    try {
      // Fix: Dekodierung + Encoding in compute() auslagern → kein UI-Jank
      return await compute(_processImage, _ProcessArgs(sourceBytes, crop));
    } catch (e, stack) {
      debugPrint('ImageProcessingUtils: Fehler bei der Bildverarbeitung: $e');
      debugPrint(stack.toString());
      return sourceBytes;
    }
  }

  static Future<Uint8List> rotateClockwise(Uint8List sourceBytes) async {
    try {
      // Fix: Rotation ebenfalls in compute() auslagern → kein UI-Jank
      return await compute(_rotateImage, sourceBytes);
    } catch (e, stack) {
      debugPrint('ImageProcessingUtils: Fehler beim Drehen: $e');
      debugPrint(stack.toString());
      return sourceBytes;
    }
  }

  // ---------------------------------------------------------------------------
  // Isolate-kompatible Top-Level-ähnliche Hilfsfunktionen
  // (static, keine Closures → sicher für compute())
  // ---------------------------------------------------------------------------

  static Uint8List _processImage(_ProcessArgs args) {
    final decoded = img.decodeImage(args.sourceBytes);
    // Fix: Fallback auf Original wenn Dekodierung fehlschlägt
    if (decoded == null) return args.sourceBytes;

    final adjusted = args.crop ? _cropToAspectRatio(decoded) : decoded;
    final resized = _resizeIfNeeded(adjusted);

    return _encode(resized);
  }

  static Uint8List _rotateImage(Uint8List sourceBytes) {
    final decoded = img.decodeImage(sourceBytes);
    // Fix: Fallback auf Original wenn Dekodierung fehlschlägt
    if (decoded == null) return sourceBytes;

    final rotated = img.copyRotate(decoded, angle: 90);
    return _encode(rotated);
  }

  /// Kodiert ein Bild als PNG (mit Alpha) oder JPEG (ohne Alpha).
  static Uint8List _encode(img.Image image) {
    final hasAlpha = image.numChannels > 3;
    if (hasAlpha) {
      return Uint8List.fromList(img.encodePng(image, level: 6));
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: _jpegQuality));
  }

  static img.Image _cropToAspectRatio(img.Image source) {
    final currentAspect = source.width / source.height;

    // Fix: Benannte Konstante statt Magic Number 0.01
    if ((currentAspect - _targetAspectRatio).abs() < _aspectRatioTolerance) {
      return source;
    }

    if (currentAspect > _targetAspectRatio) {
      final targetWidth = (source.height * _targetAspectRatio).round();
      final offsetX = ((source.width - targetWidth) / 2).round();
      return img.copyCrop(
        source,
        x: offsetX,
        y: 0,
        width: targetWidth,
        height: source.height,
      );
    } else {
      final targetHeight = (source.width / _targetAspectRatio).round();
      final offsetY = ((source.height - targetHeight) / 2).round();
      return img.copyCrop(
        source,
        x: 0,
        y: offsetY,
        width: source.width,
        height: targetHeight,
      );
    }
  }

  static img.Image _resizeIfNeeded(img.Image source) {
    // Fix: math.max statt manueller Vergleich
    final maxSide = source.width >= source.height
        ? source.width
        : source.height;

    if (maxSide <= _maxDimension) return source;

    // Fix: Skalierungsfaktor berechnen → beide Dimensionen korrekt skaliert
    final scale = _maxDimension / maxSide;
    return img.copyResize(
      source,
      width: (source.width * scale).round(),
      height: (source.height * scale).round(),
      interpolation: img.Interpolation.cubic,
    );
  }
}

// ---------------------------------------------------------------------------
// Hilfsklasse für compute()-Argumente (muss serialisierbar sein)
// ---------------------------------------------------------------------------

class _ProcessArgs {
  final Uint8List sourceBytes;
  final bool crop;

  const _ProcessArgs(this.sourceBytes, this.crop);
}