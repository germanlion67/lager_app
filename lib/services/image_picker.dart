//.../services/image_picker.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';


class PickedImage {
  final String? pfad;
  final Uint8List? bytes;
  final String? dateiname;

  PickedImage({this.pfad, this.bytes, this.dateiname});
}

class ImagePickerService {
  static const int _maxDimension = 1600;
  static const int _jpegQuality = 85;

  /// Wählt ein Bild aus einer Datei
  static Future<PickedImage> pickImageFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return PickedImage();
    final file = result.files.single;
    final processedBytes = await _processImageBytes(file.bytes);
    return PickedImage(
      pfad: file.path,
      bytes: processedBytes ?? file.bytes,
      dateiname: file.name,
    );
  }

  /// Nimmt ein Bild mit der Kamera auf
  static Future<PickedImage> pickImageCamera() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _maxDimension.toDouble(),
      maxHeight: _maxDimension.toDouble(),
      imageQuality: _jpegQuality,
    );
    if (pickedFile == null) return PickedImage();
    final bytes = await pickedFile.readAsBytes();
    final processedBytes = await _processImageBytes(bytes);
    return PickedImage(
      pfad: pickedFile.path,
      bytes: processedBytes ?? bytes,
      dateiname: pickedFile.name,
    );
  }

  static Future<Uint8List?> _processImageBytes(Uint8List? sourceBytes) async {
    if (sourceBytes == null || sourceBytes.isEmpty) return sourceBytes;
    try {
      final decoded = img.decodeImage(sourceBytes);
      if (decoded == null) return sourceBytes;

      img.Image workingImage = decoded;
      final maxSide = decoded.width >= decoded.height ? decoded.width : decoded.height;
      if (maxSide > _maxDimension) {
        workingImage = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? _maxDimension : null,
          height: decoded.height > decoded.width ? _maxDimension : null,
          interpolation: img.Interpolation.cubic,
        );
      }

  final hasAlpha = workingImage.numChannels > 3;

      if (hasAlpha) {
        return Uint8List.fromList(img.encodePng(workingImage, level: 6));
      }
      return Uint8List.fromList(img.encodeJpg(workingImage, quality: _jpegQuality));
    } catch (e, stack) {
      debugPrint('ImagePickerService: Fehler beim Verkleinern des Bildes: $e');
      debugPrint(stack.toString());
      return sourceBytes;
    }
  }
}