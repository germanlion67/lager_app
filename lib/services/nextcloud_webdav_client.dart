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

/// Custom Exception für WebDAV-Fehler
class WebDavException implements Exception {
  final String message;
  
  const WebDavException(this.message);
  
  @override
  String toString() => 'WebDavException: $message';
}

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
        path: '/remote.php/dav/files/$username/',
      );
}

/// Minimaler WebDAV-Client (PUT, MKCOL) für Nextcloud.
/// Siehe Nextcloud WebDAV-Doku (remote.php/dav).  📚
/// https://docs.nextcloud.com/server/latest/developer_manual/client_apis/WebDAV/basic.html
class NextcloudWebDavClient {
  final NextcloudConfig config;

  NextcloudWebDavClient(this.config);

  Map<String, String> get _authHeader {
    final auth = base64Encode(utf8.encode('${config.username}:${config.appPassword}'));
    return {
      'Authorization': 'Basic $auth',
      'Content-Type': 'application/octet-stream',
    };
  }

  /// Prüft/legt einen Zielordner rekursiv an (MKCOL).
  Future<void> ensureFolder(String folderPath) async {
    try {
      final segments = folderPath.split('/');
      String currentPath = '';

      for (final segment in segments) {
        if (segment.isEmpty) continue; // Überspringe leere Segmente
        currentPath = currentPath.isEmpty ? segment : '$currentPath/$segment';

        final targetUri = config.webDavRoot.resolve(currentPath);
        final client = http.Client();

        final request = http.Request('MKCOL', targetUri);
        request.headers.addAll(_authHeader);

        final response = await client.send(request).timeout(const Duration(seconds: 30));
        final statusCode = response.statusCode;

        // 201 = Created, 405 = Already exists
        if (statusCode != 201 && statusCode != 405) {
          throw WebDavException('Failed to create folder $currentPath: $statusCode');
        }

        client.close();
      }
    } catch (e) {
      if (e is WebDavException) rethrow;
      throw WebDavException('Network error creating folder: $e');
    }
  }

  /// Lädt eine Datei zu Nextcloud hoch.
  /// Wirft [WebDavException] bei Fehlern.
  Future<void> uploadFile(String localPath, String remoteFolder, [String? customFilename]) async {
    try {
      // File validation
      final file = File(localPath);
      if (!await file.exists()) {
        throw WebDavException('File not found: $localPath');
      }
      
      // Check file permissions by attempting to read
      try {
        await file.readAsBytes();
      } catch (e) {
        throw WebDavException('Cannot read file (permission denied): $localPath');
      }

      final filename = customFilename ?? p.basename(localPath);
      final remotePath = p.posix.join(remoteFolder, filename);

      // Stelle sicher, dass der Zielordner existiert
      await ensureFolder(remoteFolder);

      final bytes = await file.readAsBytes();
      final targetUri = config.webDavRoot.resolve(remotePath);

      final response = await http.put(
        targetUri,
        headers: _authHeader,
        body: bytes,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 201 && response.statusCode != 204) {
        throw WebDavException('Upload failed with status ${response.statusCode}: $remotePath');
      }
    } catch (e) {
      if (e is WebDavException) rethrow;
      throw WebDavException('Network error during upload: $e');
    }
  }

  /// Downloads a file from Nextcloud to local path.
  /// Throws [WebDavException] on errors.
  Future<void> downloadFile(String remotePath, String localPath) async {
    try {
      final targetUri = config.webDavRoot.resolve(remotePath);
      
      final response = await http.get(
        targetUri,
        headers: _authHeader,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Ensure local directory exists
        final localFile = File(localPath);
        await localFile.parent.create(recursive: true);
        
        // Write file content
        await localFile.writeAsBytes(response.bodyBytes);
      } else if (response.statusCode == 404) {
        throw WebDavException('Remote file not found: $remotePath');
      } else {
        throw WebDavException('Download failed with status ${response.statusCode}: $remotePath');
      }
    } catch (e) {
      if (e is WebDavException) rethrow;
      throw WebDavException('Network error during download: $e');
    }
  }

  /// Listet Dateien/Ordner in einem Remote-Verzeichnis auf.
  Future<List<String>> listFiles(String remoteFolderPath) async {
    try {
      final targetUri = config.webDavRoot.resolve(remoteFolderPath);
      final client = http.Client();
      
      final request = http.Request('PROPFIND', targetUri);
      request.headers.addAll({
        ..._authHeader,
        'Depth': '1',
        'Content-Type': 'application/xml',
      });
      request.body = '''<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:displayname/>
  </d:prop>
</d:propfind>''';
      
      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      
      client.close();

      if (response.statusCode == 207) {
        // Parse XML response to extract file names
        // Simplified parsing - in production, use proper XML parser
        final files = <String>[];
        final lines = response.body.split('\n');
        for (final line in lines) {
          if (line.contains('<d:displayname>') && line.contains('</d:displayname>')) {
            final start = line.indexOf('<d:displayname>') + 15;
            final end = line.indexOf('</d:displayname>');
            if (start < end) {
              final filename = line.substring(start, end).trim();
              if (filename.isNotEmpty && filename != remoteFolderPath) {
                files.add(filename);
              }
            }
          }
        }
        return files;
      } else if (response.statusCode == 404) {
        return []; // Folder doesn't exist
      } else {
        throw WebDavException('List files failed with status ${response.statusCode}');
      }
    } catch (e) {
      if (e is WebDavException) rethrow;
      throw WebDavException('Network error listing files: $e');
    }
  }

