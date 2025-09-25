//lib/services/artikel_export_service.dart

//Exportiert alle Artikel als JSON-Array (Backup).
//Exportiert alle Artikel als CSV-Datei (Backup).
//Nutzt die Felder deiner Artikel-Klasse, inkl. aller Datenbankattribute.

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../services/app_log_service.dart';
//import '../models/artikel_model.dart';
import 'artikel_db_service.dart';
import 'nextcloud_credentials.dart';
import 'nextcloud_webdav_client.dart';

class ArtikelExportService {
  // Exportiert alle Artikel der Datenbank als JSON-String (Backup).
  Future<String> exportAllArtikelAsJson() async {
    final artikelList = await ArtikelDbService().getAlleArtikel();
    final jsonList = artikelList.map((a) => a.toMap()).toList();
    return json.encode(jsonList);
  }

  // Exportiert alle Artikel der Datenbank als CSV-String (Backup).
  Future<String> exportAllArtikelAsCsv() async {
    final artikelList = await ArtikelDbService().getAlleArtikel();
    if (artikelList.isEmpty) return "";

    // Header aus toMap nehmen
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



  static Future<void> showExportDialog(BuildContext context) async {
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
        exportData = await ArtikelExportService().exportAllArtikelAsJson();
      } else if (exportType == 'csv') {
        exportData = await ArtikelExportService().exportAllArtikelAsCsv();
      }

      if (exportData == null || exportData.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Artikeldaten vorhanden.')),
        );
        return;
      }

      final fileName =
        'artikel_export_${DateTime.now().toIso8601String().replaceAll(':', '-')}.$exportType';
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
        SnackBar(content: Text('Fehler beim Export: $e'), backgroundColor: Colors.red),
      );
    }
  }
  // --- Backup ---
  static Future<void> backupToFile(BuildContext context) async {
    await AppLogService().log('Backup gestartet');
    final now = DateTime.now();
    final filename =
        'backup_${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.json';
    final jsonString = await ArtikelExportService().exportAllArtikelAsJson();
    final bytes = Uint8List.fromList(utf8.encode(jsonString)); // <--- Diese Zeile ergänzt die Variable!
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
    }
    else {
      await AppLogService().log('Backup abgebrochen oder kein Pfad gewählt');
    }
  }

  // --- Backup mit Bildern zu Nextcloud ---
  static Future<void> backupWithImagesToNextcloud(BuildContext context) async {
    try {
      await AppLogService().log('Backup mit Bildern zu Nextcloud gestartet');

      // 1. Nextcloud-Zugangsdaten prüfen
      final creds = await NextcloudCredentialsStore().read();
      if (creds == null) {
        throw Exception('Nextcloud-Zugangsdaten nicht gefunden. Bitte erst einrichten.');
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
      final backupFolder = 'backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      await AppLogService().log('Anzahl Artikel für Backup: ${artikelList.length}');

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
            await AppLogService().log('Bilddatei nicht gefunden: ${artikel.bildPfad}');
            continue;
          }

          final artikelNameSlug = artikel.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
          final fileName = '${artikel.id}_$artikelNameSlug.jpg';
          final remotePath = '${creds.baseFolder}/$backupFolder/images/$fileName';
          try {
            await _uploadImage(webdavClient, artikel.bildPfad, remotePath);
            artikelList[i] = artikel.copyWith(
              remoteBildPfad: remotePath,
              bildPfad: remotePath,
              );
            successfulImages++;
            await AppLogService().log('Bild erfolgreich hochgeladen: $remotePath');
          } catch (uploadError) {
            if (_isConflictError(uploadError)) {
              await _retryUpload(webdavClient, artikel.bildPfad, remotePath, artikel.name);
              artikelList[i] = artikel.copyWith(remoteBildPfad: remotePath);
              successfulImages++;
            } else {
              rethrow; // Updated to use rethrow
            }
          }
        } catch (e, stackTrace) {
          failedImages++;
          errors.add('Fehler bei Artikel ${artikel.name}: $e');
          await AppLogService().logError('Fehler beim Upload von Bild für Artikel ${artikel.name}', stackTrace);
        }
      }

      // 4. JSON-Backup mit aktualisierten remoteBildPfad erstellen
      final jsonList = artikelList.map((a) => a.toMap()).toList();
      final jsonString = json.encode(jsonList);
      final jsonBytes = Uint8List.fromList(utf8.encode(jsonString));

      await AppLogService().log('JSON erstellt, Größe: ${jsonBytes.length} bytes');

      // 5. JSON-Backup zu Nextcloud hochladen
      final backupFileName = 'backup.json';
      await webdavClient.uploadBytes(
        bytes: jsonBytes,
        remoteRelativePath: '${creds.baseFolder}/$backupFolder/$backupFileName',
        contentType: 'application/json',
      );

      // 6. Erfolgsmeldung
      await AppLogService().log('Backup mit Bildern erfolgreich: $successfulImages Bilder, $failedImages Fehler');
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
      await AppLogService().logError('Fehler beim Backup mit Bildern: $e', stack);
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

  static Future<void> _uploadImage(
    NextcloudWebDavClient webdavClient,
    String localPath,
    String remotePath,
  ) async {
    // Verzeichnis sicherstellen
    final folderPath = p.dirname(remotePath); // Extrahiere den Verzeichnispfad
    await webdavClient.ensureFolder(folderPath); // Stelle sicher, dass das Verzeichnis existiert
    // Datei hochladen
    await webdavClient.uploadFileNew(
      localPath: localPath,
      remoteRelativePath: remotePath,
    );
  }

  static bool _isConflictError(Object error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('409') || errorString.contains('folder');
  }

  static Future<void> _retryUpload(
    NextcloudWebDavClient webdavClient,
    String localPath,
    String remotePath,
    String artikelName,
  ) async {
    await AppLogService().log('409 Fehler beim Upload - versuche erneut: $artikelName');
    await Future.delayed(const Duration(milliseconds: 500));
    await webdavClient.uploadFileNew(
      localPath: localPath,
      remoteRelativePath: remotePath,
    );
    await AppLogService().log('Bild erfolgreich hochgeladen (2. Versuch): $remotePath');
  }
}
