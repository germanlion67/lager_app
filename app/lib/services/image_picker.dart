//.../services/image_picker.dart

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/image_processing_utils.dart';
import '../widgets/image_crop_dialog.dart';


class PickedImage {
  final String? pfad;
  final Uint8List? bytes;
  final String? dateiname;

  PickedImage({this.pfad, this.bytes, this.dateiname});
}

class ImagePickerService {
  /// Wählt ein Bild aus einer Datei
  static Future<PickedImage> pickImageFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return PickedImage();
    final file = result.files.single;
    if (!context.mounted) return PickedImage();
    final cropResult = await _openCropDialog(context, file.bytes);
    if (cropResult == null) return PickedImage();
    final processedBytes = await ImageProcessingUtils.ensureTargetFormat(
      cropResult.bytes,
      crop: cropResult.cropped,
    );
    return PickedImage(
      pfad: file.path,
      bytes: processedBytes ?? cropResult.bytes,
      dateiname: file.name,
    );
  }

  /// Nimmt ein Bild mit der Kamera auf
  static Future<PickedImage> pickImageCamera(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (pickedFile == null) return PickedImage();
    final bytes = await pickedFile.readAsBytes();
  if (!context.mounted) return PickedImage();
    final cropResult = await _openCropDialog(context, bytes);
    if (cropResult == null) return PickedImage();
    final processedBytes = await ImageProcessingUtils.ensureTargetFormat(
      cropResult.bytes,
      crop: cropResult.cropped,
    );
    return PickedImage(
      pfad: pickedFile.path,
      bytes: processedBytes ?? cropResult.bytes,
      dateiname: pickedFile.name,
    );
  }

  static Future<ImageCropDialogResult?> _openCropDialog(
    BuildContext context,
    Uint8List? originalBytes,
  ) async {
    if (originalBytes == null || originalBytes.isEmpty) return null;
    if (!context.mounted) return null;
    return showDialog<ImageCropDialogResult>(
      context: context,
      builder: (ctx) => ImageCropDialog(
        originalBytes: originalBytes,
        aspectRatio: ImageProcessingUtils.targetAspectRatio,
      ),
    );
  }

}