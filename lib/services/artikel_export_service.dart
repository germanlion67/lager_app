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
import '../models/artikel_model.dart';
import 'artikel_db_service.dart';
import 'nextcloud_credentials.dart';
import 'nextcloud_webdav_client.dart';

class ArtikelExportService {
  /// Exportiert alle Artikel der Datenbank als JSON-String (Backup).
  Future<String> exportAllArtikelAsJson() async {
    final artikelList = await ArtikelDbService().getAlleArtikel();
    final jsonList = artikelList.map((a) => a.toMap()).toList();
    return json.encode(jsonList);
  }

  /// Exportiert alle Artikel der Datenbank als CSV-String (Backup).
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
      final backupFolder = 'backup_${DateTime.now().millisecondsSinceEpoch}';
      
      int successfulImages = 0;
      int failedImages = 0;
      final errors = <String>[];

      // 3. Bilder zu Nextcloud hochladen und remoteBildPfad aktualisieren
      for (int i = 0; i < artikelList.length; i++) {
        final artikel = artikelList[i];
        
        if (artikel.bildPfad.isNotEmpty) {
          try {
            final imageFile = File(artikel.bildPfad);
            if (await imageFile.exists()) {
              // Remote-Pfad für Backup
              final fileName = p.basename(artikel.bildPfad);
              final remotePath = '$backupFolder/images/artikel_${artikel.id}_$fileName';
              
              // Upload zu Nextcloud
              await webdavClient.uploadFileNew(
                localPath: artikel.bildPfad,
                remoteRelativePath: remotePath,
              );

              // Artikel-Objekt mit remoteBildPfad aktualisieren
              artikelList[i] = Artikel(
                id: artikel.id,
                name: artikel.name,
                menge: artikel.menge,
                ort: artikel.ort,
                fach: artikel.fach,
                beschreibung: artikel.beschreibung,
                bildPfad: artikel.bildPfad,
                erstelltAm: artikel.erstelltAm,
                aktualisiertAm: artikel.aktualisiertAm,
                remoteBildPfad: remotePath,
              );
              
              successfulImages++;
            }
          } catch (e, stackTrace) {
            failedImages++;
            errors.add('Fehler bei Artikel ${artikel.name}: $e');
            await AppLogService().logError('Fehler beim Upload von Bild für Artikel ${artikel.name}', stackTrace);
          }
        }
      }

      // 4. JSON-Backup mit aktualisierten remoteBildPfad erstellen
      final jsonList = artikelList.map((a) => a.toMap()).toList();
      final jsonString = json.encode(jsonList);
      final jsonBytes = Uint8List.fromList(utf8.encode(jsonString));
      
      // 5. JSON-Backup zu Nextcloud hochladen
      final now = DateTime.now();
      final backupFileName = 'backup_${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.json';
      
      await webdavClient.uploadBytes(
        bytes: jsonBytes,
        remoteRelativePath: '$backupFolder/$backupFileName',
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
            'Backup-Ordner: $backupFolder'
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

}
