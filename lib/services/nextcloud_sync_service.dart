//lib/services/nextcloud_sync_service.dart

import 'package:webdav_client/webdav_client.dart' as webdav;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

class NextcloudSyncService {
  final String serverUrl = 'https://deine-nextcloud-url.de/remote.php/dav/files/USERNAME/';
  final String username = 'USERNAME';
  final String password = 'PASSWORT';
  final String remoteFolder = 'ArtikelSync';

  late webdav.Client client;
  final Logger _logger = Logger();

  NextcloudSyncService() {
    client = webdav.newClient(
      serverUrl,
      user: username,
      password: password,
    );
  }

  Future<void> uploadJsonFile(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');

    if (await file.exists()) {
      await client.write('$remoteFolder/$fileName', file.readAsBytesSync());
      _logger.i('Datei erfolgreich hochgeladen: $fileName');
    } else {
      _logger.w('Datei nicht gefunden: $fileName');
    }
  }

  Future<void> downloadJsonFile(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');

    final data = await client.read('$remoteFolder/$fileName');
    await file.writeAsBytes(data);
    _logger.i('Datei erfolgreich heruntergeladen: $fileName');
  }

  Future<void> uploadImage(String imagePath) async {
    final imageFile = File(imagePath);
    final imageName = imageFile.uri.pathSegments.last;

    if (await imageFile.exists()) {
      await client.write('$remoteFolder/images/$imageName', imageFile.readAsBytesSync());
      _logger.i('Bild erfolgreich hochgeladen: $imageName');
    } else {
      _logger.w('Bild nicht gefunden: $imagePath');
    }
  }
}
