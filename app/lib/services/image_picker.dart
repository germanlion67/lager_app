// lib/services/image_picker.dart
//
// Plattformübergreifender Image-Picker Service.
// Unterstützt Datei-Auswahl und Kamera (nur Mobile).
//
// Web:     Nur Datei-Auswahl, Pfad ist null → bytes verwenden.
// Mobile:  Datei-Auswahl + Kamera, Pfad + bytes verfügbar.
// Desktop: Datei-Auswahl via file_selector (GTK, kein DBus nötig).
//          Fallback: manueller Pfad-Dialog wenn GTK nicht verfügbar.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';

import '../config/app_config.dart';
import '../services/app_log_service.dart';
import '../utils/image_processing_utils.dart';
import '../widgets/image_crop_dialog.dart';
import 'dart:io';

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

  static const PickedImage empty = PickedImage();

  /// True wenn ein Bild gewählt wurde (bytes vorhanden).
  bool get hasImage => bytes != null && bytes!.isNotEmpty;
}

class ImagePickerService {
  static const int _maxFileSizeBytes = 10 * 1024 * 1024;
  static final Logger _logger = AppLogService.logger;

  // Field zur Klasse hinzufügen (nach _logger):
  /// Austauschbarer [ImagePicker] für Tests.
  /// Produktionscode lässt diesen null — dann wird [ImagePicker()] verwendet.
  @visibleForTesting
  static ImagePicker? overrideImagePicker;  

  @visibleForTesting
  static int? maxFileSizeBytesOverride;

  static int get _effectiveMaxFileSize =>
      maxFileSizeBytesOverride ?? _maxFileSizeBytes;

