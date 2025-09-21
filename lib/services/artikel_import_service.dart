//lib/services/artikel_import_service.dart

//Importiert Artikel aus JSON- und CSV-String (z.B. aus Datei-Inhalt).
//Prüft Gültigkeit der Artikel vor Einfügen.
//Überspringt fehlerhafte Einträge.
//Fügt alle Artikel in die Datenbank ein.


import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/artikel_model.dart';
import 'artikel_db_service.dart';
import 'nextcloud_credentials.dart';
import 'nextcloud_webdav_client.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../services/app_log_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // <-- für Desktop/FFI

class ArtikelImportService {
  /// Importiert Artikel aus einer JSON-Datei (String-Inhalt).
  /// Erwartet ein Array von Artikel-Objekten im JSON.
  Future<List<Artikel>> importFromJson(String jsonString) async {
    final List<dynamic> jsonList = json.decode(jsonString);
    final artikelList = <Artikel>[];

    for (final item in jsonList) {
      try {
        artikelList.add(Artikel.fromMap(item as Map<String, dynamic>));
      } catch (e) {
        // Fehlerhafte Einträge überspringen
        continue;
      }
    }
    return artikelList;
  }

  /// Importiert Artikel aus einer CSV-Datei (String-Inhalt).
  /// Erwartet Header: name,menge,ort,fach,beschreibung,bildPfad,erstelltAm,aktualisiertAm,remoteBildPfad
  Future<List<Artikel>> importFromCsv(String csvString) async {
    final rows = const CsvToListConverter(eol: '\n').convert(csvString, eol: '\n');
    if (rows.isEmpty) return [];

    // Header verarbeiten
    final header = rows.first.map((e) => e.toString()).toList();
    final artikelList = <Artikel>[];

    for (final row in rows.skip(1)) {
      if (row.length < header.length) continue;
      final map = <String, dynamic>{};
      for (var i = 0; i < header.length; i++) {
        map[header[i]] = row[i];
      }
      try {
        artikelList.add(Artikel.fromMap(map));
      } catch (e) {
        continue;
      }
    }
    return artikelList;
  }

  /// Fügt eine Liste von Artikeln in die Datenbank ein.
  Future<void> insertArtikelList(List<Artikel> artikelList) async {
    final db = ArtikelDbService();
    for (var artikel in artikelList) {
      // Validierung: Nur gültige Artikel importieren
      if (artikel.isValid()) {
        await db.insertArtikel(artikel);
      }
    }
  }

// --- Backup ---
  static Future<void> importBackup(BuildContext context, [Future<void> Function()? reloadArtikel]) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Backup-Datei auswählen',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = File(result.files.single.path!);
    final jsonString = await file.readAsString();
    final artikelList = await ArtikelImportService().importFromJson(jsonString);
    await AppLogService().log('Backup-Restore gestartet');

