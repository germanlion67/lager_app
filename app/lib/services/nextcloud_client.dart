// lib/services/nextcloud_client.dart
//
// Schlanker WebDAV-Client für Nextcloud.
// Designziele:
// - http.Client wird per Konstruktor injiziert → testbar ohne Netzwerk
// - Alle Methoden sind async und werfen nur bei echten Fehlern
// - RemoteItemMeta kapselt Pfad, ETag und lastModified

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

// ── RemoteItemMeta ────────────────────────────────────────────────────────────

/// Metadaten eines remote gespeicherten Items (Datei auf Nextcloud).
class RemoteItemMeta {
  final String path;
  final String etag;
  final DateTime lastModified;

  const RemoteItemMeta({
    required this.path,
    required this.etag,
    required this.lastModified,
  });

  /// Equality basiert ausschließlich auf [path] und [etag].
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
      'RemoteItemMeta(path: $path, etag: $etag, lastModified: $lastModified)';
}

// ── NextcloudClient ───────────────────────────────────────────────────────────

/// WebDAV-Client für Nextcloud.
///
/// [baseUrl] zeigt auf den App-Ordner, z.B.:
///   https://cloud.example.com/remote.php/dav/files/user/app/
///
/// Der optionale [client] erlaubt Dependency Injection für Tests.
class NextcloudClient {
  final Uri baseUrl;
  final String username;
  final String appPassword;
  final http.Client _client;

  NextcloudClient({
    required this.baseUrl,
    required this.username,
    required this.appPassword,
    http.Client? client,
  }) : _client = client ?? http.Client();

  // ── Auth ──────────────────────────────────────────────────────────────────

  Map<String, String> get _authHeader => {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$username:$appPassword'))}',
      };

  Map<String, String> get _authJsonHeader => {
        ..._authHeader,
        'Content-Type': 'application/json; charset=utf-8',
      };

  // ── URI-Helpers ───────────────────────────────────────────────────────────

  /// Löst einen relativen Pfad gegen [baseUrl] auf.
  Uri _resolve(String relativePath) {
    final base = baseUrl.toString();
    final sep = base.endsWith('/') ? '' : '/';
    return Uri.parse('$base$sep$relativePath');
  }

  Uri _itemUri(String filename) => _resolve('items/$filename');

  Uri _attachmentUri(String itemUuid, String filename) =>
      _resolve('attachments/$itemUuid/$filename');

  Uri _folderUri(String folderPath) => _resolve(folderPath);

  // ── testConnection ────────────────────────────────────────────────────────

