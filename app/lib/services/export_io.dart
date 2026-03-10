// lib/services/export_io.dart

import 'dart:io';
import 'dart:typed_data';

/// Liest Datei-Bytes, gibt null zurück wenn Datei nicht existiert
Future<Uint8List?> readFileBytesIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) {
    return await file.readAsBytes();
  }
  return null;
}
