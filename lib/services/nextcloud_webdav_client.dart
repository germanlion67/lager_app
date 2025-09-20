//lib/services/nextcloud_webdav_client.dart

//Warum MKCOL & PUT?
//Mit MKCOL legst du WebDAV‑Ordner an; mit PUT lädst du Dateiinhalt
// hoch. Das ist der von Nextcloud unterstützte Standardweg über
// remote.php/dav. 1


import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

/// Konfiguration für Nextcloud
class NextcloudConfig {
  final Uri serverBase; // z.B. https://cloud.example.com
  final String username; // Nextcloud Benutzername
  final String appPassword; // App-Passwort (empfohlen)
  final String baseRemoteFolder; // z.B. "Apps/Artikel" (optional)

  const NextcloudConfig({
    required this.serverBase,
    required this.username,
    required this.appPassword,
    this.baseRemoteFolder = 'Apps/Artikel',
  });

  // Baut die vollständige WebDAV-Basis:
  // https://host/remote.php/dav/files/<username>/
  Uri get webDavRoot => serverBase.replace(
        path: p.join(serverBase.path, 'remote.php/dav/files/${Uri.encodeComponent(username)}/'),
      );
}

/// Minimaler WebDAV-Client (PUT, MKCOL) für Nextcloud.
/// Siehe Nextcloud WebDAV-Doku (remote.php/dav).  📚
/// https://docs.nextcloud.com/server/latest/developer_manual/client_apis/WebDAV/basic.html
class NextcloudWebDavClient {
  final NextcloudConfig config;

  NextcloudWebDavClient(this.config);

  Map<String, String> get _authHeader {
    final basic = base64Encode(utf8.encode('${config.username}:${config.appPassword}'));
    return {'Authorization': 'Basic $basic'};
  }

  /// Prüft/legt einen Zielordner rekursiv an (MKCOL).
  /// MKCOL auf bereits existierendem Pfad liefert 405 – das ist ok.
  Future<void> ensureRemoteFolder(String remoteFolder) async {
    final segments = p.split(remoteFolder).where((s) => s.isNotEmpty).toList();
    var current = '';
    for (final seg in segments) {
      current = p.posix.join(current, seg);
      final uri = config.webDavRoot.replace(path: p.posix.join(config.webDavRoot.path, current));
      final res = http.Request('MKCOL', uri)
        ..headers.addAll(_authHeader);
      final streamed = await res.send();
      // 201 = created, 405 = already exists -> beides okay
      if (streamed.statusCode == 201 || streamed.statusCode == 405) continue;
      if (streamed.statusCode == 401) {
        throw WebDavException('Unauthorized (401): Bitte Credentials prüfen.');
      }
      if (streamed.statusCode == 409) {
        // übergeordneter Ordner fehlt – sollte durch Rekursion vermieden werden
        throw WebDavException('Conflict (409): Übergeordneter Ordner fehlt: $current');
      }
      final body = await streamed.stream.bytesToString();
      throw WebDavException('MKCOL fehlgeschlagen (${streamed.statusCode}): $body');
    }
  }

  /// Upload einer Datei (Bytes).
  /// [remoteRelativePath] relativ zu webDavRoot, z.B. "Apps/Artikel/1234/image.jpg"
  Future<void> uploadBytes({
    required Uint8List bytes,
    required String remoteRelativePath,
    String? contentType,
  }) async {
    final mime = contentType ?? lookupMimeType(remoteRelativePath) ?? 'application/octet-stream';

    final targetUri = config.webDavRoot.replace(
      path: p.posix.join(config.webDavRoot.path, remoteRelativePath),
    );

    // Ordnerstruktur anlegen
    await ensureRemoteFolder(p.posix.dirname(remoteRelativePath));

    final res = await http.put(
      targetUri,
      headers: {
        ..._authHeader,
        'Content-Type': mime,
      },
      body: bytes,
    );

    if (res.statusCode == 201 || res.statusCode == 204) {
      // 201 Created (neue Datei) oder 204 No Content (überschrieben)
      return;
    } else if (res.statusCode == 401) {
      throw WebDavException('Unauthorized (401): Bitte App-Passwort prüfen.');
    } else if (res.statusCode == 507) {
      throw WebDavException('Insufficient Storage (507): Kein Speicherplatz auf Nextcloud.');
    } else if (res.statusCode == 423) {
      throw WebDavException('Locked (423): Zieldatei gesperrt.');
    }

    throw WebDavException(
        'Upload fehlgeschlagen (${res.statusCode}): ${res.body.isNotEmpty ? res.body : "<kein Body>"}');
  }

  /// Upload von einem lokalen Pfad (z. B. wenn file_picker .path liefert)
  Future<void> uploadFile({
    required String localPath,
    required String remoteRelativePath,
  }) async {
    final file = File(localPath);
    final bytes = await file.readAsBytes();
    await uploadBytes(bytes: bytes, remoteRelativePath: remoteRelativePath);
  }

  /// Download einer Datei von Nextcloud
  /// [remoteRelativePath] relativ zu webDavRoot, z.B. "Apps/Artikel/backup_123/images/artikel_1_image.jpg"
  Future<Uint8List> downloadBytes({
    required String remoteRelativePath,
  }) async {
    final targetUri = config.webDavRoot.replace(
      path: p.posix.join(config.webDavRoot.path, remoteRelativePath),
    );

    final res = await http.get(
      targetUri,
      headers: _authHeader,
    );

    if (res.statusCode == 200) {
      return res.bodyBytes;
    } else if (res.statusCode == 401) {
      throw WebDavException('Unauthorized (401): Bitte App-Passwort prüfen.');
    } else if (res.statusCode == 404) {
      throw WebDavException('Not Found (404): Datei nicht gefunden: $remoteRelativePath');
    }

    throw WebDavException(
        'Download fehlgeschlagen (${res.statusCode}): ${res.body.isNotEmpty ? res.body : "<kein Body>"}');
  }

  /// Download einer Datei zu einem lokalen Pfad
  Future<void> downloadFile({
    required String remoteRelativePath,
    required String localPath,
  }) async {
    final bytes = await downloadBytes(remoteRelativePath: remoteRelativePath);
    
    // Lokales Verzeichnis erstellen falls nötig
    final localFile = File(localPath);
    await localFile.parent.create(recursive: true);
    
    await localFile.writeAsBytes(bytes);
  }
}

class WebDavException implements Exception {
  final String message;
  WebDavException(this.message);
  @override
  String toString() => message;
}
