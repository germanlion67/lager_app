// lib/screens/detail_screen_io.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

String _slug(String input) {
  final s = input.toLowerCase();
  final replaced = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return replaced.replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Speichert ein Bild lokal im App-Verzeichnis
Future<String?> persistSelectedImage({
  Uint8List? bildBytes,
  String? bildPfad,
  required int artikelId,
  required String artikelName,
}) async {
  final appDir = await getApplicationDocumentsDirectory();
  final imagesDir = Directory(p.join(appDir.path, 'images'));
  await imagesDir.create(recursive: true);

  final nameSlug = _slug(artikelName.isEmpty ? 'artikel' : artikelName);
  final fileName = '${artikelId}_$nameSlug.jpg';
  final targetPath = p.join(imagesDir.path, fileName);

  if (bildBytes != null) {
    await File(targetPath).writeAsBytes(bildBytes);
    return targetPath;
  }

  if (bildPfad != null) {
    final sourceFile = File(bildPfad);
    if (await sourceFile.exists()) {
      await sourceFile.copy(targetPath);
      return targetPath;
    }
  }

  return null;
}

/// Liest Bytes einer lokalen Datei
Future<Uint8List> readFileBytes(String path) async {
  return await File(path).readAsBytes();
}

/// Prüft ob eine lokale Datei existiert
bool fileExists(String path) {
  return File(path).existsSync();
}

/// Baut ein Image.file Widget
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
  );
}
