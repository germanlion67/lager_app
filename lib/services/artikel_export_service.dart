import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../services/app_log_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'artikel_db_service.dart';
import 'nextcloud_credentials.dart';
import 'nextcloud_webdav_client.dart';
import 'package:archive/archive.dart';

class ArtikelExportService {
  Future<void> _uploadImage(
    NextcloudWebDavClient webdavClient,
    String localPath,
    String remotePath,
  ) async {
    final folderPath = p.dirname(remotePath);
    await webdavClient.ensureFolder(folderPath);
    await webdavClient.uploadFileNew(
      localPath: localPath,
      remoteRelativePath: remotePath,
    );
  }

  bool _isConflictError(Object error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('409') || errorString.contains('folder');
  }

  Future<void> _retryUpload(
    NextcloudWebDavClient webdavClient,
    String localPath,
    String remotePath,
    String artikelName,
  ) async {
    await AppLogService()
        .log('409 Fehler beim Upload - versuche erneut: $artikelName');
    await Future.delayed(const Duration(milliseconds: 500));
    await webdavClient.uploadFileNew(
      localPath: localPath,
      remoteRelativePath: remotePath,
    );
    await AppLogService()
        .log('Bild erfolgreich hochgeladen (2. Versuch): $remotePath');
  }

  // Backup als ZIP-Datei (JSON + Bilder)
  Future<String?> backupToZipFile(BuildContext context) async {
    await AppLogService().log('ZIP-Backup gestartet');
    final artikelList = await ArtikelDbService().getAlleArtikel();
    final jsonList = artikelList.map((a) => a.toMap()).toList();
    final jsonString = json.encode(jsonList);

    // ZIP-Archiv vorbereiten
    final archive = Archive();
    archive.addFile(ArchiveFile(
        'artikel_backup.json', jsonString.length, utf8.encode(jsonString)));

    // Alle Bilder hinzufügen
    for (final artikel in artikelList) {
      if (artikel.bildPfad.isNotEmpty) {
        final imageFile = File(artikel.bildPfad);
        if (await imageFile.exists()) {
          final imageBytes = await imageFile.readAsBytes();
          final fileName =
              'images/${artikel.id}_${artikel.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}.jpg';
          archive.addFile(ArchiveFile(fileName, imageBytes.length, imageBytes));
        }
      }
    }

    // ZIP-Datei erstellen
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);

