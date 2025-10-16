import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageProcessingUtils {
  static const int _maxDimension = 1600;
  static const int _jpegQuality = 85;
  static const double _targetAspectRatio = 16 / 9;

  static double get targetAspectRatio => _targetAspectRatio;

  static Future<Uint8List?> ensureTargetFormat(
    Uint8List? sourceBytes, {
    bool crop = true,
  }) async {
    if (sourceBytes == null || sourceBytes.isEmpty) return sourceBytes;
    try {
      final decoded = img.decodeImage(sourceBytes);
      if (decoded == null) return sourceBytes;

      final adjustedAspect = crop ? _cropToAspectRatio(decoded) : decoded;
      final resized = _resizeIfNeeded(adjustedAspect);

      final hasAlpha = resized.numChannels > 3;
      if (hasAlpha) {
        return Uint8List.fromList(img.encodePng(resized, level: 6));
      }
      return Uint8List.fromList(img.encodeJpg(resized, quality: _jpegQuality));
    } catch (e, stack) {
      debugPrint('ImageProcessingUtils: Fehler bei der Bildverarbeitung: $e');
      debugPrint(stack.toString());
      return sourceBytes;
    }
  }

  static Future<Uint8List> rotateClockwise(Uint8List sourceBytes) async {
    try {
      final decoded = img.decodeImage(sourceBytes);
      if (decoded == null) return sourceBytes;

      final rotated = img.copyRotate(decoded, angle: 90);
      final hasAlpha = rotated.numChannels > 3;
      if (hasAlpha) {
        return Uint8List.fromList(img.encodePng(rotated, level: 6));
      }
      return Uint8List.fromList(img.encodeJpg(rotated, quality: _jpegQuality));
    } catch (e, stack) {
      debugPrint('ImageProcessingUtils: Fehler beim Drehen: $e');
      debugPrint(stack.toString());
      return sourceBytes;
    }
  }

  static img.Image _cropToAspectRatio(img.Image source) {
    final currentAspect = source.width / source.height;
    if ((currentAspect - _targetAspectRatio).abs() < 0.01) {
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
    if (maxSide <= _maxDimension) {
      return source;
    }

    return img.copyResize(
      source,
      width: source.width >= source.height ? _maxDimension : null,
      height: source.height > source.width ? _maxDimension : null,
      interpolation: img.Interpolation.cubic,
    );
  }
}
