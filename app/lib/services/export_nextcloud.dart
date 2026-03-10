// lib/services/export_nextcloud.dart
// Nextcloud-spezifische Backup-Funktionen (nur Mobile)

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'app_log_service.dart';
import 'artikel_db_service.dart';
import 'nextcloud_credentials.dart';
import 'nextcloud_webdav_client.dart';

/// Lädt eine ZIP-Datei zu Nextcloud hoch
Future<void> uploadZipToNextcloud(String zipFilePath, {BuildContext? context}) async {
  final connectivityResults = await Connectivity().checkConnectivity();
  if (!connectivityResults.contains(ConnectivityResult.wifi)) {
    await AppLogService().log('Nextcloud-Backup: Kein WLAN, übersprungen');
    return;
  }

  try {
    final creds = await NextcloudCredentialsStore().read();
    if (creds == null) {
      await AppLogService().log('Nextcloud-Backup: Keine Zugangsdaten');
      return;
    }

    final webdavClient = NextcloudWebDavClient(
      NextcloudConfig(
        serverBase: creds.server,
        username: creds.user,
        appPassword: creds.appPw,
        baseRemoteFolder: creds.baseFolder,
      ),
    );

    final zipFile = File(zipFilePath);
    if (!await zipFile.exists()) {
      await AppLogService().log('Nextcloud-Backup: ZIP nicht gefunden: $zipFilePath');
      return;
    }

    final zipBytes = await zipFile.readAsBytes();
    final now = DateTime.now();
    final remoteFileName =
        'backup_${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}.zip';
    final remotePath = p.posix.join(creds.baseFolder, remoteFileName);

    await webdavClient.uploadBytes(
      bytes: zipBytes,
      remoteRelativePath: remotePath,
      contentType: 'application/zip',
    );

    await AppLogService().log('Nextcloud-Backup: Upload erfolgreich: $remotePath');

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ZIP-Backup hochgeladen:\n$remotePath'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  } catch (e) {
    await AppLogService().log('Nextcloud-Backup: Fehler: $e');
  }
}

/// Vollständiges Backup mit Bildern zu Nextcloud
Future<void> backupWithImagesToNextcloud(BuildContext context) async {
  try {
    await AppLogService().log('Nextcloud Bild-Backup gestartet');

    final creds = await NextcloudCredentialsStore().read();
    if (creds == null) {
      throw Exception('Nextcloud-Zugangsdaten nicht gefunden.');
    }

    final webdavClient = NextcloudWebDavClient(
      NextcloudConfig(
        serverBase: creds.server,
        username: creds.user,
        appPassword: creds.appPw,
        baseRemoteFolder: creds.baseFolder,
      ),
    );

    final artikelList = await ArtikelDbService().getAlleArtikel();
    final now = DateTime.now();
    final backupFolder =
        'backup_${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';

    await webdavClient.ensureFolder(backupFolder);
    final imagesSubFolder = '$backupFolder/images';
    await webdavClient.ensureFolder(imagesSubFolder);

    int successCount = 0;
    int failCount = 0;

    for (final artikel in artikelList) {
      if (artikel.bildPfad.isEmpty) continue;

      try {
        final imageFile = File(artikel.bildPfad);
        if (!await imageFile.exists()) continue;

        final slug = artikel.name
            .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
            .toLowerCase();
        final remotePath = '$imagesSubFolder/${artikel.id}_$slug.jpg';

        await webdavClient.uploadFileNew(
          localPath: artikel.bildPfad,
          remoteRelativePath: remotePath,
        );
        successCount++;
      } catch (e) {
        failCount++;
        await AppLogService().log('Bild-Upload Fehler (${artikel.name}): $e');
      }
    }

    // JSON-Backup
    final jsonList = artikelList.map((a) => a.toMap()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);
    await webdavClient.uploadBytes(
      bytes: Uint8List.fromList(utf8.encode(jsonString)),
      remoteRelativePath: '$backupFolder/backup.json',
      contentType: 'application/json',
    );

    await AppLogService().log(
      'Nextcloud Bild-Backup fertig: $successCount OK, $failCount Fehler',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup erfolgreich!\n'
            'Bilder: $successCount OK, $failCount Fehler\n'
            'Ordner: $backupFolder',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  } catch (e, stack) {
    await AppLogService().logError('Nextcloud Bild-Backup Fehler: $e', stack);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
