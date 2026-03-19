// lib/services/export_nextcloud.dart

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
// Fix: connectivity_plus direkt entfernt — ConnectivityService übernimmt
// den plattformspezifischen Check (kein NetworkManager auf WSL2/Linux nötig)
import 'connectivity_service.dart';
import 'app_log_service.dart';
import 'artikel_db_service.dart';
import 'nextcloud_credentials.dart';
import 'nextcloud_webdav_client.dart';

// ✅ Lokale Logger-Referenz — einmal definiert, überall nutzbar
final Logger _logger = AppLogService.logger;

/// Lädt eine ZIP-Datei zu Nextcloud hoch
Future<void> uploadZipToNextcloud(
  String zipFilePath, {
  BuildContext? context,
}) async {
  final isWifi = await ConnectivityService.isWifi();

  if (!isWifi) {
    // ✅ kein await — void
    _logger.i('Nextcloud-Backup: Kein WLAN, übersprungen');
    return;
  }

  try {
    final creds = await NextcloudCredentialsStore().read();
    if (creds == null) {
      // ✅ kein await — void
      _logger.i('Nextcloud-Backup: Keine Zugangsdaten');
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
      // ✅ kein await — void
      _logger.i('Nextcloud-Backup: ZIP nicht gefunden: $zipFilePath');
      return;
    }

    final zipBytes = await zipFile.readAsBytes();

    final now = DateTime.now().toUtc();
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

    // ✅ kein await — void
    _logger.i('Nextcloud-Backup: Upload erfolgreich: $remotePath');

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ZIP-Backup hochgeladen:\n$remotePath'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  } catch (e, stack) {
    // ✅ named parameters — kein positional StackTrace
    _logger.e(
      'Nextcloud-Backup: Fehler:',
      error: e,
      stackTrace: stack,
    );
  }
}

/// Vollständiges Backup mit Bildern zu Nextcloud
Future<void> backupWithImagesToNextcloud(BuildContext context) async {
  try {
    // ✅ kein await — void
    _logger.i('Nextcloud Bild-Backup gestartet');

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

    final now = DateTime.now().toUtc();
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
      } catch (e, stack) {
        failCount++;
        // ✅ named parameters — war vorher nur .i() ohne StackTrace
        _logger.w(
          'Bild-Upload Fehler (${artikel.name}):',
          error: e,
          stackTrace: stack,
        );
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

    // ✅ kein await — void
    _logger.i(
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
    // ✅ named parameters — kein positional StackTrace
    _logger.e(
      'Nextcloud Bild-Backup Fehler:',
      error: e,
      stackTrace: stack,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}