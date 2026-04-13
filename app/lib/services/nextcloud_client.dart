// lib/services/nextcloud_client.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:xml/xml.dart' as xml;

/// Standard-Timeout für alle WebDAV-Operationen.
const Duration _kRequestTimeout = Duration(seconds: 15);

/// Metadaten für eine Remote-Datei.
class RemoteItemMeta {
  final String path;
  final String etag;
  final DateTime lastModified;

  const RemoteItemMeta({
    required this.path,
    required this.etag,
    required this.lastModified,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteItemMeta &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          etag == other.etag;

  @override
  int get hashCode => Object.hash(path, etag);

  RemoteItemMeta copyWith({
    String? path,
    String? etag,
    DateTime? lastModified,
  }) =>
      RemoteItemMeta(
        path: path ?? this.path,
        etag: etag ?? this.etag,
        lastModified: lastModified ?? this.lastModified,
      );

  @override
  String toString() =>
      'RemoteItemMeta(path: $path, etag: $etag, modified: $lastModified)';
}

/// WebDAV-Client für Nextcloud-Kommunikation.
class NextcloudClient {
  final Uri baseUrl;
  final String username;
  final http.Client _client;

  final Logger _logger = Logger();

  late final Map<String, String> _headers;

  NextcloudClient({
    required this.baseUrl,
    required this.username,
    required String appPassword,
    http.Client? client,
  }) : _client = client ?? http.Client() {
    _headers = {
      'Authorization':
          'Basic ${base64Encode(utf8.encode('$username:$appPassword'))}',
      'User-Agent': 'ElektronikVerwaltung/1.0',
    };
  }

  /// Testet die Verbindung zur Nextcloud.
  Future<bool> testConnection() async {
    try {
      final response = await _client
          .head(baseUrl, headers: _headers)
          .timeout(_kRequestTimeout);

      _logger.d('Connection test response: ${response.statusCode}');
      return [200, 201, 204, 404].contains(response.statusCode);
    } catch (e) {
      _logger.e('Connection test failed: $e');
      return false;
    }
  }

  /// Erstellt einen Ordner auf dem Server.
  Future<bool> createFolder(String path) async {
    try {
      final request = http.Request('MKCOL', _resolveUri(path));
      request.headers.addAll(_headers);

      final streamedResponse = await _client
          .send(request)
          .timeout(_kRequestTimeout);

      // 405 = Ordner existiert bereits — kein Fehler
      final success = [201, 405].contains(streamedResponse.statusCode);
      _logger.d('Create folder $path: ${streamedResponse.statusCode}');
      return success;
    } catch (e) {
      _logger.e('Failed to create folder $path: $e');
      return false;
    }
  }

  /// Listet alle Dateien im angegebenen [folderPath] mit ETags.
  Future<List<RemoteItemMeta>> listItemsEtags({
    String folderPath = 'items/',
  }) async {
    const propfindBody = '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:getetag/>
    <d:getlastmodified/>
  </d:prop>
</d:propfind>''';

    try {
      final request = http.Request('PROPFIND', _resolveUri(folderPath));
      request.headers.addAll({
        ..._headers,
        'Depth': '1',
        'Content-Type': 'application/xml',
      });
      request.body = propfindBody;

      final streamedResponse = await _client
          .send(request)
          .timeout(_kRequestTimeout);

      if (streamedResponse.statusCode != 207) {
        throw Exception(
          'PROPFIND failed: ${streamedResponse.statusCode}',
        );
      }

      final responseBody = await streamedResponse.stream.bytesToString();
      return _parsePropfindResponse(responseBody);
    } catch (e) {
      _logger.e('Failed to list items: $e');
      rethrow;
    }
  }

  /// Parst die PROPFIND XML-Response.
  List<RemoteItemMeta> _parsePropfindResponse(String xmlString) {
    final items = <RemoteItemMeta>[];
    try {
      final doc = xml.XmlDocument.parse(xmlString);
      final responses = doc.findAllElements('response', namespace: 'DAV:');

      for (final resp in responses) {
        final hrefEl =
            resp.findElements('href', namespace: 'DAV:').firstOrNull;
        if (hrefEl == null) continue;
        final href = hrefEl.innerText;
        if (!href.endsWith('.json')) continue;

        String? etag;
        DateTime? lastModified;

        final propstats =
            resp.findAllElements('propstat', namespace: 'DAV:');
        for (final ps in propstats) {
          final prop =
              ps.findElements('prop', namespace: 'DAV:').firstOrNull;
          if (prop == null) continue;

          final etagEl =
              prop.findElements('getetag', namespace: 'DAV:').firstOrNull;
          final lmEl = prop
              .findElements('getlastmodified', namespace: 'DAV:')
              .firstOrNull;

          if (etagEl != null) {
            etag = etagEl.innerText.replaceAll('"', '');
          }
          if (lmEl != null) {
            lastModified = _parseHttpDate(lmEl.innerText);
          }
        }

        if (etag == null) continue;

        final filename = href.split('/').lastWhere(
          (s) => s.isNotEmpty,
          orElse: () => href,
        );

        items.add(RemoteItemMeta(
          path: filename,
          etag: etag,
          lastModified: lastModified ?? DateTime.now(),
        ),);
      }

      _logger.i('Found ${items.length} items on server');
      return items;
    } catch (e) {
      _logger.e('XML parse error: $e');
      return [];
    }
  }

  /// Parst RFC 7231 HTTP-Datumsformat zu [DateTime].
  ///
  /// WebDAV `getlastmodified` liefert RFC 7231, kein ISO 8601.
  /// Beispiel: "Thu, 01 Jan 2026 12:00:00 GMT"
  DateTime? _parseHttpDate(String value) {
    try {
      const months = {
        'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4,
        'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8,
        'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
      };

      // Format: "Thu, 01 Jan 2026 12:00:00 GMT"
      final parts = value.trim().split(RegExp(r'[\s,]+'));
      // parts: [Thu, 01, Jan, 2026, 12:00:00, GMT]
      if (parts.length < 6) return null;

      final day = int.tryParse(parts[1]);
      final month = months[parts[2]];
      final year = int.tryParse(parts[3]);
      final timeParts = parts[4].split(':');

      if (day == null || month == null || year == null ||
          timeParts.length < 3) {
        return null;
      }

      final hour = int.tryParse(timeParts[0]);
      final minute = int.tryParse(timeParts[1]);
      final second = int.tryParse(timeParts[2]);

      if (hour == null || minute == null || second == null) return null;

      return DateTime.utc(year, month, day, hour, minute, second);
    } catch (_) {
      return null;
    }
  }

  /// Lädt eine Datei vom Server herunter.
  Future<String> downloadItem(String path) async {
    try {
      final response = await _client
          .get(_resolveUri('items/$path'), headers: _headers)
          .timeout(_kRequestTimeout);

      if (response.statusCode == 200) {
        _logger.d('Downloaded $path (${response.body.length} bytes)');
        return response.body;
      }

      throw Exception(
        'Download failed: ${response.statusCode} ${response.reasonPhrase}',
      );
    } catch (e) {
      _logger.e('Failed to download $path: $e');
      rethrow;
    }
  }

  /// Lädt eine Datei zum Server hoch.
  ///
  /// Rückgabe:
  /// - `String`: neues ETag bei Erfolg
  /// - `null`: Konflikt (412 Precondition Failed) oder kein ETag
  /// - `Exception`: anderer Fehler
  Future<String?> uploadItem(
    String path,
    String body, {
    String? ifMatch,
  }) async {
    try {
      final headers = <String, String>{
        ..._headers,
        'Content-Type': 'application/json',
      };
      if (ifMatch != null) {
        headers['If-Match'] = ifMatch;
      }

      final response = await _client
          .put(
            _resolveUri('items/$path'),
            headers: headers,
            body: body,
          )
          .timeout(_kRequestTimeout);

      if ([200, 201, 204].contains(response.statusCode)) {
        final etag = response.headers['etag']?.replaceAll('"', '');
        _logger.d('Uploaded $path (ETag: $etag)');
        return etag;
      }

      if (response.statusCode == 412) {
        _logger.w('Upload conflict for $path: If-Match failed');
        return null;
      }

      throw Exception(
        'Upload failed: ${response.statusCode} ${response.reasonPhrase}',
      );
    } catch (e) {
      _logger.e('Failed to upload $path: $e');
      rethrow;
    }
  }

  /// Löscht eine Datei vom Server.
  Future<bool> deleteItem(String path) async {
    try {
      final response = await _client
          .delete(_resolveUri('items/$path'), headers: _headers)
          .timeout(_kRequestTimeout);

      // 404 ok — bereits gelöscht (idempotent)
      final success = [200, 204, 404].contains(response.statusCode);
      _logger.d('Delete $path: ${response.statusCode}');
      return success;
    } catch (e) {
      _logger.e('Failed to delete $path: $e');
      return false;
    }
  }

  /// Lädt einen Anhang/ein Bild zum Server hoch.
  Future<String?> uploadAttachment(
    String itemUUID,
    String filename,
    List<int> data, {
    String? contentType,
  }) async {
    try {
      final uri = _resolveUriSegments(['attachments', itemUUID, filename]);
      final headers = <String, String>{
        ..._headers,
        'Content-Type': contentType ?? 'application/octet-stream',
      };

      final response = await _client
          .put(uri, headers: headers, body: data)
          .timeout(_kRequestTimeout);

      if ([200, 201, 204].contains(response.statusCode)) {
        final etag = response.headers['etag']?.replaceAll('"', '');
        _logger.d(
          'Uploaded attachment $itemUUID/$filename '
          '(${data.length} bytes, ETag: $etag)',
        );
        return etag;
      }

      throw Exception(
        'Attachment upload failed: '
        '${response.statusCode} ${response.reasonPhrase}',
      );
    } catch (e) {
      _logger.e('Failed to upload attachment $itemUUID/$filename: $e');
      rethrow;
    }
  }

  /// Lädt einen Anhang/ein Bild vom Server herunter.
  Future<List<int>> downloadAttachment(
    String itemUUID,
    String filename,
  ) async {
    try {
      final uri = _resolveUriSegments(['attachments', itemUUID, filename]);

      final response = await _client
          .get(uri, headers: _headers)
          .timeout(_kRequestTimeout);

      if (response.statusCode == 200) {
        _logger.d(
          'Downloaded attachment $itemUUID/$filename '
          '(${response.bodyBytes.length} bytes)',
        );
        return response.bodyBytes;
      }

      throw Exception(
        'Attachment download failed: '
        '${response.statusCode} ${response.reasonPhrase}',
      );
    } catch (e) {
      _logger.e('Failed to download attachment $itemUUID/$filename: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Hilfsmethoden
  // ---------------------------------------------------------------------------

  /// Löst einen relativen Pfad gegen [baseUrl] auf mit korrektem Encoding.
  Uri _resolveUri(String relativePath) {
    final encoded = Uri.encodeFull(relativePath);
    return baseUrl.resolve(encoded);
  }

  /// Löst Pfad-Segmente gegen [baseUrl] auf — jedes Segment wird
  /// einzeln encoded.
  Uri _resolveUriSegments(List<String> segments) {
    final basePath = baseUrl.path.endsWith('/')
        ? baseUrl.path
        : '${baseUrl.path}/';
    final encodedSegments = segments.map(Uri.encodeComponent).join('/');
    return baseUrl.replace(path: '$basePath$encodedSegments');
  }
}