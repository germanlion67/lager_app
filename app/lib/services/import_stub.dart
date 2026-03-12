// lib/services/import_stub.dart
// Web-Stubs: Datei-Operationen sind im Web nicht verfügbar.

import 'dart:typed_data';
import 'package:archive/archive.dart' show ArchiveFile;
import '../models/artikel_model.dart';

Future<String> readFileAsString(String path) async {
  throw UnsupportedError('readFileAsString im Web nicht verfügbar');
}

Future<Uint8List> readFileBytes(String path) async {
  throw UnsupportedError('readFileBytes im Web nicht verfügbar');
}

Future<List<Artikel>> extractImagesToLocal(
  List<Artikel> artikelList,
  List<ArchiveFile> imageFiles,
  List<String> errors,
) async {
  // Web: Bilder werden nicht lokal gespeichert
  return artikelList;
}