  /// Gibt [true] zurück wenn der Server erreichbar ist (Status < 500).
  Future<bool> testConnection() async {
    try {
      final response = await _client.get(baseUrl, headers: _authHeader);
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  // ── createFolder ──────────────────────────────────────────────────────────

  /// Legt einen Ordner per MKCOL an.
  /// Gibt [true] bei 201 (Created) oder 405 (Already Exists) zurück.
  Future<bool> createFolder(String folderPath) async {
    try {
      final response = await _client.send(
        http.Request('MKCOL', _folderUri(folderPath))
          ..headers.addAll(_authHeader),
      );
      return response.statusCode == 201 || response.statusCode == 405;
    } catch (_) {
      return false;
    }
  }

  // ── listItemsEtags ────────────────────────────────────────────────────────

  /// Listet alle JSON-Dateien im [folderPath] via PROPFIND.
  /// Wirft eine [Exception] bei Status != 207.
  Future<List<RemoteItemMeta>> listItemsEtags({
    String folderPath = 'items/',
  }) async {
    final uri = _resolve(folderPath);
    final request = http.Request('PROPFIND', uri)
      ..headers.addAll({
        ..._authHeader,
        'Depth': '1',
        'Content-Type': 'application/xml',
      })
      ..body = '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:getetag/>
    <d:getlastmodified/>
  </d:prop>
</d:propfind>''';

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 207) {
      throw Exception('PROPFIND failed: ${response.statusCode}');
    }

    return _parsePropfindResponse(response.body, folderPath);
  }

  // ── downloadItem ──────────────────────────────────────────────────────────

  /// Lädt eine JSON-Datei herunter und gibt den Body zurück.
  /// Wirft eine [Exception] bei Status != 200.
  Future<String> downloadItem(String filename) async {
    final response =
        await _client.get(_itemUri(filename), headers: _authHeader);

    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }
    return response.body;
  }

  // ── uploadItem ────────────────────────────────────────────────────────────

  /// Lädt eine JSON-Datei hoch (PUT).
  /// - Gibt den ETag zurück (ohne Anführungszeichen) oder [null] wenn keiner
  ///   geliefert wurde.
  /// - Gibt [null] bei 412 Precondition Failed zurück (ETag-Konflikt).
  /// - Wirft eine [Exception] bei anderen Fehler-Status.
  Future<String?> uploadItem(
    String filename,
    String body, {
    String? ifMatch,
  }) async {
    final headers = {
      ..._authJsonHeader,
      if (ifMatch != null) 'If-Match': ifMatch,
    };

    final request = http.Request('PUT', _itemUri(filename))
      ..headers.addAll(headers)
      ..body = body;

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 412) return null;

    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw Exception('Upload failed: ${response.statusCode}');
    }

    final rawEtag = response.headers['etag'];
    if (rawEtag == null) return null;
    // Entferne umschließende Anführungszeichen: "abc123" → abc123
    return rawEtag.replaceAll('"', '');
  }

  // ── deleteItem ────────────────────────────────────────────────────────────

  /// Löscht eine Datei (DELETE).
  /// Gibt [true] bei 204 oder 404 (idempotent) zurück.
  Future<bool> deleteItem(String filename) async {
    try {
      final request = http.Request('DELETE', _itemUri(filename))
        ..headers.addAll(_authHeader);
      final streamed = await _client.send(request);
      return streamed.statusCode == 204 || streamed.statusCode == 404;
    } catch (_) {
      return false;
    }
  }

  // ── uploadAttachment ──────────────────────────────────────────────────────

  /// Lädt einen Anhang (Binärdaten) hoch.
  /// Gibt den ETag zurück oder [null] wenn keiner geliefert wurde.
  /// Wirft eine [Exception] bei Fehler-Status.
  Future<String?> uploadAttachment(
    String itemUuid,
    String filename,
    List<int> bytes, {
    String contentType = 'application/octet-stream',
  }) async {
    final request = http.Request('PUT', _attachmentUri(itemUuid, filename))
      ..headers.addAll({
        ..._authHeader,
        'Content-Type': contentType,
      })
      ..bodyBytes = bytes;

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw Exception('Attachment upload failed: ${response.statusCode}');
    }

    final rawEtag = response.headers['etag'];
    if (rawEtag == null) return null;
    return rawEtag.replaceAll('"', '');
  }

  // ── downloadAttachment ────────────────────────────────────────────────────

  /// Lädt einen Anhang herunter und gibt die Bytes zurück.
  /// Wirft eine [Exception] bei Status != 200.
  Future<List<int>> downloadAttachment(
    String itemUuid,
    String filename,
  ) async {
    final response = await _client.get(
      _attachmentUri(itemUuid, filename),
      headers: _authHeader,
    );

    if (response.statusCode != 200) {
      throw Exception('Attachment download failed: ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  // ── Interne Helpers ───────────────────────────────────────────────────────

  /// Parst eine PROPFIND-207-Response und gibt nur JSON-Dateien zurück.
  /// Der erste Eintrag (der Ordner selbst) wird übersprungen.
  List<RemoteItemMeta> _parsePropfindResponse(
    String xmlBody,
    String folderPath,
  ) {
    final document = XmlDocument.parse(xmlBody);
    final responses = document.findAllElements('response',
        namespace: 'DAV:',);

    final result = <RemoteItemMeta>[];
    bool first = true;

    for (final response in responses) {
      // Ersten Eintrag (Ordner selbst) überspringen
      if (first) {
        first = false;
        continue;
      }

      final href = response.findElements('href', namespace: 'DAV:').firstOrNull?.innerText ?? '';
      final filename = href.split('/').last;

      // Nur JSON-Dateien
      if (!filename.endsWith('.json')) continue;

      final etagRaw = response
          .findAllElements('getetag', namespace: 'DAV:')
          .firstOrNull
          ?.innerText;

      // Einträge ohne ETag überspringen
      if (etagRaw == null || etagRaw.isEmpty) continue;

      final etag = etagRaw.replaceAll('"', '');

      final lastModifiedStr = response
          .findAllElements('getlastmodified', namespace: 'DAV:')
          .firstOrNull
          ?.innerText;

      final lastModified = lastModifiedStr != null
          ? _parseHttpDate(lastModifiedStr)
          : DateTime.now();

      result.add(RemoteItemMeta(
        path: filename,
        etag: etag,
        lastModified: lastModified,
      ),);
    }

    return result;
  }

  /// Parst ein RFC 7231 HTTP-Datum, z.B.:
  ///   "Thu, 01 Jan 2026 12:00:00 GMT"
  static DateTime _parseHttpDate(String value) {
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4,
      'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8,
      'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };

    // Format: "Thu, 01 Jan 2026 12:00:00 GMT"
    try {
      final parts = value.trim().split(RegExp(r'[\s,]+'));
      // parts: [Thu, 01, Jan, 2026, 12:00:00, GMT]
      final day = int.parse(parts[1]);
      final month = months[parts[2]] ?? 1;
      final year = int.parse(parts[3]);
      final timeParts = parts[4].split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final second = int.parse(timeParts[2]);

      return DateTime.utc(year, month, day, hour, minute, second);
    } catch (_) {
      return DateTime.now();
    }
  }
}
