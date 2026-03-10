// lib/screens/artikel_erfassen_stub.dart
// Stub für Web – diese Funktionen werden im Web nicht aufgerufen,
// da Bilder direkt als Bytes zu PocketBase gehen.

import 'dart:typed_data';

Future<String?> copyImageToLocalDirectory({
  Uint8List? bildBytes,
  String? bildPfad,
  required int artikelId,
  required String artikelName,
}) async {
  // Im Web nicht verfügbar
  return null;
}

Future<Uint8List> readFileBytes(String path) async {
  throw UnsupportedError('readFileBytes ist im Web nicht verfügbar');
}