  /// Wählt ein Bild aus einer Datei.
  /// Funktioniert auf allen Plattformen (Web, Mobile, Desktop).
  ///
  /// Reihenfolge der Versuche auf Desktop/Linux:
  ///   1. file_picker  (funktioniert wenn xdg-desktop-portal vorhanden)
  ///   2. file_selector (GTK-Dialog, funktioniert auf WSL2 mit $DISPLAY)
  ///   3. Manueller Pfad-Dialog (letzter Fallback)
  ///
  /// Im Web ist [PickedImage.pfad] immer null – verwende [PickedImage.bytes].
  static Future<PickedImage> pickImageFile(BuildContext context) async {
    final FilePickerResult? result;

    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.image,
        withData: true,
      );
    } catch (e, st) {
      _logger.w(
        'pickImageFile: FilePicker nicht verfügbar, Fallback zu file_selector',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return PickedImage.empty;
      return await _pickImageByFileSelector(context);
    }

    if (result == null || result.files.isEmpty) return PickedImage.empty;

    final file = result.files.single;

    if (file.bytes != null && file.bytes!.length > _maxFileSizeBytes) {
      _logger.w(
        'pickImageFile: Datei zu groß '
        '(${file.bytes!.length} Bytes, max $_maxFileSizeBytes Bytes)',
      );
      return PickedImage.empty;
    }

    if (!context.mounted) return PickedImage.empty;

    final cropResult = await _openCropDialog(context, file.bytes);
    if (cropResult == null) return PickedImage.empty;

    final Uint8List? processedBytes;
    try {
      processedBytes = await ImageProcessingUtils.ensureTargetFormat(
        cropResult.bytes,
        crop: cropResult.cropped,
      );
    } catch (e, st) {
      _logger.e(
        'pickImageFile: Bildverarbeitung fehlgeschlagen',
        error: e,
        stackTrace: st,
      );
      return PickedImage.empty;
    }

    return PickedImage(
      pfad: kIsWeb ? null : file.path,
      bytes: processedBytes ?? cropResult.bytes,
      dateiname: file.name,
    );
  }

  /// Fallback 1: file_selector — GTK-Dialog, kein DBus/Portal nötig.
  /// Funktioniert auf WSL2 wenn $DISPLAY gesetzt ist (WSLg).
  static Future<PickedImage> _pickImageByFileSelector(
    BuildContext context,
  ) async {
    const typeGroup = XTypeGroup(
      label: 'Bilder',
      extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
    );

    final XFile? xFile;
    try {
      xFile = await openFile(acceptedTypeGroups: [typeGroup]);
    } catch (e, st) {
      _logger.w(
        '_pickImageByFileSelector: file_selector nicht verfügbar, '
        'Fallback zu manuellem Pfad-Dialog',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return PickedImage.empty;
      return await _pickImageByPathFallback(context);
    }

    if (xFile == null) return PickedImage.empty;

    final Uint8List bytes;
    try {
      bytes = await xFile.readAsBytes();
    } catch (e, st) {
      _logger.e(
        '_pickImageByFileSelector: Datei konnte nicht gelesen werden',
        error: e,
        stackTrace: st,
      );
      return PickedImage.empty;
    }

    if (bytes.length > _effectiveMaxFileSize) {
      _logger.w(
        '_pickImageByFileSelector: Datei zu groß '
        '(${bytes.length} Bytes, max $_maxFileSizeBytes Bytes)',
      );
      return PickedImage.empty;
    }

    if (!context.mounted) return PickedImage.empty;

    final cropResult = await _openCropDialog(context, bytes);
    if (cropResult == null) return PickedImage.empty;

    final Uint8List? processedBytes;
    try {
      processedBytes = await ImageProcessingUtils.ensureTargetFormat(
        cropResult.bytes,
        crop: cropResult.cropped,
      );
    } catch (e, st) {
      _logger.e(
        '_pickImageByFileSelector: Bildverarbeitung fehlgeschlagen',
        error: e,
        stackTrace: st,
      );
      return PickedImage.empty;
    }

    return PickedImage(
      pfad: xFile.path,
      bytes: processedBytes ?? cropResult.bytes,
      dateiname: xFile.name,
    );
  }

  /// Fallback 2: Manueller Pfad-Eingabe-Dialog.
  /// Letzter Ausweg wenn weder file_picker noch file_selector verfügbar.
  static Future<PickedImage> _pickImageByPathFallback(
    BuildContext context,
  ) async {
    final controller = TextEditingController();

    final String? eingabePfad = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bildpfad eingeben'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Datei-Dialog nicht verfügbar.\n'
              'Bitte vollständigen Bildpfad eingeben:',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '/home/user/bilder/foto.jpg',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Laden'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (eingabePfad == null || eingabePfad.isEmpty) return PickedImage.empty;

    final file = File(eingabePfad);
    if (!await file.exists()) {
      _logger.w('_pickImageByPathFallback: Datei nicht gefunden: $eingabePfad');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datei nicht gefunden. Bitte Pfad prüfen.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return PickedImage.empty;
    }

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e, st) {
      _logger.e(
        '_pickImageByPathFallback: Datei konnte nicht gelesen werden: $eingabePfad',
        error: e,
        stackTrace: st,
      );
      return PickedImage.empty;
    }

    if (bytes.length > _effectiveMaxFileSize) {
      _logger.w(
        '_pickImageByPathFallback: Datei zu groß '
        '(${bytes.length} Bytes, max $_maxFileSizeBytes Bytes)',
      );
      return PickedImage.empty;
    }

    if (!context.mounted) return PickedImage.empty;

    final cropResult = await _openCropDialog(context, bytes);
    if (cropResult == null) return PickedImage.empty;

    final Uint8List? processedBytes;
    try {
      processedBytes = await ImageProcessingUtils.ensureTargetFormat(
        cropResult.bytes,
        crop: cropResult.cropped,
      );
    } catch (e, st) {
      _logger.e(
        '_pickImageByPathFallback: Bildverarbeitung fehlgeschlagen',
        error: e,
        stackTrace: st,
      );
      return PickedImage.empty;
    }

    return PickedImage(
      pfad: eingabePfad,
      bytes: processedBytes ?? cropResult.bytes,
      dateiname: eingabePfad.split('/').last,
    );
  }

  /// Nimmt ein Bild mit der Kamera auf.
  ///
  /// ⚠️ Nur auf Android und iOS verfügbar.
  ///
  /// Kein automatischer Crop-Dialog mehr – die Vorschau wird sofort
  /// nach der Aufnahme angezeigt. Zuschneiden ist optional per Button
  /// im aufrufenden Screen möglich.
  static Future<PickedImage> pickImageCamera(BuildContext context) async {
    if (!isCameraAvailable) return PickedImage.empty;

    final picker = overrideImagePicker ?? ImagePicker();
    final XFile? pickedFile;

    try {
      pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: AppConfig.cameraTargetMaxWidth.toDouble(),
        maxHeight: AppConfig.cameraTargetMaxHeight.toDouble(),
        imageQuality: AppConfig.cameraImageQuality,
      );
    } catch (e, st) {
      _logger.e(
        'pickImageCamera: Kamera Fehler',
        error: e,
        stackTrace: st,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kamera nicht verfügbar auf diesem Gerät.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return PickedImage.empty;
    }

    if (pickedFile == null) return PickedImage.empty;

    final Uint8List bytes;
    try {
      bytes = await pickedFile.readAsBytes();
    } catch (e, st) {
      _logger.e(
        'pickImageCamera: Bilddaten konnten nicht gelesen werden',
        error: e,
        stackTrace: st,
      );
      return PickedImage.empty;
    }

    if (bytes.length > _effectiveMaxFileSize) {
      _logger.w(
        'pickImageCamera: Bild zu groß '
        '(${bytes.length} Bytes, max $_maxFileSizeBytes Bytes)',
      );
      return PickedImage.empty;
    }

    // Kein automatischer Crop-Dialog – Bytes direkt verarbeiten (kein Crop)
    // und sofort zurückgeben, damit die UI ohne Verzögerung eine Vorschau zeigt.
    final Uint8List? processedBytes;
    try {
      processedBytes = await ImageProcessingUtils.ensureTargetFormat(
        bytes,
        crop: false,
      );
    } catch (e, st) {
      _logger.e(
        'pickImageCamera: Bildverarbeitung fehlgeschlagen',
        error: e,
        stackTrace: st,
      );
      return PickedImage.empty;
    }

    return PickedImage(
      pfad: pickedFile.path,
      bytes: processedBytes ?? bytes,
      dateiname: pickedFile.name,
    );
  }

  /// Prüft ob die Kamera auf dieser Plattform verfügbar ist.
  ///
  /// true  → Android, iOS
  /// false → Web, Linux, Windows
  static bool get isCameraAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Öffnet den Crop-Dialog für das gewählte Bild.
  ///
  /// Kann direkt aus einem Screen aufgerufen werden, um optionales Zuschneiden
  /// nach der Aufnahme/Auswahl zu ermöglichen.
  static Future<ImageCropDialogResult?> openCropDialog(
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

  /// Öffnet den Crop-Dialog für das gewählte Bild.
  static Future<ImageCropDialogResult?> _openCropDialog(
    BuildContext context,
    Uint8List? originalBytes,
  ) => openCropDialog(context, originalBytes);
}