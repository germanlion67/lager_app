// lib/services/import_nextcloud.dart
// Nextcloud-spezifische Import-Funktionen (nur Mobile)

import 'package:flutter/material.dart';
import 'app_log_service.dart';
import 'artikel_import_service.dart';
import 'nextcloud_credentials.dart';
import 'nextcloud_webdav_client.dart';

/// ZIP-Backup von Nextcloud importieren mit Dateiauswahl
Future<void> importZipBackupAuto(
  BuildContext context, [
  Future<void> Function()? reloadArtikel,
  bool setzePlatzhalter = false,
]) async {
  final creds = await NextcloudCredentialsStore().read();
  if (creds == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nextcloud-Zugangsdaten nicht gefunden!'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  // ZIP-Dateien sammeln
  final zipMap = <String, Map<String, dynamic>>{};

  try {
    // Root-Dateien
    final rootFiles = await webdavClient.listFilesWithSize('');
    for (final entry in rootFiles.entries) {
      if (entry.key.toLowerCase().endsWith('.zip')) {
        zipMap[_cleanName(entry.key)] = {
          'path': entry.key,
          'size': entry.value,
        };
      }
    }

    // Unterordner durchsuchen
    final folders = await webdavClient.listFolders('');
    for (final folder in folders) {
      try {
        final subFiles = await webdavClient.listFilesWithSize(folder);
        for (final entry in subFiles.entries) {
          if (entry.key.toLowerCase().endsWith('.zip')) {
            zipMap['$folder/${_cleanName(entry.key)}'] = {
              'path': '$folder/${entry.key}',
              'size': entry.value,
            };
          }
        }
      } catch (e) {
        await AppLogService().logError('Ordner "$folder" lesen: $e');
      }
    }
  } catch (e) {
    await AppLogService().logError('Dateien auflisten: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
      );
    }
    return;
  }

  if (zipMap.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine ZIP-Backups gefunden')),
      );
    }
    return;
  }

  // Sortieren (neueste zuerst)
  final sorted = zipMap.entries.toList()
    ..sort((a, b) => b.key.compareTo(a.key));

  if (!context.mounted) return;

  // Auswahl-Dialog
  final selected = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('ZIP-Backup auswählen'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: sorted.length,
          itemBuilder: (_, index) {
            final entry = sorted[index];
            final size = entry.value['size'] as int;
            return ListTile(
              leading: const Icon(Icons.archive),
              title: Text(entry.key),
              subtitle: Text('Größe: ${_formatSize(size)}'),
              onTap: () => Navigator.pop(ctx, entry.value['path'] as String),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Abbrechen'),
        ),
      ],
    ),
  );

  if (!context.mounted || selected == null) return;

  // Download und Import
  try {
    final zipBytes = await webdavClient.downloadBytes(
      remoteRelativePath: selected,
    );
    final (success, errors) = await ArtikelImportService.importZipBytesService(
      zipBytes,
      reloadArtikel,
      setzePlatzhalter,
    );

    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ZIP-Backup erfolgreich importiert!')),
      );
    }
    if (errors.isNotEmpty) {
      ArtikelImportService.showImportErrors(context, errors);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download-Fehler: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

String _cleanName(String fileName) {
  String cleaned = fileName;
  if (cleaned.startsWith('backup_')) cleaned = cleaned.substring(7);
  if (cleaned.toLowerCase().endsWith('.zip')) {
    cleaned = cleaned.substring(0, cleaned.length - 4);
  }
  return cleaned;
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
