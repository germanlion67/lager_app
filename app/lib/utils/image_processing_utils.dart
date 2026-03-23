// lib/utils/image_processing_utils.dart

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageProcessingUtils {
  ImageProcessingUtils._();

  static const int _maxDimension = 1600;
  static const int _jpegQuality = 85;
  static const double _targetAspectRatio = 16 / 9;
  static const double _aspectRatioTolerance = 0.01;

  // M-011: Thumbnail-Dimensionen
  static const int thumbnailWidth = 120;
  static const int thumbnailHeight = 120;
  static const int _thumbnailJpegQuality = 75;

  static double get targetAspectRatio => _targetAspectRatio;

  /// Verarbeitet ein Bild (crop + resize) und gibt JPEG/PNG-Bytes zurück.
  static Future<Uint8List?> ensureTargetFormat(
    Uint8List? sourceBytes, {
    bool crop = true,
  }) async {
    if (sourceBytes == null || sourceBytes.isEmpty) return sourceBytes;

    try {
      return await compute(_processImage, _ProcessArgs(sourceBytes, crop));
    } catch (e, stack) {
      debugPrint('ImageProcessingUtils: Fehler bei der Bildverarbeitung: $e');
      debugPrint(stack.toString());
      return sourceBytes;
    }
  }

  /// M-011: Generiert ein quadratisches Thumbnail (120×120px, JPEG Q75).
  /// Läuft in einem Isolate via compute() → kein UI-Jank.
  ///
  /// [sourceBytes] – Originalbild-Bytes (bereits verarbeitet/gecroppt)
  /// Gibt JPEG-Bytes zurück, oder null bei Fehler.
  static Future<Uint8List?> generateThumbnail(Uint8List? sourceBytes) async {
    if (sourceBytes == null || sourceBytes.isEmpty) return null;

    try {
      return await compute(_generateThumbnailIsolate, sourceBytes);
    } catch (e, stack) {
      debugPrint('ImageProcessingUtils: Thumbnail-Generierung fehlgeschlagen: $e');
      debugPrint(stack.toString());
      return null;
    }
  }

  static Future<Uint8List> rotateClockwise(Uint8List sourceBytes) async {
    try {
      return await compute(_rotateImage, sourceBytes);
    } catch (e, stack) {
      debugPrint('ImageProcessingUtils: Fehler beim Drehen: $e');
      debugPrint(stack.toString());
      return sourceBytes;
    }
  }

  // ---------------------------------------------------------------------------
  // Isolate-Funktionen (static, keine Closures)
  // ---------------------------------------------------------------------------

  static Uint8List _processImage(_ProcessArgs args) {
    final decoded = img.decodeImage(args.sourceBytes);
    if (decoded == null) return args.sourceBytes;

    final adjusted = args.crop ? _cropToAspectRatio(decoded) : decoded;
    final resized = _resizeIfNeeded(adjusted);
    return _encode(resized);
  }

  /// M-011: Thumbnail-Generierung im Isolate.
  /// Schneidet quadratisch zu (center-crop) und skaliert auf 120×120px.
  static Uint8List _generateThumbnailIsolate(Uint8List sourceBytes) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) return sourceBytes;

    // Center-Crop auf Quadrat
    final size = decoded.width < decoded.height ? decoded.width : decoded.height;
    final offsetX = ((decoded.width - size) / 2).round();
    final offsetY = ((decoded.height - size) / 2).round();

    final cropped = img.copyCrop(
      decoded,
      x: offsetX,
      y: offsetY,
      width: size,
      height: size,
    );

    // Auf Thumbnail-Größe skalieren
    final thumbnail = img.copyResize(
      cropped,
      width: thumbnailWidth,
      height: thumbnailHeight,
      interpolation: img.Interpolation.average,
    );

    return Uint8List.fromList(
      img.encodeJpg(thumbnail, quality: _thumbnailJpegQuality),
    );
  }

  static Uint8List _rotateImage(Uint8List sourceBytes) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) return sourceBytes;

    final rotated = img.copyRotate(decoded, angle: 90);
    return _encode(rotated);
  }

  static Uint8List _encode(img.Image image) {
    final hasAlpha = image.numChannels > 3;
    if (hasAlpha) {
      return Uint8List.fromList(img.encodePng(image, level: 6));
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: _jpegQuality));
  }

  static img.Image _cropToAspectRatio(img.Image source) {
    final currentAspect = source.width / source.height;

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
    final maxSide = source.width >= source.height ? source.width : source.height;
    if (maxSide <= _maxDimension) return source;

    final scale = _maxDimension / maxSide;
    return img.copyResize(
      source,
      width: (source.width * scale).round(),
      height: (source.height * scale).round(),
      interpolation: img.Interpolation.cubic,
    );
  }
}

class _ProcessArgs {
  final Uint8List sourceBytes;
  final bool crop;

  const _ProcessArgs(this.sourceBytes, this.crop);
}