    // Dateidialog anzeigen
    final now = DateTime.now();
    final filename =
        'lager_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.zip';
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Backup als ZIP speichern',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: ['zip'],
      bytes: Uint8List.fromList(zipData),
    );
    await AppLogService().log('FilePicker result: $result');
    if (result != null) {
      await AppLogService()
          .log('ZIP-Backup erfolgreich gespeichert: $filename');
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ZIP-Backup erfolgreich gespeichert')),
      );
      return result;
    } else {
      await AppLogService()
          .log('ZIP-Backup abgebrochen oder kein Pfad gewählt');
      return null;
    }
  }

  /// Führt ein Nextcloud-Backup der ZIP-Datei durch, aber nur wenn WLAN verfügbar ist und das lokale Backup erfolgreich war
  Future<void> backupZipToNextcloud(String zipFilePath) async {
    // Nur für Android/iOS: Prüfe WLAN
    if (!Platform.isAndroid && !Platform.isIOS) {
      await AppLogService()
          .log('Nextcloud-Backup: Übersprungen (nur Android/iOS)');
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.wifi) {
      await AppLogService().log(
          'Nextcloud-Backup: Kein WLAN verfügbar, Synchronisation übersprungen');
      return;
    }

    try {
      await AppLogService()
          .log('Nextcloud-Backup: WLAN erkannt, Upload gestartet');

      // Nextcloud-Zugangsdaten laden
      final creds = await NextcloudCredentialsStore().read();
      if (creds == null) {
        await AppLogService()
            .log('Nextcloud-Backup: Keine Zugangsdaten gefunden');
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

      // ZIP-Datei einlesen
      final zipFile = File(zipFilePath);
      if (!await zipFile.exists()) {
        await AppLogService()
            .log('Nextcloud-Backup: ZIP-Datei nicht gefunden: $zipFilePath');
        return;
      }
      final zipBytes = await zipFile.readAsBytes();

      // Remote-Pfad generieren
      final now = DateTime.now();
      final remoteFileName =
          'backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.zip';
      final remotePath = p.posix.join(creds.baseFolder, remoteFileName);

      // Upload durchführen
      await webdavClient.uploadBytes(
        bytes: zipBytes,
        remoteRelativePath: remotePath,
        contentType: 'application/zip',
      );
      await AppLogService()
          .log('Nextcloud-Backup: Upload erfolgreich: $remotePath');
    } catch (e) {
      await AppLogService().log('Nextcloud-Backup: Fehler beim Upload: $e');
    }
  }

  Future<String> exportAllArtikelAsJson() async {
    final artikelList = await ArtikelDbService().getAlleArtikel();
    final jsonList = artikelList.map((a) => a.toMap()).toList();
    return json.encode(jsonList);
  }

  Future<String> exportAllArtikelAsCsv() async {
    final artikelList = await ArtikelDbService().getAlleArtikel();
    if (artikelList.isEmpty) return "";
    final header = [
      'id',
      'name',
      'menge',
      'ort',
      'fach',
      'beschreibung',
      'bildPfad',
      'erstelltAm',
      'aktualisiertAm',
      'remoteBildPfad',
    ];
    final List<List<String>> rows = [];
    rows.add(header);
    for (final artikel in artikelList) {
      final map = artikel.toMap();
      rows.add(header.map((h) => map[h]?.toString() ?? "").toList());
    }
    return const ListToCsvConverter().convert(rows);
  }

  Future<void> showExportDialog(BuildContext context) async {
    try {
      String? exportType = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Exportformat wählen'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'json'),
              child: const Text('Export als JSON'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'csv'),
              child: const Text('Export als CSV'),
            ),
          ],
        ),
      );
      if (exportType == null) return;

      String? exportData;
      if (exportType == 'json') {
        exportData = await exportAllArtikelAsJson();
      } else if (exportType == 'csv') {
        exportData = await exportAllArtikelAsCsv();
      }

      if (exportData == null || exportData.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Artikeldaten vorhanden.')),
        );
        return;
      }

      final fileName =
          'artikel_export_${DateTime.now().toIso8601String().replaceAll(':', '-')}.${exportType}';
      final bytes = Uint8List.fromList(utf8.encode(exportData));

      await AppLogService().log('Export gestartet ($exportType)');

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Exportiere Artikeldaten',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [exportType],
        bytes: bytes,
      );

      if (savedPath != null && context.mounted) {
        await AppLogService().log('Export erfolgreich: $savedPath');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export erfolgreich: $fileName')),
        );
      }
    } catch (e, stack) {
      await AppLogService().logError('Fehler beim Export: $e', stack);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Fehler beim Export: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> backupToFile(BuildContext context) async {
    await AppLogService().log('Backup gestartet');
    final now = DateTime.now();
    final filename =
        'backup_${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.json';
    final jsonString = await exportAllArtikelAsJson();
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Backup speichern',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    await AppLogService().log('FilePicker result: $result');
    if (result != null) {
      await AppLogService().log('Backup erfolgreich gespeichert: $filename');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup erfolgreich gespeichert')),
      );
    } else {
      await AppLogService().log('Backup abgebrochen oder kein Pfad gewählt');
    }
  }

  Future<void> backupWithImagesToNextcloud(BuildContext context) async {
    try {
      await AppLogService().log('Backup mit Bildern zu Nextcloud gestartet');

      // 1. Nextcloud-Zugangsdaten prüfen
      final creds = await NextcloudCredentialsStore().read();
      if (creds == null) {
        throw Exception(
            'Nextcloud-Zugangsdaten nicht gefunden. Bitte erst einrichten.');
      }

      final webdavClient = NextcloudWebDavClient(
        NextcloudConfig(
          serverBase: creds.server,
          username: creds.user,
          appPassword: creds.appPw,
          baseRemoteFolder: creds.baseFolder,
        ),
      );

      // 2. Alle Artikel laden
      final artikelList = await ArtikelDbService().getAlleArtikel();
      final now = DateTime.now();
      final backupFolder =
          'backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      await AppLogService()
          .log('Anzahl Artikel für Backup: ${artikelList.length}');

      // Sicherstellen, dass das Backup-Verzeichnis existiert
      final backupFolderPath = '${creds.baseFolder}/$backupFolder/images';
      await webdavClient.ensureFolder(backupFolderPath);

      int successfulImages = 0;
      int failedImages = 0;
      final errors = <String>[];

      // 3. Bilder zu Nextcloud hochladen und remoteBildPfad aktualisieren
      for (int i = 0; i < artikelList.length; i++) {
        final artikel = artikelList[i];
        if (artikel.bildPfad.isEmpty) continue;

        try {
          final imageFile = File(artikel.bildPfad);
          if (!await imageFile.exists()) {
            await AppLogService()
                .log('Bilddatei nicht gefunden: ${artikel.bildPfad}');
            continue;
          }

          final artikelNameSlug = artikel.name
              .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
              .toLowerCase();
          final fileName = '${artikel.id}_$artikelNameSlug.jpg';
          final remotePath =
              '${creds.baseFolder}/$backupFolder/images/$fileName';
          try {
            await _uploadImage(webdavClient, artikel.bildPfad, remotePath);
            artikelList[i] = artikel.copyWith(
              remoteBildPfad: remotePath,
              bildPfad: remotePath,
            );
            successfulImages++;
            await AppLogService()
                .log('Bild erfolgreich hochgeladen: $remotePath');
          } catch (uploadError) {
            if (_isConflictError(uploadError)) {
              await _retryUpload(
                  webdavClient, artikel.bildPfad, remotePath, artikel.name);
              artikelList[i] = artikel.copyWith(remoteBildPfad: remotePath);
              successfulImages++;
            } else {
              rethrow; // Updated to use rethrow
            }
          }
        } catch (e, stackTrace) {
          failedImages++;
          errors.add('Fehler bei Artikel ${artikel.name}: $e');
          await AppLogService().logError(
              'Fehler beim Upload von Bild für Artikel ${artikel.name}',
              stackTrace);
        }
      }

      // 4. JSON-Backup mit aktualisierten remoteBildPfad erstellen
      final jsonList = artikelList.map((a) => a.toMap()).toList();
      final jsonString = json.encode(jsonList);
      final jsonBytes = Uint8List.fromList(utf8.encode(jsonString));

      await AppLogService()
          .log('JSON erstellt, Größe: ${jsonBytes.length} bytes');

      // 5. JSON-Backup zu Nextcloud hochladen
      final backupFileName = 'backup.json';
      await webdavClient.uploadBytes(
        bytes: jsonBytes,
        remoteRelativePath: '${creds.baseFolder}/$backupFolder/$backupFileName',
        contentType: 'application/json',
      );

      // 6. Erfolgsmeldung
      await AppLogService().log(
          'Backup mit Bildern erfolgreich: $successfulImages Bilder, $failedImages Fehler');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup erfolgreich zu Nextcloud!\n'
            'Bilder: $successfulImages erfolgreich, $failedImages Fehler\n'
            'Backup-Ordner: $backupFolder',
          ),
          duration: const Duration(seconds: 5),
        ),
      );

      // Fehler anzeigen falls vorhanden
      if (errors.isNotEmpty && context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Upload-Fehler'),
            content: SingleChildScrollView(
              child: Text(errors.join('\n\n')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e, stack) {
      await AppLogService()
          .logError('Fehler beim Backup mit Bildern: $e', stack);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Backup: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
