// test/services/nextcloud_client_test.dart
//
// T-003: Unit-Tests für NextcloudClient
//
// Strategie:
// - MockClient aus package:http/testing.dart — kein Netzwerk nötig
// - http.Client wird über Konstruktor-Parameter injiziert
// - Jede WebDAV-Methode wird mit Success-, Fehler- und Edge-Cases getestet
// - PROPFIND-Responses als XML-Fixtures inline
//
// Abgedeckt:
// - testConnection: Success, Server-Fehler, Timeout
// - createFolder: 201 Created, 405 Already Exists, Fehler
// - listItemsEtags: PROPFIND 207 mit XML-Parsing, leere Response, Fehler
// - downloadItem: 200 OK, 404 Not Found
// - uploadItem: 201 mit ETag, 412 Conflict, Fehler
// - deleteItem: 204 OK, 404 idempotent, Fehler
// - uploadAttachment: 201 mit ETag, Fehler
// - downloadAttachment: 200 OK, Fehler
// - _parsePropfindResponse: Diverse XML-Varianten (indirekt via listItemsEtags)
// - _parseHttpDate: RFC 7231 Format (indirekt via listItemsEtags)
// - RemoteItemMeta: equality, copyWith, toString

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lager_app/services/nextcloud_client.dart';

void main() {
  // ── Konstanten & Helpers ───────────────────────────────────────────────────

  const kBaseUrl = 'https://cloud.example.com/remote.php/dav/files/user/app/';
  const kUser = 'testuser';
  const kPass = 'testpass';

  /// Erzeugt einen NextcloudClient mit injiziertem MockClient.
  NextcloudClient makeClient(MockClient mockHttp) => NextcloudClient(
        baseUrl: Uri.parse(kBaseUrl),
        username: kUser,
        appPassword: kPass,
        client: mockHttp,
      );

  /// Minimale gültige PROPFIND-Response mit 1 Item.
  String propfindXml({
    String filename = 'item1.json',
    String etag = 'abc123',
    String lastModified = 'Thu, 01 Jan 2026 12:00:00 GMT',
  }) =>
      '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/remote.php/dav/files/user/app/items/</d:href>
    <d:propstat>
      <d:prop>
        <d:getetag>"folder-etag"</d:getetag>
        <d:getlastmodified>Thu, 01 Jan 2026 00:00:00 GMT</d:getlastmodified>
      </d:prop>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/remote.php/dav/files/user/app/items/$filename</d:href>
    <d:propstat>
      <d:prop>
        <d:getetag>"$etag"</d:getetag>
        <d:getlastmodified>$lastModified</d:getlastmodified>
      </d:prop>
    </d:propstat>
  </d:response>
</d:multistatus>''';

  /// Leere PROPFIND-Response (nur Ordner, keine Dateien).
  String emptyPropfindXml() => '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/remote.php/dav/files/user/app/items/</d:href>
    <d:propstat>
      <d:prop>
        <d:getetag>"folder-etag"</d:getetag>
        <d:getlastmodified>Thu, 01 Jan 2026 00:00:00 GMT</d:getlastmodified>
      </d:prop>
    </d:propstat>
  </d:response>
</d:multistatus>''';

  /// PROPFIND mit mehreren Items.
  String multiItemPropfindXml() =>
      '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/remote.php/dav/files/user/app/items/</d:href>
    <d:propstat>
      <d:prop>
        <d:getetag>"folder"</d:getetag>
        <d:getlastmodified>Thu, 01 Jan 2026 00:00:00 GMT</d:getlastmodified>
      </d:prop>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/remote.php/dav/files/user/app/items/item1.json</d:href>
    <d:propstat>
      <d:prop>
        <d:getetag>"etag1"</d:getetag>
        <d:getlastmodified>Mon, 10 Mar 2025 08:30:00 GMT</d:getlastmodified>
      </d:prop>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/remote.php/dav/files/user/app/items/item2.json</d:href>
    <d:propstat>
      <d:prop>
        <d:getetag>"etag2"</d:getetag>
        <d:getlastmodified>Tue, 11 Mar 2025 09:45:00 GMT</d:getlastmodified>
      </d:prop>
    </d:propstat>
  </d:response>
</d:multistatus>''';

  // ── RemoteItemMeta ─────────────────────────────────────────────────────────

  group('RemoteItemMeta', () {
    test('equality basiert auf path und etag', () {
      final a = RemoteItemMeta(
        path: 'item.json',
        etag: 'abc',
        lastModified: DateTime(2025),
      );
      final b = RemoteItemMeta(
        path: 'item.json',
        etag: 'abc',
        lastModified: DateTime(2026), // anderes Datum — trotzdem gleich
      );
      final c = RemoteItemMeta(
        path: 'item.json',
        etag: 'xyz',
        lastModified: DateTime(2025),
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });

    test('copyWith erstellt Kopie mit geänderten Feldern', () {
      final original = RemoteItemMeta(
        path: 'old.json',
        etag: 'e1',
        lastModified: DateTime(2025),
      );
      final copied = original.copyWith(path: 'new.json', etag: 'e2');

      expect(copied.path, 'new.json');
      expect(copied.etag, 'e2');
      expect(copied.lastModified, original.lastModified);
    });

    test('toString enthält alle Felder', () {
      final meta = RemoteItemMeta(
        path: 'test.json',
        etag: 'abc',
        lastModified: DateTime.utc(2025, 3, 10),
      );

      expect(meta.toString(), contains('test.json'));
      expect(meta.toString(), contains('abc'));
    });
  });

  // ── testConnection ─────────────────────────────────────────────────────────

  group('testConnection()', () {
    test('gibt true bei Status 200 zurück', () async {
      final mock = MockClient((_) async => http.Response('', 200));
      final client = makeClient(mock);

      expect(await client.testConnection(), isTrue);
    });

    test('gibt true bei Status 404 zurück (Server erreichbar)', () async {
      final mock = MockClient((_) async => http.Response('', 404));
      final client = makeClient(mock);

      expect(await client.testConnection(), isTrue);
    });

    test('gibt false bei Status 500 zurück', () async {
      final mock = MockClient((_) async => http.Response('', 500));
      final client = makeClient(mock);

      expect(await client.testConnection(), isFalse);
    });

    test('gibt false bei Exception zurück', () async {
      final mock = MockClient((_) async => throw Exception('network error'));
      final client = makeClient(mock);

      expect(await client.testConnection(), isFalse);
    });

    test('sendet korrekte Auth-Header', () async {
      String? capturedAuth;
      final mock = MockClient((request) async {
        capturedAuth = request.headers['Authorization'];
        return http.Response('', 200);
      });
      final client = makeClient(mock);

      await client.testConnection();

      final expectedAuth =
          'Basic ${base64Encode(utf8.encode('$kUser:$kPass'))}';
      expect(capturedAuth, expectedAuth);
    });
  });

  // ── createFolder ───────────────────────────────────────────────────────────

  group('createFolder()', () {
    test('gibt true bei Status 201 zurück', () async {
      final mock = MockClient(
        (request) async {
          expect(request.method, 'MKCOL');
          return http.Response('', 201);
        },
      );
      final client = makeClient(mock);

      expect(await client.createFolder('items/'), isTrue);
    });

    test('gibt true bei Status 405 (Ordner existiert)', () async {
      final mock = MockClient((_) async => http.Response('', 405));
      final client = makeClient(mock);

      expect(await client.createFolder('items/'), isTrue);
    });

    test('gibt false bei Status 500', () async {
      final mock = MockClient((_) async => http.Response('', 500));
      final client = makeClient(mock);

      expect(await client.createFolder('items/'), isFalse);
    });

    test('gibt false bei Exception', () async {
      final mock = MockClient((_) async => throw Exception('timeout'));
      final client = makeClient(mock);

      expect(await client.createFolder('items/'), isFalse);
    });
  });

  // ── listItemsEtags ────────────────────────────────────────────────────────

  group('listItemsEtags()', () {
    test('parst PROPFIND-Response mit einem Item', () async {
      final mock = MockClient(
        (request) async {
          expect(request.method, 'PROPFIND');
          expect(request.headers['Depth'], '1');
          return http.Response(propfindXml(), 207);
        },
      );
      final client = makeClient(mock);

      final items = await client.listItemsEtags();

      expect(items, hasLength(1));
      expect(items.first.path, 'item1.json');
      expect(items.first.etag, 'abc123');
      expect(items.first.lastModified, DateTime.utc(2026, 1, 1, 12, 0, 0));
    });

    test('parst PROPFIND-Response mit mehreren Items', () async {
      final mock = MockClient(
        (_) async => http.Response(multiItemPropfindXml(), 207),
      );
      final client = makeClient(mock);

      final items = await client.listItemsEtags();

      expect(items, hasLength(2));
      expect(items[0].path, 'item1.json');
      expect(items[0].etag, 'etag1');
      expect(items[1].path, 'item2.json');
      expect(items[1].etag, 'etag2');
      expect(items[1].lastModified, DateTime.utc(2025, 3, 11, 9, 45, 0));
    });

    test('gibt leere Liste bei leerem Ordner zurück', () async {
      final mock = MockClient(
        (_) async => http.Response(emptyPropfindXml(), 207),
      );
      final client = makeClient(mock);

      final items = await client.listItemsEtags();

      expect(items, isEmpty);
    });

    test('wirft Exception bei Nicht-207-Status', () async {
      final mock = MockClient(
        (_) async => http.Response('Forbidden', 403),
      );
      final client = makeClient(mock);

      expect(
        () => client.listItemsEtags(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('PROPFIND failed: 403'),
        ),),
      );
    });

    test('filtert Nicht-JSON-Dateien heraus', () async {
      final xmlWithNonJson = '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/remote.php/dav/files/user/app/items/</d:href>
    <d:propstat>
      <d:prop>
        <d:getetag>"folder"</d:getetag>
        <d:getlastmodified>Thu, 01 Jan 2026 00:00:00 GMT</d:getlastmodified>
      </d:prop>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/remote.php/dav/files/user/app/items/readme.txt</d:href>
    <d:propstat>
      <d:prop>
        <d:getetag>"txt-etag"</d:getetag>
        <d:getlastmodified>Thu, 01 Jan 2026 00:00:00 GMT</d:getlastmodified>
      </d:prop>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/remote.php/dav/files/user/app/items/data.json</d:href>
    <d:propstat>
      <d:prop>
        <d:getetag>"json-etag"</d:getetag>
        <d:getlastmodified>Thu, 01 Jan 2026 00:00:00 GMT</d:getlastmodified>
      </d:prop>
    </d:propstat>
  </d:response>
</d:multistatus>''';

      final mock = MockClient(
        (_) async => http.Response(xmlWithNonJson, 207),
      );
      final client = makeClient(mock);

      final items = await client.listItemsEtags();

      expect(items, hasLength(1));
      expect(items.first.path, 'data.json');
    });

    test('überspringt Einträge ohne ETag', () async {
      final xmlNoEtag = '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/remote.php/dav/files/user/app/items/no-etag.json</d:href>
    <d:propstat>
      <d:prop>
        <d:getlastmodified>Thu, 01 Jan 2026 00:00:00 GMT</d:getlastmodified>
      </d:prop>
    </d:propstat>
  </d:response>
</d:multistatus>''';

      final mock = MockClient(
        (_) async => http.Response(xmlNoEtag, 207),
      );
      final client = makeClient(mock);

      final items = await client.listItemsEtags();

      expect(items, isEmpty);
    });

    test('nutzt benutzerdefinierten folderPath', () async {
      Uri? capturedUri;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(emptyPropfindXml(), 207);
      });
      final client = makeClient(mock);

      await client.listItemsEtags(folderPath: 'custom/path/');

      expect(capturedUri.toString(), contains('custom/path/'));
    });
  });

  // ── downloadItem ───────────────────────────────────────────────────────────

  group('downloadItem()', () {
    test('gibt Body bei Status 200 zurück', () async {
      final mock = MockClient((request) async {
        expect(request.url.toString(), contains('items/test.json'));
        return http.Response('{"name":"Test"}', 200);
      });
      final client = makeClient(mock);

      final body = await client.downloadItem('test.json');

      expect(body, '{"name":"Test"}');
    });

    test('wirft Exception bei Status 404', () async {
      final mock = MockClient(
        (_) async => http.Response('Not Found', 404),
      );
      final client = makeClient(mock);

      expect(
        () => client.downloadItem('missing.json'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Download failed: 404'),
        ),),
      );
    });

    test('wirft Exception bei Netzwerkfehler', () async {
      final mock = MockClient(
        (_) async => throw Exception('connection refused'),
      );
      final client = makeClient(mock);

      expect(() => client.downloadItem('test.json'), throwsException);
    });
  });

  // ── uploadItem ─────────────────────────────────────────────────────────────

  group('uploadItem()', () {
    test('gibt ETag bei Status 201 zurück', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.body, '{"data":1}');
        return http.Response('', 201, headers: {'etag': '"new-etag"'});
      });
      final client = makeClient(mock);

      final etag = await client.uploadItem('item.json', '{"data":1}');

      expect(etag, 'new-etag');
    });

    test('sendet If-Match Header wenn angegeben', () async {
      String? capturedIfMatch;
      final mock = MockClient((request) async {
        capturedIfMatch = request.headers['If-Match'];
        return http.Response('', 204, headers: {'etag': '"updated"'});
      });
      final client = makeClient(mock);

      await client.uploadItem('item.json', '{}', ifMatch: 'old-etag');

      expect(capturedIfMatch, 'old-etag');
    });

    test('gibt null bei Status 412 (Conflict) zurück', () async {
      final mock = MockClient(
        (_) async => http.Response('Precondition Failed', 412),
      );
      final client = makeClient(mock);

      final etag = await client.uploadItem(
        'item.json',
        '{}',
        ifMatch: 'stale',
      );

      expect(etag, isNull);
    });

    test('wirft Exception bei Status 500', () async {
      final mock = MockClient(
        (_) async => http.Response('Server Error', 500),
      );
      final client = makeClient(mock);

      expect(
        () => client.uploadItem('item.json', '{}'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Upload failed: 500'),
        ),),
      );
    });

    test('gibt null zurück wenn kein ETag im Response', () async {
      final mock = MockClient(
        (_) async => http.Response('', 201, headers: {}),
      );
      final client = makeClient(mock);

      final etag = await client.uploadItem('item.json', '{}');

      expect(etag, isNull);
    });
  });

  // ── deleteItem ─────────────────────────────────────────────────────────────

  group('deleteItem()', () {
    test('gibt true bei Status 204 zurück', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'DELETE');
        return http.Response('', 204);
      });
      final client = makeClient(mock);

      expect(await client.deleteItem('item.json'), isTrue);
    });

    test('gibt true bei Status 404 (idempotent)', () async {
      final mock = MockClient(
        (_) async => http.Response('Not Found', 404),
      );
      final client = makeClient(mock);

      expect(await client.deleteItem('already-gone.json'), isTrue);
    });

    test('gibt false bei Status 500', () async {
      final mock = MockClient(
        (_) async => http.Response('Error', 500),
      );
      final client = makeClient(mock);

      expect(await client.deleteItem('item.json'), isFalse);
    });

    test('gibt false bei Exception', () async {
      final mock = MockClient(
        (_) async => throw Exception('timeout'),
      );
      final client = makeClient(mock);

      expect(await client.deleteItem('item.json'), isFalse);
    });
  });

  // ── uploadAttachment ───────────────────────────────────────────────────────

  group('uploadAttachment()', () {
    test('gibt ETag bei Erfolg zurück', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.toString(), contains('attachments'));
        expect(request.url.toString(), contains('uuid-123'));
        expect(request.url.toString(), contains('photo.jpg'));
        return http.Response('', 201, headers: {'etag': '"att-etag"'});
      });
      final client = makeClient(mock);

      final etag = await client.uploadAttachment(
        'uuid-123',
        'photo.jpg',
        [1, 2, 3],
        contentType: 'image/jpeg',
      );

      expect(etag, 'att-etag');
    });

    test('sendet korrekten Content-Type', () async {
      String? capturedContentType;
      final mock = MockClient((request) async {
        capturedContentType = request.headers['Content-Type'];
        return http.Response('', 201, headers: {'etag': '"e"'});
      });
      final client = makeClient(mock);

      await client.uploadAttachment('u', 'f', [1],
          contentType: 'image/png',);

      expect(capturedContentType, 'image/png');
    },);

    test('nutzt application/octet-stream als Default', () async {
      String? capturedContentType;
      final mock = MockClient((request) async {
        capturedContentType = request.headers['Content-Type'];
        return http.Response('', 201, headers: {'etag': '"e"'});
      });
      final client = makeClient(mock);

      await client.uploadAttachment('u', 'f', [1]);

      expect(capturedContentType, 'application/octet-stream');
    });

    test('wirft Exception bei Status 500', () async {
      final mock = MockClient(
        (_) async => http.Response('Error', 500),
      );
      final client = makeClient(mock);

      expect(
        () => client.uploadAttachment('u', 'f', [1]),
        throwsException,
      );
    });
  });

  // ── downloadAttachment ─────────────────────────────────────────────────────

  group('downloadAttachment()', () {
    test('gibt Bytes bei Status 200 zurück', () async {
      final mock = MockClient((request) async {
        expect(request.url.toString(), contains('attachments'));
        expect(request.url.toString(), contains('uuid-456'));
        expect(request.url.toString(), contains('image.png'));
        return http.Response.bytes([10, 20, 30], 200);
      });
      final client = makeClient(mock);

      final bytes = await client.downloadAttachment('uuid-456', 'image.png');

      expect(bytes, [10, 20, 30]);
    });

    test('wirft Exception bei Status 404', () async {
      final mock = MockClient(
        (_) async => http.Response('Not Found', 404),
      );
      final client = makeClient(mock);

      expect(
        () => client.downloadAttachment('u', 'missing.png'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Attachment download failed: 404'),
        ),),
      );
    });
  });

  // ── URI-Auflösung (indirekt) ───────────────────────────────────────────────

  group('URI-Auflösung', () {
    test('items-Pfad wird korrekt aufgelöst', () async {
      Uri? capturedUri;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{}', 200);
      });
      final client = makeClient(mock);

      await client.downloadItem('test-uuid.json');

      expect(
        capturedUri.toString(),
        contains('items/test-uuid.json'),
      );
    });

    test('attachments-Pfad wird korrekt aufgelöst', () async {
      Uri? capturedUri;
      final mock = MockClient((request) async {
        capturedUri = request.url;
        return http.Response.bytes([1], 200);
      });
      final client = makeClient(mock);

      await client.downloadAttachment('my-uuid', 'file.bin');

      final uriStr = capturedUri.toString();
      expect(uriStr, contains('attachments'));
      expect(uriStr, contains('my-uuid'));
      expect(uriStr, contains('file.bin'));
    });
  });
}