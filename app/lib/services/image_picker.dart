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

  const PickedImage({this.pfad, this.bytes, this.dateiname});

  // Fix: Konstanter leerer Zustand — kein unnötiges Objekt pro Abbruch
  static const PickedImage empty = PickedImage();

  /// True wenn ein Bild gewählt wurde (bytes vorhanden).
  bool get hasImage => bytes != null && bytes!.isNotEmpty;
}

class ImagePickerService {
  // Fix: Maximale Dateigröße (10 MB) — verhindert OOM bei riesigen Bildern
  static const int _maxFileSizeBytes = 10 * 1024 * 1024;

  /// Wählt ein Bild aus einer Datei.
  /// Funktioniert auf allen Plattformen (Web, Mobile, Desktop).
  ///
  /// Im Web ist [PickedImage.pfad] immer null – verwende [PickedImage.bytes].
  /// Gibt [PickedImage.empty] zurück wenn kein Bild gewählt wurde oder
  /// ein Fehler aufgetreten ist.
  static Future<PickedImage> pickImageFile(BuildContext context) async {
    final FilePickerResult? result;

    // Fix: FilePicker-Fehler abfangen statt unkontrolliert werfen
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.image,
        withData: true, // Wichtig für Web: liefert bytes
      );
    } catch (e) {
      debugPrint('ImagePickerService.pickImageFile: FilePicker Fehler: $e');
      return PickedImage.empty;
    }

    if (result == null || result.files.isEmpty) return PickedImage.empty;

    final file = result.files.single;

    // Fix: Dateigröße prüfen vor Verarbeitung
    if (file.bytes != null && file.bytes!.length > _maxFileSizeBytes) {
      debugPrint(
        'ImagePickerService.pickImageFile: Datei zu groß '
        '(${file.bytes!.length} Bytes, max $_maxFileSizeBytes Bytes)',
      );
      return PickedImage.empty;
    }

    if (!context.mounted) return PickedImage.empty;

    final cropResult = await _openCropDialog(context, file.bytes);
    if (cropResult == null) return PickedImage.empty;

    // Fix: ImageProcessingUtils-Fehler abfangen
    final Uint8List? processedBytes;
    try {
      processedBytes = await ImageProcessingUtils.ensureTargetFormat(
        cropResult.bytes,
        crop: cropResult.cropped,
      );
    } catch (e) {
      debugPrint(
          'ImagePickerService.pickImageFile: Bildverarbeitung Fehler: $e',);
      return PickedImage.empty;
    }

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
  /// Im Web wird [PickedImage.empty] zurückgegeben
  /// (Kamera nicht zuverlässig unterstützt).
  /// Aufrufer sollten im Web den Kamera-Button ausblenden
  /// (siehe [isCameraAvailable]).
  static Future<PickedImage> pickImageCamera(BuildContext context) async {
    // Kamera ist im Web nicht zuverlässig verfügbar
    if (kIsWeb) return PickedImage.empty;

    final picker = ImagePicker();
    final XFile? pickedFile;

    // Fix: ImagePicker-Fehler abfangen (z.B. Kamera-Permission verweigert)
    try {
      pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
    } catch (e) {
      debugPrint('ImagePickerService.pickImageCamera: Kamera Fehler: $e');
      return PickedImage.empty;
    }

    if (pickedFile == null) return PickedImage.empty;

    // Fix: readAsBytes-Fehler abfangen
    final Uint8List bytes;
    try {
      bytes = await pickedFile.readAsBytes();
    } catch (e) {
      debugPrint(
          'ImagePickerService.pickImageCamera: readAsBytes Fehler: $e',);
      return PickedImage.empty;
    }

    // Fix: Dateigröße prüfen nach readAsBytes
    if (bytes.length > _maxFileSizeBytes) {
      debugPrint(
        'ImagePickerService.pickImageCamera: Bild zu groß '
        '(${bytes.length} Bytes, max $_maxFileSizeBytes Bytes)',
      );
      return PickedImage.empty;
    }

    if (!context.mounted) return PickedImage.empty;

    final cropResult = await _openCropDialog(context, bytes);
    if (cropResult == null) return PickedImage.empty;

    // Fix: ImageProcessingUtils-Fehler abfangen
    final Uint8List? processedBytes;
    try {
      processedBytes = await ImageProcessingUtils.ensureTargetFormat(
        cropResult.bytes,
        crop: cropResult.cropped,
      );
    } catch (e) {
      debugPrint(
          'ImagePickerService.pickImageCamera: Bildverarbeitung Fehler: $e',);
      return PickedImage.empty;
    }

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