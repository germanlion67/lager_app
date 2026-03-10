// lib/services/image_picker.dart
//
// Plattformübergreifender Image-Picker Service.
// Unterstützt Datei-Auswahl und Kamera (nur Mobile/Desktop).
//
// Web: Nur Datei-Auswahl, Pfad ist null → bytes verwenden.
// Mobile: Datei-Auswahl + Kamera, Pfad + bytes verfügbar.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/image_processing_utils.dart';
import '../widgets/image_crop_dialog.dart';

/// Ergebnis eines Bild-Picks.
///
/// - [pfad]: Lokaler Dateipfad (nur Mobile/Desktop, im Web immer null)
/// - [bytes]: Bilddaten als Bytes (immer verfügbar wenn Bild gewählt wurde)
/// - [dateiname]: Originaler Dateiname
class PickedImage {
  final String? pfad;
  final Uint8List? bytes;
  final String? dateiname;

  PickedImage({this.pfad, this.bytes, this.dateiname});

  /// True wenn ein Bild gewählt wurde (bytes vorhanden).
  bool get hasImage => bytes != null && bytes!.isNotEmpty;
}

class ImagePickerService {
  /// Wählt ein Bild aus einer Datei.
  /// Funktioniert auf allen Plattformen (Web, Mobile, Desktop).
  ///
  /// Im Web ist [PickedImage.pfad] immer null – verwende [PickedImage.bytes].
  static Future<PickedImage> pickImageFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.image,
      withData: true, // Wichtig für Web: liefert bytes
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
      // Im Web ist file.path null → das ist OK, bytes sind vorhanden
      pfad: kIsWeb ? null : file.path,
      bytes: processedBytes ?? cropResult.bytes,
      dateiname: file.name,
    );
  }

  /// Nimmt ein Bild mit der Kamera auf.
  ///
  /// ⚠️ Nur auf Mobile/Desktop verfügbar.
  /// Im Web wird null zurückgegeben (Kamera nicht zuverlässig unterstützt).
  /// Aufrufer sollten im Web den Kamera-Button ausblenden.
  static Future<PickedImage> pickImageCamera(BuildContext context) async {
    // Kamera ist im Web nicht zuverlässig verfügbar
    if (kIsWeb) {
      return PickedImage();
    }

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

  /// Prüft ob die Kamera auf dieser Plattform verfügbar ist.
  /// Kann im UI verwendet werden um den Kamera-Button ein-/auszublenden.
  static bool get isCameraAvailable => !kIsWeb;

  /// Öffnet den Crop-Dialog für das gewählte Bild.
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
