// lib/screens/artikel_erfassen_io.dart
// Plattform-spezifische Funktionen für Mobile/Desktop

import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../services/app_log_service.dart';

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

/// Kopiert das Bild ins lokale App-Verzeichnis.
Future<String?> copyImageToLocalDirectory({
  Uint8List? bildBytes,
  String? bildPfad,
  required int artikelId,
  required String artikelName,
}) async {
  if (bildBytes == null && bildPfad == null) return null;

  try {
    final appDir = await getApplicationDocumentsDirectory();
    _logger.d('appDir: ${appDir.path}');

    final imagesDir = Directory(p.join(appDir.path, 'images'));
    _logger.d('imagesDir: ${imagesDir.path}');
    _logger.d('imagesDir exists: ${await imagesDir.exists()}');
    _logger.d('bildBytes null: ${bildBytes == null}');
    _logger.d('bildPfad: $bildPfad');
      await imagesDir.create(recursive: true);

    final nameSlug = _slug(artikelName.isEmpty ? 'artikel' : artikelName);
    final fileName = '${artikelId}_$nameSlug.jpg';
    final localImagePath = p.join(imagesDir.path, fileName);

    if (bildBytes != null) {
      await File(localImagePath).writeAsBytes(bildBytes);
    } else if (bildPfad != null) {
      final sourceFile = File(bildPfad);
      if (await sourceFile.exists()) {
        await sourceFile.copy(localImagePath);
      } else {
        return null;
      }
    }

    return localImagePath;
  } catch (e, st) {
    _logger.e('[copyImageToLocalDirectory] Fehler', error: e, stackTrace: st);
    return null;
  }
}