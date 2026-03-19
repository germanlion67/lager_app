// lib/services/import_io.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart' show ArchiveFile;
import 'package:logger/logger.dart';
import '../models/artikel_model.dart';
import 'app_log_service.dart';

// ✅ Lokale Logger-Referenz — einmal definiert, überall nutzbar
final Logger _logger = AppLogService.logger;

/// Liest eine Datei als String
Future<String> readFileAsString(String path) async {
  try {
    return await File(path).readAsString();
  } catch (e, stack) {
    // ✅ named parameters — kein await, catch mit StackTrace
    _logger.e(
      'readFileAsString fehlgeschlagen (Pfad: $path):',
      error: e,
      stackTrace: stack,
    );
    rethrow;
  }
}

/// Liest eine Datei als Bytes
Future<Uint8List> readFileBytes(String path) async {
  try {
    return await File(path).readAsBytes();
  } catch (e, stack) {
    // ✅ named parameters — kein await, catch mit StackTrace
    _logger.e(
      'readFileBytes fehlgeschlagen (Pfad: $path):',
      error: e,
      stackTrace: stack,
    );
    rethrow;
  }
}

/// Extrahiert Bilder aus ZIP-ArchiveFiles ins lokale Dateisystem
Future<List<Artikel>> extractImagesToLocal(
  List<Artikel> artikelList,
  List<ArchiveFile> imageFiles,
  List<String> errors,
) async {
  final appDir = await getApplicationDocumentsDirectory();
  final imagesDir = Directory(p.join(appDir.path, 'images'));
  await imagesDir.create(recursive: true);

  final result = List<Artikel>.from(artikelList);

  for (int i = 0; i < result.length; i++) {
    final artikel = result[i];
    final imageFile = imageFiles.firstWhere(
      (img) => img.name.contains('images/${artikel.id}_'),
      orElse: () => ArchiveFile('', 0, []),
    );

    if (imageFile.name.isNotEmpty) {
      final localImagePath = p.join(
        imagesDir.path,
        p.basename(imageFile.name),
      );
      try {
        final outFile = File(localImagePath);
        await outFile.writeAsBytes(imageFile.content as List<int>);
        result[i] = artikel.copyWith(bildPfad: localImagePath);
      } catch (e, stack) {
        errors.add('Bild-Fehler (${artikel.name}): $e');
        // ✅ named parameters — kein await, catch mit StackTrace
        _logger.e(
          'Bild schreiben fehlgeschlagen (${artikel.name}):',
          error: e,
          stackTrace: stack,
        );
        result[i] = artikel.copyWith(bildPfad: '');
      }
    } else {
      // ✅ kein await — void
      _logger.i('${artikel.name}: Kein Bild im ZIP');
      result[i] = artikel.copyWith(bildPfad: '');
    }
  }

  return result;
}