  /// Lädt Bytes zu Nextcloud hoch mit relativem Pfad
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
    await ensureFolder(p.posix.dirname(remoteRelativePath));

    final response = await http.put(
      targetUri,
      headers: {
        ..._authHeader,
        'Content-Type': mime,
      },
      body: bytes,
    ).timeout(
      const Duration(minutes: 5), // Upload kann bei großen Dateien länger dauern
      onTimeout: () => throw WebDavException('Upload-Timeout (5 Min): $remoteRelativePath'),
    );

    if (response.statusCode == 201 || response.statusCode == 204) {
      // 201 Created (neue Datei) oder 204 No Content (überschrieben)
      return;
    } else if (response.statusCode == 401) {
      throw WebDavException('Unauthorized (401): Bitte App-Passwort prüfen.');
    } else if (response.statusCode == 507) {
      throw WebDavException('Insufficient Storage (507): Kein Speicherplatz auf Nextcloud.');
    } else if (response.statusCode == 423) {
      throw WebDavException('Locked (423): Zieldatei gesperrt.');
    }

    throw WebDavException(
        'Upload fehlgeschlagen (${response.statusCode}): ${response.body.isNotEmpty ? response.body : "<kein Body>"}');
  }

  /// Download einer Datei von Nextcloud
  /// [remoteRelativePath] relativ zu webDavRoot, z.B. "Apps/Artikel/backup_123/images/artikel_1_image.jpg"
  Future<Uint8List> downloadBytes({
    required String remoteRelativePath,
  }) async {
    final targetUri = config.webDavRoot.replace(
      path: p.posix.join(config.webDavRoot.path, remoteRelativePath),
    );

    final response = await http.get(
      targetUri,
      headers: _authHeader,
    ).timeout(
      const Duration(minutes: 3), // Download-Timeout
      onTimeout: () => throw WebDavException('Download-Timeout (3 Min): $remoteRelativePath'),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else if (response.statusCode == 401) {
      throw WebDavException('Unauthorized (401): Bitte App-Passwort prüfen.');
    } else if (response.statusCode == 404) {
      throw WebDavException('Not Found (404): Datei nicht gefunden: $remoteRelativePath');
    }

    throw WebDavException(
        'Download fehlgeschlagen (${response.statusCode}): ${response.body.isNotEmpty ? response.body : "<kein Body>"}');
  }

  /// Lädt eine Datei mit neuer Signatur hoch
  Future<void> uploadFileNew({
    required String localPath,
    required String remoteRelativePath,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw WebDavException('File not found: $localPath');
    }

    final bytes = await file.readAsBytes();
    await uploadBytes(
      bytes: bytes,
      remoteRelativePath: remoteRelativePath,
      contentType: lookupMimeType(localPath),
    );
  }

  /// Download einer Datei mit neuer Signatur
  Future<void> downloadFileNew({
    required String remoteRelativePath,
    required String localPath,
  }) async {
    final bytes = await downloadBytes(remoteRelativePath: remoteRelativePath);
    
    final localFile = File(localPath);
    await localFile.parent.create(recursive: true);
    await localFile.writeAsBytes(bytes);
  }

  /// Listet nur Ordner in einem Remote-Verzeichnis auf.
  Future<List<String>> listFolders(String remoteFolderPath) async {
    try {
      final targetUri = config.webDavRoot.resolve(remoteFolderPath);
      final client = http.Client();
      
      final request = http.Request('PROPFIND', targetUri);
      request.headers.addAll({
        ..._authHeader,
        'Depth': '1',
        'Content-Type': 'application/xml',
      });
      request.body = '''<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:displayname/>
    <d:resourcetype/>
  </d:prop>
</d:propfind>''';
      
      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      
      client.close();

      if (response.statusCode == 207) {
        // Parse XML response to extract folder names
        final folders = <String>[];
        final responseBody = response.body;
        
        // Split by <d:response> to get individual entries
        final responseEntries = responseBody.split('<d:response>');
        
        for (final entry in responseEntries) {
          if (entry.contains('<d:collection/>')) { // This indicates a folder
            // Extract folder name
            if (entry.contains('<d:displayname>') && entry.contains('</d:displayname>')) {
              final start = entry.indexOf('<d:displayname>') + 15;
              final end = entry.indexOf('</d:displayname>');
              if (start < end) {
                final folderName = entry.substring(start, end).trim();
                if (folderName.isNotEmpty && 
                    folderName != remoteFolderPath && 
                    !folderName.endsWith('/')) {
                  folders.add(folderName);
                }
              }
            }
          }
        }
        return folders;
      } else if (response.statusCode == 404) {
        return []; // Folder doesn't exist
      } else {
        throw WebDavException('List folders failed with status ${response.statusCode}');
      }
    } catch (e) {
      if (e is WebDavException) rethrow;
      throw WebDavException('Network error listing folders: $e');
    }
  }
}

// Automatischer ZIP-Upload in den Basisordner aus der Konfiguration
Future<void> uploadBackupZipAuto({
  required String localZipPath,
  required NextcloudWebDavClient webdavClient,
}) async {
  final filename = p.basename(localZipPath);
  final remoteRelativePath = p.posix.join(webdavClient.config.baseRemoteFolder, filename);
  await webdavClient.uploadFileNew(
    localPath: localZipPath,
    remoteRelativePath: remoteRelativePath,
  );
}