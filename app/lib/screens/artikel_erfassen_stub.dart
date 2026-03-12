// lib/screens/artikel_erfassen_stub.dart
// Stub für Web — diese Funktionen werden im Web nicht aufgerufen,
// da Bilder direkt als Bytes zu PocketBase gehen.

import 'dart:typed_data';

/// Liest Datei-Bytes von einem lokalen Pfad (Web-Stub).
Future<Uint8List> readFileBytes(String path) {
  throw UnsupportedError('readFileBytes ist im Web nicht verfügbar');
}

/// Gibt den Dateinamen aus einem Pfad zurück (Web-Stub).
String getBasename(String path) {
  throw UnsupportedError('getBasename ist im Web nicht verfügbar');
}

/// Kopiert ein Bild in das lokale App-Verzeichnis (Web-Stub).
Future<String?> copyImageToLocalDirectory({
  Uint8List? bildBytes,
  String? bildPfad,
  required int artikelId,
  required String artikelName,
}) async {
  // Im Web nicht benötigt — Bilder gehen direkt an PocketBase
  return null;
}