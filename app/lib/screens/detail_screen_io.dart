// lib/screens/detail_screen_io.dart

import 'dart:async'; // ← NEU
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/image_processing_utils.dart';
import '../services/app_log_service.dart';

final _logger = AppLogService.logger;

String _slug(String input) {
  final replaced = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return replaced.replaceAll(RegExp(r'^-+|-+$'), '');
}

Future<Directory> _getImagesDir() async {
  final appDir = await getApplicationDocumentsDirectory();
  final imagesDir = Directory(p.join(appDir.path, 'images'));
  await imagesDir.create(recursive: true);
  return imagesDir;
}

/// Speichert ein Bild lokal im App-Verzeichnis.
///
/// M-011: Generiert zusätzlich ein Thumbnail und gibt dessen Pfad
/// über [onThumbnailSaved] zurück (optional, fire-and-forget).
Future<String?> persistSelectedImage({
  Uint8List? bildBytes,
  String? bildPfad,
  required int artikelId,
  required String artikelName,
  void Function(String thumbPath)? onThumbnailSaved,
}) async {
  final imagesDir = await _getImagesDir();

  final nameSlug = _slug(artikelName.isEmpty ? 'artikel' : artikelName);
  final fileName = '${artikelId}_$nameSlug.jpg';
  final targetPath = p.join(imagesDir.path, fileName);

  Uint8List? sourceBytes;

  if (bildBytes != null) {
    await File(targetPath).writeAsBytes(bildBytes);
    sourceBytes = bildBytes;
  } else if (bildPfad != null) {
    final sourceFile = File(bildPfad);
    if (await sourceFile.exists()) {
      await sourceFile.copy(targetPath);
      sourceBytes = await sourceFile.readAsBytes();
    }
  }

  if (sourceBytes == null) return null;

  // M-011: Thumbnail generieren (fire-and-forget)
  unawaited(_generateAndSaveThumbnail(  // ← unawaited()
    sourceBytes: sourceBytes,
    artikelId: artikelId,
    nameSlug: nameSlug,
    imagesDir: imagesDir,
    onSaved: onThumbnailSaved,
  ),);

  return targetPath;
}

/// M-011: Generiert und speichert Thumbnail asynchron.
Future<void> _generateAndSaveThumbnail({
  required Uint8List sourceBytes,
  required int artikelId,
  required String nameSlug,
  required Directory imagesDir,
  void Function(String thumbPath)? onSaved,
}) async {
  try {
    final thumbBytes = await ImageProcessingUtils.generateThumbnail(sourceBytes);
    if (thumbBytes == null) return;

    final thumbFileName = '${artikelId}_${nameSlug}_thumb.jpg';
    final thumbPath = p.join(imagesDir.path, thumbFileName);
    await File(thumbPath).writeAsBytes(thumbBytes);

    _logger.d('[detail_screen_io] Thumbnail gespeichert: $thumbPath');
    onSaved?.call(thumbPath);
  } catch (e, st) {
    _logger.e('[detail_screen_io] Thumbnail-Generierung fehlgeschlagen',
        error: e, stackTrace: st,);
  }
}

/// Liest Bytes einer lokalen Datei.
Future<Uint8List> readFileBytes(String path) => File(path).readAsBytes();

/// Prüft ob eine lokale Datei existiert.
bool fileExists(String path) => File(path).existsSync();

/// Baut ein Image.file Widget.
Widget buildFileImage(
  String path, {
  double? height,
  double? width,
  BoxFit? fit,
}) {
  return Image.file(
    File(path),
    height: height,
    width: width,
    fit: fit,
    errorBuilder: (_, __, ___) => Container(
      height: height,
      width: width,
      color: Colors.grey[200],
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    ),
  );
}