// lib/screens/artikel_erfassen_io.dart
// Plattform-spezifische Funktionen für Mobile/Desktop

import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

String _slug(String input) {
  final s = input.toLowerCase();
  final replaced = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return replaced.replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Kopiert das Bild ins lokale App-Verzeichnis
Future<String?> copyImageToLocalDirectory({
  Uint8List? bildBytes,
  String? bildPfad,
  required int artikelId,
  required String artikelName,
}) async {
  if (bildBytes == null && bildPfad == null) return null;

  try {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'images'));
    await imagesDir.create(recursive: true);

    final nameSlug = _slug(artikelName.isEmpty ? 'artikel' : artikelName);
    final fileName = '${artikelId}_$nameSlug.jpg';
    final localImagePath = p.join(imagesDir.path, fileName);

    if (bildBytes != null) {
      final file = File(localImagePath);
      await file.writeAsBytes(bildBytes);
    } else if (bildPfad != null) {
      final sourceFile = File(bildPfad);
      if (await sourceFile.exists()) {
        await sourceFile.copy(localImagePath);
      } else {
        return null;
      }
    }

    return localImagePath;
  } catch (e) {
    return null;
  }
}

/// Liest Datei-Bytes von einem lokalen Pfad
Future<Uint8List> readFileBytes(String path) async {
  return await File(path).readAsBytes();
}
