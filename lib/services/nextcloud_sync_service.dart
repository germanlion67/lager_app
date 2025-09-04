//lib/services/nextcloud_sync_service.dart

import 'package:webdav_client/webdav_client.dart' as webdav;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'nextcloud_credentials.dart';

class NextcloudSyncService {
  late webdav.Client client;
  final Logger _logger = Logger();
  late String remoteFolder;

  Future<bool> init() async {
    try {
      final creds = await NextcloudCredentialsStore().read();
      if (creds == null) {
        _logger.e('Nextcloud-Zugangsdaten nicht gefunden.');
        return false;
      }
      client = webdav.newClient(
        creds.server.toString(),
        user: creds.user,
        password: creds.appPw,
      );
      remoteFolder = creds.baseFolder;
      return true;
    } catch (e) {
      _logger.e('Fehler bei Initialisierung der Nextcloud-Verbindung:', e);
      return false;
    }
  }

  Future<bool> uploadJsonFile(String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      if (await file.exists()) {
        await client.write('$remoteFolder/$fileName', file.readAsBytesSync());
        _logger.i('Datei erfolgreich hochgeladen: $fileName');
        return true;
      } else {
        _logger.w('Datei nicht gefunden: $fileName');
        return false;
      }
    } catch (e) {
      _logger.e('Fehler beim Hochladen der Datei:', e);
      return false;
    }
  }

  Future<bool> downloadJsonFile(String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      final data = await client.read('$remoteFolder/$fileName');
      await file.writeAsBytes(data);
      _logger.i('Datei erfolgreich heruntergeladen: $fileName');
      return true;
    } catch (e) {
      _logger.e('Fehler beim Herunterladen der Datei:', e);
      return false;
    }
  }

  Future<bool> uploadImage(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      final imageName = imageFile.uri.pathSegments.last;
      if (await imageFile.exists()) {
        await client.write('$remoteFolder/images/$imageName', imageFile.readAsBytesSync());
        _logger.i('Bild erfolgreich hochgeladen: $imageName');
        return true;
      } else {
        _logger.w('Bild nicht gefunden: $imagePath');
        return false;
      }
    } catch (e) {
      _logger.e('Fehler beim Hochladen des Bildes:', e);
      return false;
    }
  }
}