    final db = await ArtikelDbService().database;
    try {
      await db.transaction((txn) async {
        // 1) Clear table
        await txn.delete('artikel');
        // 2) Insert all articles preserving IDs (falls vorhanden)
        for (final a in artikelList) {
          final map = a.toMap();
          // Insert with REPLACE to preserve provided id (falls Primary Key gesetzt)
          await txn.insert('artikel', map, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        // 3) Optional: Update sqlite_sequence so AUTOINCREMENT folgt highest id
        final maxIdRow = await txn.rawQuery('SELECT MAX(id) as maxId FROM artikel');
        final maxId = (maxIdRow.isNotEmpty && maxIdRow.first['maxId'] != null)
            ? maxIdRow.first['maxId'] as int
            : 0;
        if (maxId > 0) {
          await txn.rawUpdate('UPDATE sqlite_sequence SET seq = ? WHERE name = ?', [maxId, 'artikel']);
        }
      });
      
      // Artikelliste neu laden falls Callback vorhanden
      if (reloadArtikel != null) {
        await reloadArtikel();
      }
      
      await AppLogService().log('Backup-Restore erfolgreich: ${artikelList.length} Einträge wiederhergestellt');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup erfolgreich wiederhergestellt')),
        );
      }
    } catch (e, st) {
      await AppLogService().logError('Fehler beim Backup-Restore: $e', st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Restore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  static Future<void> importArtikel(BuildContext context, Future<void> Function() reloadArtikel) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['json', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final ext = file.extension?.toLowerCase();
    final content = file.bytes != null
        ? String.fromCharCodes(file.bytes!)
        : await File(file.path!).readAsString();

    List<Artikel> artikelList = [];
    String importMsg = "";

    try {
      if (ext == 'json') {
        await AppLogService().log('Import gestartet');
        artikelList = await ArtikelImportService().importFromJson(content);
        importMsg = "Importierte Artikel aus JSON: ${artikelList.length}";
        await AppLogService().log('Import erfolgreich: $importMsg');
      } else if (ext == 'csv') {
        await AppLogService().log('Import gestartet');
        artikelList = await ArtikelImportService().importFromCsv(content);
        importMsg = "Importierte Artikel aus CSV: ${artikelList.length}";
        await AppLogService().log('Import erfolgreich: $importMsg');
      } else {
        importMsg = "Dateiformat nicht unterstützt.";
        await AppLogService().log('Import fehlgeschlagen: $importMsg');
      }
      if (artikelList.isNotEmpty) {
        await ArtikelImportService().insertArtikelList(artikelList);
        await reloadArtikel();
      }
    } catch (e, stack) {
      importMsg = "Fehler beim Import: $e";
      await AppLogService().logError(importMsg, stack);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(importMsg)),
    );
  }

  // --- Backup mit Bildern von Nextcloud importieren ---
  static Future<void> importBackupWithImagesFromNextcloud(
    BuildContext context, 
    [Future<void> Function()? reloadArtikel]
  ) async {
    try {
      await AppLogService().log('Backup-Import mit Bildern von Nextcloud gestartet');

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

      // 2. Verfügbare Backup-Ordner anzeigen (vereinfacht: Benutzer gibt Backup-Ordner-Namen ein)
      if (!context.mounted) return;
      final backupFolder = await _showBackupFolderDialog(context);
      if (backupFolder == null || backupFolder.isEmpty) return;

      // 3. JSON-Backup herunterladen und parsen
      final jsonFiles = ['backup.json', 'artikel_backup.json']; // Mögliche Namen
      String? jsonContent;
      
      for (final jsonFileName in jsonFiles) {
        try {
          final jsonBytes = await webdavClient.downloadBytes(
            remoteRelativePath: '$backupFolder/$jsonFileName',
          );
          jsonContent = String.fromCharCodes(jsonBytes);
          break;
        } catch (e) {
          // Versuche nächsten Dateinamen
          continue;
        }
      }

      if (jsonContent == null) {
        throw Exception('Keine gültige JSON-Backup-Datei im Ordner $backupFolder gefunden.');
      }

      final artikelList = await ArtikelImportService().importFromJson(jsonContent);
      if (artikelList.isEmpty) {
        throw Exception('Keine Artikel im Backup gefunden.');
      }

      // 4. Lokales Verzeichnis für Bilder vorbereiten
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'images'));
      await imagesDir.create(recursive: true);

      int successfulImages = 0;
      int failedImages = 0;
      final errors = <String>[];

      // 5. Bilder herunterladen und lokale Pfade aktualisieren
      for (int i = 0; i < artikelList.length; i++) {
        var artikel = artikelList[i];
        
        if (artikel.remoteBildPfad?.isNotEmpty == true) {
          try {
            final localImagePath = '${imagesDir.path}/artikel_${artikel.id}_image.jpg';
            
            await webdavClient.downloadFileNew(
              remoteRelativePath: artikel.remoteBildPfad!,
              localPath: localImagePath,
            );
            
            // Update article with local image path
            artikel = artikel.copyWith(bildPfad: localImagePath);
            artikelList[i] = artikel; // Update in list
          } catch (e) {
            await AppLogService().logError('Failed to download image for article ${artikel.name}: $e');
            // Continue without image
          }
        }
      }

      // 6. Artikel in Datenbank importieren
      final db = await ArtikelDbService().database;
      await db.transaction((txn) async {
        // Datenbank löschen
        await txn.delete('artikel');
        
        // Artikel importieren
        for (final a in artikelList) {
          final map = a.toMap();
          await txn.insert('artikel', map, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        
        // SQLite-Sequenz aktualisieren
        final maxIdRow = await txn.rawQuery('SELECT MAX(id) as maxId FROM artikel');
        final maxId = (maxIdRow.isNotEmpty && maxIdRow.first['maxId'] != null)
            ? maxIdRow.first['maxId'] as int
            : 0;
        if (maxId > 0) {
          await txn.rawUpdate('UPDATE sqlite_sequence SET seq = ? WHERE name = ?', [maxId, 'artikel']);
        }
      });

      // 7. Artikelliste neu laden
      if (reloadArtikel != null) {
        await reloadArtikel();
      }

      await AppLogService().log('Backup-Import mit Bildern erfolgreich: ${artikelList.length} Artikel, $successfulImages Bilder');
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup erfolgreich wiederhergestellt!\n'
            'Artikel: ${artikelList.length}\n'
            'Bilder: $successfulImages erfolgreich, $failedImages Fehler'
          ),
          duration: const Duration(seconds: 5),
        ),
      );

      // Fehler anzeigen falls vorhanden
      if (errors.isNotEmpty && context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Download-Fehler'),
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

    } catch (e, st) {
      await AppLogService().logError('Fehler beim Backup-Import mit Bildern: $e', st);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Import: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Dialog zur Eingabe des Backup-Ordner-Namens
  static Future<String?> _showBackupFolderDialog(BuildContext context) async {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup-Ordner auswählen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Geben Sie den Namen des Backup-Ordners in Nextcloud ein:\n'
              '(z.B. backup_1695735600000)',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Backup-Ordner-Name',
                hintText: 'backup_1695735600000',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
