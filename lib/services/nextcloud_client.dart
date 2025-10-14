//lib/services/nextcloud_client.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:xml/xml.dart' as xml;

/// Metadaten für eine Remote-Datei
class RemoteItemMeta {
  final String path;
  final String etag;
  final DateTime lastModified;
  
  RemoteItemMeta({
    required this.path,
    required this.etag,
    required this.lastModified,
  });

  @override
  String toString() => 'RemoteItemMeta(path: $path, etag: $etag, modified: $lastModified)';
}

/// WebDAV-Client für Nextcloud-Kommunikation
class NextcloudClient {
  final Uri baseUrl;
  final String username;
  final String appPassword;
  final Logger logger = Logger();

  NextcloudClient({
    required this.baseUrl,
    required this.username,
    required this.appPassword,
  });

  /// HTTP-Headers für alle Requests
  Map<String, String> get _headers => {
    'Authorization': 'Basic ${base64Encode(utf8.encode('$username:$appPassword'))}',
    'User-Agent': 'ElektronikVerwaltung/1.0',
  };

  /// Testet die Verbindung zur Nextcloud
  Future<bool> testConnection() async {
    try {
      final response = await http.head(
        baseUrl,
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      
      logger.d('Connection test response: ${response.statusCode}');
      return [200, 201, 204, 404].contains(response.statusCode); // 404 ok wenn Ordner nicht existiert
    } catch (e) {
      logger.e('Connection test failed: $e');
      return false;
    }
  }

  /// Erstellt einen Ordner auf dem Server
  Future<bool> createFolder(String path) async {
    try {
      final request = http.Request('MKCOL', baseUrl.resolve(path));
      request.headers.addAll(_headers);

      final streamedResponse = await http.Client().send(request);
      final success = [201, 405].contains(streamedResponse.statusCode); // 405 = bereits vorhanden
      
      logger.d('Create folder $path: ${streamedResponse.statusCode}');
      return success;
    } catch (e) {
      logger.e('Failed to create folder $path: $e');
      return false;
    }
  }

  /// Listet alle .json Dateien im items/ Ordner mit ihren ETags
  Future<List<RemoteItemMeta>> listItemsEtags() async {
    try {
      const propfindBody = '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:getetag/>
    <d:getlastmodified/>
  </d:prop>
</d:propfind>''';

      final request = http.Request('PROPFIND', baseUrl.resolve('items/'));
      request.headers.addAll({
        ..._headers,
        'Depth': '1',
        'Content-Type': 'application/xml',
      });
      request.body = propfindBody;

      final streamedResponse = await http.Client().send(request);
      
      if (streamedResponse.statusCode != 207) {
        throw Exception('PROPFIND failed: ${streamedResponse.statusCode}');
      }

      final responseBody = await streamedResponse.stream.bytesToString();
      return _parsePropfindResponse(responseBody);
    } catch (e) {
      logger.e('Failed to list items: $e');
      rethrow;
    }
  }

  /// Parst die PROPFIND XML-Response robust mit package:xml
  List<RemoteItemMeta> _parsePropfindResponse(String xmlString) {
    final items = <RemoteItemMeta>[];
    try {
      final doc = xml.XmlDocument.parse(xmlString);
      final responses = doc.findAllElements('response', namespace: 'DAV:');

      for (final resp in responses) {
        // href
        final hrefEl = resp.findElements('href', namespace: 'DAV:').firstOrNull;
        if (hrefEl == null) continue;
        var href = hrefEl.innerText;
        if (!href.endsWith('.json')) continue;

        // getetag und getlastmodified aus propstat/prop
        String? etag;
        DateTime? lastModified;
        final propstats = resp.findAllElements('propstat', namespace: 'DAV:');
        for (final ps in propstats) {
          final prop = ps.findElements('prop', namespace: 'DAV:').firstOrNull;
          if (prop == null) continue;
          final etagEl = prop.findElements('getetag', namespace: 'DAV:').firstOrNull;
          final lmEl = prop.findElements('getlastmodified', namespace: 'DAV:').firstOrNull;
          if (etagEl != null) etag = etagEl.innerText.replaceAll('"', '');
          if (lmEl != null) {
            try {
              lastModified = DateTime.tryParse(lmEl.innerText);
            } catch (_) {}
          }
        }

        if (etag == null) continue;

        // Dateiname extrahieren
        final segments = href.split('/');
        final filename = segments.isNotEmpty ? segments.last : href;

        items.add(RemoteItemMeta(
          path: filename,
          etag: etag,
          lastModified: lastModified ?? DateTime.now(),
        ));
      }

      logger.i('Found ${items.length} items on server');
      return items;
    } catch (e) {
      logger.e('XML parse error: $e');
      return [];
    }
  }

  /// Lädt eine Datei vom Server
  Future<String> downloadItem(String path) async {
    try {
      final response = await http.get(
        baseUrl.resolve('items/$path'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        logger.d('Downloaded $path (${response.body.length} bytes)');
        return response.body;
      }
      
      throw Exception('Download failed: ${response.statusCode} ${response.reasonPhrase}');
    } catch (e) {
      logger.e('Failed to download $path: $e');
      rethrow;
    }
  }

  /// Lädt eine Datei zum Server hoch
  /// 
  /// Rückgabe:
  /// - String: neues ETag bei Erfolg
  /// - null: Konflikt (412 Precondition Failed)
  /// - Exception: anderer Fehler
  Future<String?> uploadItem(String path, String body, {String? ifMatch}) async {
    try {
      final headers = {..._headers, 'Content-Type': 'application/json'};
      if (ifMatch != null) {
        headers['If-Match'] = ifMatch;
      }

      final response = await http.put(
        baseUrl.resolve('items/$path'),
        headers: headers,
        body: body,
      );

      if ([200, 201, 204].contains(response.statusCode)) {
        final etag = response.headers['etag']?.replaceAll('"', '');
        logger.d('Uploaded $path (ETag: $etag)');
        return etag ?? 'unknown';
      }
      
      if (response.statusCode == 412) {
        logger.w('Upload conflict for $path: If-Match failed');
        return null; // Konflikt
      }
      
      throw Exception('Upload failed: ${response.statusCode} ${response.reasonPhrase}');
    } catch (e) {
      logger.e('Failed to upload $path: $e');
      rethrow;
    }
  }

  /// Löscht eine Datei vom Server
  Future<bool> deleteItem(String path) async {
    try {
      final response = await http.delete(
        baseUrl.resolve('items/$path'),
        headers: _headers,
      );

      final success = [200, 204, 404].contains(response.statusCode); // 404 ok wenn bereits gelöscht
      logger.d('Delete $path: ${response.statusCode}');
      return success;
    } catch (e) {
      logger.e('Failed to delete $path: $e');
      return false;
    }
  }

  /// Lädt ein Anhang/Bild zum Server hoch
  Future<String?> uploadAttachment(String itemUUID, String filename, List<int> data, {String? contentType}) async {
    try {
      final path = 'attachments/$itemUUID/$filename';
      final headers = {
        ..._headers,
        'Content-Type': contentType ?? 'application/octet-stream',
      };

      final response = await http.put(
        baseUrl.resolve(path),
        headers: headers,
        body: data,
      );

      if ([200, 201, 204].contains(response.statusCode)) {
        final etag = response.headers['etag']?.replaceAll('"', '');
        logger.d('Uploaded attachment $path (${data.length} bytes, ETag: $etag)');
        return etag ?? 'unknown';
      }
      
      throw Exception('Attachment upload failed: ${response.statusCode} ${response.reasonPhrase}');
    } catch (e) {
      logger.e('Failed to upload attachment $itemUUID/$filename: $e');
      rethrow;
    }
  }

  /// Lädt ein Anhang/Bild vom Server
  Future<List<int>> downloadAttachment(String itemUUID, String filename) async {
    try {
      final path = 'attachments/$itemUUID/$filename';
      final response = await http.get(
        baseUrl.resolve(path),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        logger.d('Downloaded attachment $path (${response.bodyBytes.length} bytes)');
        return response.bodyBytes;
      }
      
      throw Exception('Attachment download failed: ${response.statusCode} ${response.reasonPhrase}');
    } catch (e) {
      logger.e('Failed to download attachment $itemUUID/$filename: $e');
      rethrow;
    }
  }
}