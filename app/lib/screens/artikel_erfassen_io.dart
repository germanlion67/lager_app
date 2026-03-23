// lib/screens/artikel_erfassen_io.dart
// Plattform-spezifische Funktionen für Mobile/Desktop

import 'dart:async'; // ← NEU: für unawaited()
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../services/app_log_service.dart';
import '../utils/image_processing_utils.dart';

// M-002: Verwende AppLogService statt debugPrint
final _logger = AppLogService.logger;

/// Liest Datei-Bytes von einem lokalen Pfad.
Future<Uint8List> readFileBytes(String path) async {
  return await File(path).readAsBytes();
}

/// Gibt den Dateinamen aus einem Pfad zurück.
String getBasename(String path) {
  return p.basename(path);
}

String _slug(String input) {
  final s = input.toLowerCase();
  final replaced = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return replaced.replaceAll(RegExp(r'^-+|-+$'), '');
}

/// M-011: Gibt das images-Verzeichnis zurück und erstellt es bei Bedarf.
Future<Directory> _getImagesDir() async {
  final appDir = await getApplicationDocumentsDirectory();
  final imagesDir = Directory(p.join(appDir.path, 'images'));
  await imagesDir.create(recursive: true);
  return imagesDir;
}

/// Kopiert das Bild ins lokale App-Verzeichnis und generiert ein Thumbnail.
///
/// Gibt den lokalen Pfad des Hauptbildes zurück.
/// Das Thumbnail wird parallel gespeichert als `{artikelId}_{slug}_thumb.jpg`.
///
/// M-011: Thumbnail wird automatisch generiert und gespeichert.
Future<String?> copyImageToLocalDirectory({
  Uint8List? bildBytes,
  String? bildPfad,
  required int artikelId,
  required String artikelName,
}) async {
  if (bildBytes == null && bildPfad == null) return null;

  try {
    final imagesDir = await _getImagesDir();
    _logger.d('imagesDir: ${imagesDir.path}');
    _logger.d('bildBytes null: ${bildBytes == null}');
    _logger.d('bildPfad: $bildPfad');

    final nameSlug = _slug(artikelName.isEmpty ? 'artikel' : artikelName);
    final fileName = '${artikelId}_$nameSlug.jpg';
    final localImagePath = p.join(imagesDir.path, fileName);

    // Haupt-Bytes ermitteln
    final Uint8List? sourceBytes;
    if (bildBytes != null) {
      await File(localImagePath).writeAsBytes(bildBytes);
      sourceBytes = bildBytes;
    } else if (bildPfad != null) {
      final sourceFile = File(bildPfad);
      if (await sourceFile.exists()) {
        await sourceFile.copy(localImagePath);
        sourceBytes = await sourceFile.readAsBytes();
      } else {
        _logger.w('[copyImageToLocalDirectory] Quelldatei nicht gefunden: $bildPfad');
        return null;
      }
    } else {
      return null;
    }

    // M-011: Thumbnail generieren und speichern (fire-and-forget)
    unawaited(_generateAndSaveThumbnail(  // ← unawaited() statt nacktem Aufruf
      sourceBytes: sourceBytes,
      artikelId: artikelId,
      nameSlug: nameSlug,
      imagesDir: imagesDir,
    ),);

    return localImagePath;
  } catch (e, st) {
    _logger.e('[copyImageToLocalDirectory] Fehler', error: e, stackTrace: st);
    return null;
  }
}

/// M-011: Generiert und speichert das Thumbnail asynchron.
/// Wird fire-and-forget aufgerufen – blockiert den Speicher-Flow nicht.
///
/// Gibt den Thumbnail-Pfad zurück (für Tests/Logging).
Future<String?> _generateAndSaveThumbnail({
  required Uint8List sourceBytes,
  required int artikelId,
  required String nameSlug,
  required Directory imagesDir,
}) async {
  try {
    final thumbBytes = await ImageProcessingUtils.generateThumbnail(sourceBytes);
    if (thumbBytes == null) {
      _logger.w('[_generateAndSaveThumbnail] Thumbnail-Bytes sind null');
      return null;
    }

    final thumbFileName = '${artikelId}_${nameSlug}_thumb.jpg';
    final thumbPath = p.join(imagesDir.path, thumbFileName);
    await File(thumbPath).writeAsBytes(thumbBytes);

    _logger.d('[_generateAndSaveThumbnail] Thumbnail gespeichert: $thumbPath');
    return thumbPath;
  } catch (e, st) {
    _logger.e('[_generateAndSaveThumbnail] Fehler', error: e, stackTrace: st);
    return null;
  }
}

/// M-011: Öffentliche Funktion zum Generieren + Speichern eines Thumbnails.
/// Wird vom ArtikelDbService nach dem Insert aufgerufen, um thumbnailPfad
/// in der DB zu setzen.
///
/// [sourceBytes]  – Originalbild-Bytes
/// [artikelId]    – Lokale DB-ID des Artikels
/// [artikelName]  – Für den Dateinamen-Slug
///
/// Gibt den Thumbnail-Pfad zurück, oder null bei Fehler.
Future<String?> generateAndSaveThumbnail({
  required Uint8List sourceBytes,
  required int artikelId,
  required String artikelName,
}) async {
  try {
    final imagesDir = await _getImagesDir();
    final nameSlug = _slug(artikelName.isEmpty ? 'artikel' : artikelName);
    return await _generateAndSaveThumbnail(
      sourceBytes: sourceBytes,
      artikelId: artikelId,
      nameSlug: nameSlug,
      imagesDir: imagesDir,
    );
  } catch (e, st) {
    _logger.e('[generateAndSaveThumbnail] Fehler', error: e, stackTrace: st);
    return null;
  }
}