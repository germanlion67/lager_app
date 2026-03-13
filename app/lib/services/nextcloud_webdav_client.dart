// lib/services/nextcloud_webdav_client.dart

// Warum MKCOL & PUT?
// Mit MKCOL legst du WebDAV‑Ordner an; mit PUT lädst du Dateiinhalt
// hoch. Das ist der von Nextcloud unterstützte Standardweg über
// remote.php/dav.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
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
  final Uri serverBase;          // z.B. https://cloud.example.com
  final String username;         // Nextcloud Benutzername
  final String appPassword;      // App-Passwort (empfohlen)
  final String baseRemoteFolder; // z.B. "Apps/Artikel" (optional)

  const NextcloudConfig({
    required this.serverBase,
    required this.username,
    required this.appPassword,
    this.baseRemoteFolder = 'Apps/Artikel',
  });

  /// Baut die vollständige WebDAV-Basis:
  /// https://host/remote.php/dav/files/`<username>`/
  Uri get webDavRoot => serverBase.replace(
        path: '/remote.php/dav/files/$username/',
      );
}

/// Minimaler WebDAV-Client (PUT, MKCOL) für Nextcloud.
/// Siehe Nextcloud WebDAV-Doku (remote.php/dav).
/// https://docs.nextcloud.com/server/latest/developer_manual/client_apis/WebDAV/basic.html
class NextcloudWebDavClient {
  final NextcloudConfig config;

  NextcloudWebDavClient(this.config);

  /// Auth-Header ohne Content-Type — jede Methode setzt ihren eigenen.
  Map<String, String> get _authHeader {
    final auth = base64Encode(
      utf8.encode('${config.username}:${config.appPassword}'),
    );
    return {'Authorization': 'Basic $auth'};
  }

  /// Prüft/legt einen Zielordner rekursiv an (MKCOL).
  Future<void> ensureFolder(String folderPath) async {
    try {
      final segments = folderPath.split('/');
      String currentPath = '';

      for (final segment in segments) {
        if (segment.isEmpty) continue;
        currentPath =
            currentPath.isEmpty ? segment : '$currentPath/$segment';

        final targetUri = config.webDavRoot.resolve(currentPath);
        final client = http.Client();
        try {
          final request = http.Request('MKCOL', targetUri);
          request.headers.addAll(_authHeader);

          final response = await client
              .send(request)
              .timeout(const Duration(seconds: 30));
          final statusCode = response.statusCode;

          // 201 = Created, 405 = Already exists
          if (statusCode != 201 && statusCode != 405) {
            throw WebDavException(
              'Failed to create folder $currentPath: $statusCode',
            );
          }
        } finally {
          client.close();
        }
      }
    } catch (e) {
      if (e is WebDavException) rethrow;
      throw WebDavException('Network error creating folder: $e');
    }
  }

  /// Lädt eine Datei zu Nextcloud hoch (Legacy-Methode).
  Future<void> uploadFile(
    String localPath,
    String remoteFolder, [
    String? customFilename,
  ]) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        throw WebDavException('File not found: $localPath');
      }

      try {
        await file.readAsBytes();
      } catch (e) {
        throw WebDavException(
          'Cannot read file (permission denied): $localPath',
        );
      }

      final filename = customFilename ?? p.basename(localPath);
      final remotePath = p.posix.join(remoteFolder, filename);

      await ensureFolder(remoteFolder);

      final bytes = await file.readAsBytes();
      final targetUri = config.webDavRoot.resolve(remotePath);

      final response = await http.put(
        targetUri,
        headers: {
          ..._authHeader,
          'Content-Type': 'application/octet-stream',
        },
        body: bytes,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 201 && response.statusCode != 204) {
        throw WebDavException(
          'Upload failed with status ${response.statusCode}: $remotePath',
        );
      }
    } catch (e) {
      if (e is WebDavException) rethrow;
      throw WebDavException('Network error during upload: $e');
    }
  }

  /// Lädt eine Datei von Nextcloud herunter (Legacy-Methode).
  Future<void> downloadFile(String remotePath, String localPath) async {
    try {
      final normalizedRemotePath = remotePath
          .replaceAll('\\', '/')
          .replaceFirst(RegExp(r'^/+'), '');

      final fullRemotePath = () {
        if (normalizedRemotePath.isEmpty) return config.baseRemoteFolder;
        if (config.baseRemoteFolder.isEmpty) return normalizedRemotePath;
        final basePrefix = '${config.baseRemoteFolder}/';
        if (normalizedRemotePath == config.baseRemoteFolder ||
            normalizedRemotePath.startsWith(basePrefix)) {
          return normalizedRemotePath;
        }
        return p.posix.join(config.baseRemoteFolder, normalizedRemotePath);
      }();

      final targetUri = config.webDavRoot.resolve(fullRemotePath);

      final response = await http.get(
        targetUri,
        headers: _authHeader,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final localFile = File(localPath);
        await localFile.parent.create(recursive: true);
        await localFile.writeAsBytes(response.bodyBytes);
      } else if (response.statusCode == 404) {
        throw WebDavException('Remote file not found: $remotePath');
      } else {
        throw WebDavException(
          'Download failed with status ${response.statusCode}: $remotePath',
        );
      }
    } catch (e) {
      if (e is WebDavException) rethrow;
      throw WebDavException('Network error during download: $e');
    }
  }

  /// Listet Dateien in einem Remote-Verzeichnis auf.
  Future<List<String>> listFiles(String remoteFolderPath) async {
    final fullPath = remoteFolderPath.isEmpty
        ? config.baseRemoteFolder
        : '${config.baseRemoteFolder}/$remoteFolderPath';
    final targetUri = config.webDavRoot.resolve(fullPath);

    const maxAttempts = 3;
    var attempt = 0;
    while (true) {
      attempt++;
      final client = http.Client();
      try {
        debugPrint(
          'NextcloudWebDavClient.listFiles target=$targetUri (attempt $attempt)',
        );

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

        final streamedResponse = await client
            .send(request)
            .timeout(const Duration(seconds: 30));
        final response = await http.Response.fromStream(streamedResponse);

        debugPrint(
          'NextcloudWebDavClient.listFiles status=${response.statusCode}',
        );

        if (response.statusCode == 207) {
          final files = <String>[];
          final displayNameRegex = RegExp(
            r'<d:displayname>(.*?)</d:displayname>',
            dotAll: true,
          );
          for (final match in displayNameRegex.allMatches(response.body)) {
            final filename = match.group(1)?.trim() ?? '';
            if (filename.isNotEmpty &&
                filename != remoteFolderPath &&
                !filename.endsWith('/')) {
              files.add(filename);
            }
          }
          return files;
        } else if (response.statusCode == 404) {
          return [];
        } else if (response.statusCode >= 500 && attempt < maxAttempts) {
          final backoffMs = 500 * (1 << (attempt - 1));
          debugPrint(
            'NextcloudWebDavClient.listFiles server error '
            '${response.statusCode} - retrying in ${backoffMs}ms',
          );
          await Future<void>.delayed(Duration(milliseconds: backoffMs));
          continue;
        } else {
          throw WebDavException(
            'List files failed with status ${response.statusCode}',
          );
        }
      } catch (e) {
        if (e is WebDavException) rethrow;
        if (attempt < maxAttempts) {
          final backoffMs = 500 * (1 << (attempt - 1));
          debugPrint(
            'NextcloudWebDavClient.listFiles error: $e - '
            'retrying in ${backoffMs}ms',
          );
          await Future<void>.delayed(Duration(milliseconds: backoffMs));
          continue;
        }
        throw WebDavException('Network error listing files: $e');
      } finally {
        client.close();
      }
    }
  }

  /// Lädt Bytes zu Nextcloud hoch mit relativem Pfad.
  Future<void> uploadBytes({
    required Uint8List bytes,
    required String remoteRelativePath,
    String? contentType,
  }) async {
    final mime = contentType ??
        lookupMimeType(remoteRelativePath) ??
        'application/octet-stream';

    final targetUri = config.webDavRoot.replace(
      path: p.posix.join(
        config.webDavRoot.path,
        remoteRelativePath,
      ),
    );

    await ensureFolder(p.posix.dirname(remoteRelativePath));

    final response = await http.put(
      targetUri,
      headers: {
        ..._authHeader,
        'Content-Type': mime,
      },
      body: bytes,
    ).timeout(
      const Duration(minutes: 5),
      // FIX: Block-Syntax statt Arrow für onTimeout
      onTimeout: () {
        throw WebDavException(
          'Upload-Timeout (5 Min): $remoteRelativePath',
        );
      },
    );

    if (response.statusCode == 201 || response.statusCode == 204) return;

    if (response.statusCode == 401) {
      throw const WebDavException(
        'Unauthorized (401): Bitte App-Passwort prüfen.',
      );
    } else if (response.statusCode == 507) {
      throw const WebDavException(
        'Insufficient Storage (507): Kein Speicherplatz auf Nextcloud.',
      );
    } else if (response.statusCode == 423) {
      throw const WebDavException('Locked (423): Zieldatei gesperrt.');
    }

    throw WebDavException(
      'Upload fehlgeschlagen (${response.statusCode}): '
      '${response.body.isNotEmpty ? response.body : "<kein Body>"}',
    );
  }

  /// Lädt Bytes von Nextcloud herunter.
  Future<Uint8List> downloadBytes({
    required String remoteRelativePath,
  }) async {
    final fullPath = p.posix.join(
      config.baseRemoteFolder,
      remoteRelativePath,
    );
    final targetUri = config.webDavRoot.replace(
      path: p.posix.join(config.webDavRoot.path, fullPath),
    );

    final response = await http.get(
      targetUri,
      headers: _authHeader,
    ).timeout(
      const Duration(minutes: 3),
      onTimeout: () => throw WebDavException(
        'Download-Timeout (3 Min): $remoteRelativePath',
      ),
    );

    // FIX: Block-Syntax für if-Statement
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }

    if (response.statusCode == 401) {
      throw const WebDavException(
        'Unauthorized (401): Bitte App-Passwort prüfen.',
      );
    } else if (response.statusCode == 404) {
      throw WebDavException(
        'Not Found (404): Datei nicht gefunden: $remoteRelativePath',
      );
    }

    throw WebDavException(
      'Download fehlgeschlagen (${response.statusCode}): '
      '${response.body.isNotEmpty ? response.body : "<kein Body>"}',
    );
  }

  /// Lädt eine lokale Datei zu Nextcloud hoch.
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

  /// Lädt eine Datei von Nextcloud ins lokale Dateisystem.
  Future<void> downloadFileNew({
    required String remoteRelativePath,
    required String localPath,
  }) async {
    final bytes = await downloadBytes(
      remoteRelativePath: remoteRelativePath,
    );
    final localFile = File(localPath);
    await localFile.parent.create(recursive: true);
    await localFile.writeAsBytes(bytes);
  }

  /// Listet nur Ordner in einem Remote-Verzeichnis auf.
  Future<List<String>> listFolders(String remoteFolderPath) async {
    try {
      final fullPath = remoteFolderPath.isEmpty
          ? config.baseRemoteFolder
          : '${config.baseRemoteFolder}/$remoteFolderPath';
      final targetUri = config.webDavRoot.resolve(fullPath);

      final client = http.Client();
      try {
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

        final streamedResponse = await client
            .send(request)
            .timeout(const Duration(seconds: 30));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 207) {
          final folders = <String>[];
          final responseEntries = response.body.split('<d:response>');

          for (final entry in responseEntries) {
            if (!entry.contains('<d:collection/>')) continue;
            if (!entry.contains('<d:displayname>') ||
                !entry.contains('</d:displayname>')) {
              continue;
            }

            final start = entry.indexOf('<d:displayname>') + 15;
            final end = entry.indexOf('</d:displayname>');
            if (start >= end) continue;

            final folderName = entry.substring(start, end).trim();
            if (folderName.isNotEmpty &&
                folderName != remoteFolderPath &&
                !folderName.endsWith('/')) {
              folders.add(folderName);
            }
          }
          return folders;
        } else if (response.statusCode == 404) {
          return [];
        } else {
          throw WebDavException(
            'List folders failed with status ${response.statusCode}',
          );
        }
      } finally {
        client.close();
      }
    } catch (e) {
      if (e is WebDavException) rethrow;
      throw WebDavException('Network error listing folders: $e');
    }
  }

  /// Listet Dateien mit ihren Größen auf.
  Future<Map<String, int>> listFilesWithSize(String remoteFolderPath) async {
    try {
      final fullPath = remoteFolderPath.isEmpty
          ? config.baseRemoteFolder
          : '${config.baseRemoteFolder}/$remoteFolderPath';
      final targetUri = config.webDavRoot.resolve(fullPath);

      final client = http.Client();
      try {
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
    <d:getcontentlength/>
    <d:resourcetype/>
  </d:prop>
</d:propfind>''';

        final streamedResponse = await client
            .send(request)
            .timeout(const Duration(seconds: 30));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 207) {
          final files = <String, int>{};
          final responseRegex = RegExp(
            r'<d:response>(.*?)</d:response>',
            dotAll: true,
          );

          for (final responseMatch
              in responseRegex.allMatches(response.body)) {
            final block = responseMatch.group(1) ?? '';
            if (block.contains('<d:collection/>')) continue;

            final nameMatch = RegExp(
              r'<d:displayname>(.*?)</d:displayname>',
              dotAll: true,
            ).firstMatch(block);
            final fileName = nameMatch?.group(1)?.trim() ?? '';

            if (fileName.isNotEmpty && fileName != remoteFolderPath) {
              final sizeMatch = RegExp(
                r'<d:getcontentlength>(\d+)</d:getcontentlength>',
              ).firstMatch(block);
              final fileSize =
                  int.tryParse(sizeMatch?.group(1) ?? '0') ?? 0;
              files[fileName] = fileSize;
            }
          }
          return files;
        } else if (response.statusCode == 404) {
          return {};
        } else {
          throw WebDavException(
            'List files with size failed with status ${response.statusCode}',
          );
        }
      } finally {
        client.close();
      }
    } catch (e) {
      if (e is WebDavException) rethrow;
      throw WebDavException('Network error listing files with size: $e');
    }
  }
}

/// Automatischer ZIP-Upload in den Basisordner aus der Konfiguration.
Future<void> uploadBackupZipAuto({
  required String localZipPath,
  required NextcloudWebDavClient webdavClient,
}) async {
  final filename = p.basename(localZipPath);
  final remoteRelativePath = p.posix.join(
    webdavClient.config.baseRemoteFolder,
    filename,
  );
  await webdavClient.uploadFileNew(
    localPath: localZipPath,
    remoteRelativePath: remoteRelativePath,
  );
}