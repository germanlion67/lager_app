//lib/services/artikel_import_service.dart

//Importiert Artikel aus JSON- und CSV-String (z.B. aus Datei-Inhalt).
//Prüft Gültigkeit der Artikel vor Einfügen.
//Überspringt fehlerhafte Einträge.
//Fügt alle Artikel in die Datenbank ein.


import 'dart:convert';
//import 'package:csv/csv.dart';
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
import 'package:archive/archive_io.dart';

class ArtikelImportService {
  /// Importiert Artikel aus einer JSON-Datei (String-Inhalt).
  /// Erwartet ein Array von Artikel-Objekten im JSON.

  Future<List<Artikel>> importFromJson(String jsonString) async {
    final List<dynamic> jsonList = json.decode(jsonString);
    final artikelList = <Artikel>[];

    for (final item in jsonList) {
      try {
        final map = item as Map<String, dynamic>;
        // Validierung der JSON-Struktur
        if (!map.containsKey('id') || !map.containsKey('name')) {
          await AppLogService().logError('Artikel übersprungen - Fehlende Felder: $map');
          continue;
        }


        // Prüfe ob bildPfad vorhanden und nicht leer ist
        final bildPfad = map['bildPfad'];
        if (bildPfad == null || bildPfad.toString().isEmpty) {
          await AppLogService().logError('Artikel übersprungen - bildPfad fehlt oder ist leer: ${map['name']}');
          continue; // Ungültigen Eintrag überspringen
        }
        
        artikelList.add(Artikel.fromMap(map));
      } catch (e) {
        await AppLogService().logError('Fehler bei Artikel: $item - $e');
        // Fehlerhafte Einträge überspringen
        continue;
      }
    }
    return artikelList;
  }

  /// Importiert Artikel aus einer CSV-Datei (String-Inhalt).
  /// Erwartet Header: name,menge,ort,fach,beschreibung,bildPfad,erstelltAm,aktualisiertAm,remoteBildPfad
  Future<List<Artikel>> importFromCsv(String csvString) async {
    final rows = const LineSplitter().convert(csvString.trim());
    if (rows.isEmpty) return [];

    final header = rows.first.split(',').map((h) => h.trim()).toList();
    final artikelList = <Artikel>[];

    for (final row in rows.skip(1)) {
      final values = row.split(',').map((v) => v.trim()).toList();
      if (values.length < header.length) continue;

      final map = Map.fromIterables(header, values);
      

      // Konvertieren Sie die Menge in int, falls vorhanden
      if (map['menge'] != null && map['menge']!.isNotEmpty) {
        map['menge'] = (int.tryParse(map['menge']!) ?? 0).toString();
      } else {
        map['menge'] = '0';
      }


      // Prüfen, ob bildPfad vorhanden und nicht leer ist
      final bildPfad = map['bildPfad'];
      if (bildPfad == null || bildPfad.isEmpty) continue;

      artikelList.add(Artikel.fromMap(map));
    }
    return artikelList;
  }

  /// Fügt eine Liste von Artikeln in die Datenbank ein.
  Future<void> insertArtikelList(List<Artikel> artikelList) async {
    final db = ArtikelDbService();
    int insertedCount = 0;
    for (var artikel in artikelList) {
      // Validierung: Nur gültige Artikel importieren
      if (artikel.isValid()) {
        await db.insertArtikel(artikel);
        insertedCount++;
      } else {
        await AppLogService().logError('Artikel nicht eingefügt - isValid() false: ${artikel.name}');
      }
    }
    await AppLogService().log('Artikel eingefügt: $insertedCount von ${artikelList.length}');
  }

// --- Backup ---
  static Future<void> importBackup(BuildContext context, [Future<void> Function()? reloadArtikel, bool setzePlatzhalter = false]) async {
    List<String> errors = [];
    List<Artikel> artikelList = [];
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Backup-Datei auswählen',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = File(result.files.single.path!);
    final jsonString = await file.readAsString();
    if (jsonString.isEmpty) {
      await AppLogService().logError('Die JSON-Datei ist leer oder ungültig.');
      final String backupFolder = 'backup_20250923_1520'; // Beispielwert
      throw Exception('Keine gültige JSON-Backup-Datei im Ordner $backupFolder gefunden.');
    }

    artikelList = await ArtikelImportService().importFromJson(jsonString);
    // Konsistenzprüfung
    final konsistenzWarnungen = konsistenzPruefung(artikelList);
    if (konsistenzWarnungen.isNotEmpty) {
      errors.add('Konsistenzwarnungen:\n${konsistenzWarnungen.join('\n')}');
      await AppLogService().logError('Konsistenzwarnungen: ${konsistenzWarnungen.join('; ')}');
    }
    // Platzhalterbilder setzen falls gewünscht
    if (setzePlatzhalter) {
      artikelList = setzePlatzhalterBilder(artikelList);
    }

    final db = await ArtikelDbService().database;
    try {
      await db.transaction((txn) async {
        await txn.delete('artikel');
        for (final a in artikelList) {
          final map = a.toMap();
          try {
            await txn.insert('artikel', map, conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (e) {
            errors.add('Fehler beim Einfügen von Artikel ${a.name}: $e');
            await AppLogService().logError('Fehler beim Einfügen von Artikel ${a.name}: $e');
          }
        }
        final maxIdRow = await txn.rawQuery('SELECT MAX(id) as maxId FROM artikel');
        final maxId = (maxIdRow.isNotEmpty && maxIdRow.first['maxId'] != null)
            ? maxIdRow.first['maxId'] as int
            : 0;
        if (maxId > 0) {
          await txn.rawUpdate('UPDATE sqlite_sequence SET seq = ? WHERE name = ?', [maxId, 'artikel']);
        }
      });
      if (reloadArtikel != null) {
        await reloadArtikel();
      }
      await AppLogService().log('Backup-Restore erfolgreich: ${artikelList.length} Einträge wiederhergestellt');
      // Konsistenzprüfung
      final konsistenzWarnungen = konsistenzPruefung(artikelList);
      if (konsistenzWarnungen.isNotEmpty) {
        errors.add('Konsistenzwarnungen:\n${konsistenzWarnungen.join('\n')}');
        await AppLogService().logError('Konsistenzwarnungen: ${konsistenzWarnungen.join('; ')}');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup erfolgreich wiederhergestellt')),
        );
      }
      if (errors.isNotEmpty && context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Fehler und Warnungen beim Import'),
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
    [Future<void> Function()? reloadArtikel, bool setzePlatzhalter = false]
  ) async {
    List<String> errors = [];
    List<Artikel> artikelList = [];
    int successfulImages = 0;
    int failedImages = 0;
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

      // 2. Verfügbare Backup-Ordner zur Auswahl anzeigen
      if (!context.mounted) return;
      final backupFolder = await _showBackupFolderSelectionDialog(context, webdavClient, creds.baseFolder);
      if (backupFolder == null || backupFolder.isEmpty) return;
      final folderContents = await webdavClient.listFolders(backupFolder);
      if (!context.mounted) return;
      await AppLogService().log('Dateien im Ordner $backupFolder: $folderContents');

      // 3. JSON-Backup herunterladen und parsen
      final jsonFiles = ['backup.json']; // Mögliche Namen
      String? jsonContent;
      
      for (final jsonFileName in jsonFiles) {
        try {
          final fullPath = '${creds.baseFolder}/$backupFolder/$jsonFileName'; // Explizit baseFolder hinzufügen
          await AppLogService().log('Vollständiger Pfad: $fullPath');
          final jsonBytes = await webdavClient.downloadBytes(
            remoteRelativePath: fullPath,
          );
          await AppLogService().log('Größe der heruntergeladenen Datei: ${jsonBytes.length} Bytes');
          jsonContent = String.fromCharCodes(jsonBytes);
          await AppLogService().log('Heruntergeladene JSON-Datei: $jsonContent');
          break;
        } catch (e) {
          await AppLogService().logError('Fehler beim Herunterladen von $backupFolder/$jsonFileName: $e');
          // Versuche nächsten Dateinamen
          continue;
        }
      }
      if (jsonContent == null || jsonContent.isEmpty) {
        await AppLogService().log('Heruntergeladene JSON-Datei: $jsonContent');
        await AppLogService().logError('Die JSON-Datei ist leer oder ungültig.');
        throw Exception('Keine gültige JSON-Backup-Datei im Ordner $backupFolder gefunden.');
      }

      try {
        artikelList = await ArtikelImportService().importFromJson(jsonContent);
        // Konsistenzprüfung
        final konsistenzWarnungen = konsistenzPruefung(artikelList);
        if (konsistenzWarnungen.isNotEmpty) {
          errors.add('Konsistenzwarnungen:\n${konsistenzWarnungen.join('\n')}');
          await AppLogService().logError('Konsistenzwarnungen: ${konsistenzWarnungen.join('; ')}');
        }
        // Platzhalterbilder setzen falls gewünscht
        if (setzePlatzhalter) {
          artikelList = setzePlatzhalterBilder(artikelList);
        }
        await AppLogService().log('Anzahl der importierten Artikel: ${artikelList.length}');
      } catch (e) {
        errors.add('Fehler beim Verarbeiten der JSON-Datei: $e');
        await AppLogService().logError('Fehler beim Verarbeiten der JSON-Datei: $e');
        throw Exception('Fehler beim Verarbeiten der JSON-Datei: $e');
      }

      // 4. Lokales Verzeichnis für Bilder vorbereiten
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'images'));
      await imagesDir.create(recursive: true);

      // 5. Bilder herunterladen und lokale Pfade aktualisieren
      for (int i = 0; i < artikelList.length; i++) {
        var artikel = artikelList[i];
        if (artikel.remoteBildPfad != null && artikel.remoteBildPfad!.isNotEmpty) {
          try {
            final localImagePath = '${imagesDir.path}/artikel_${artikel.id}_image.jpg';
            await webdavClient.downloadFileNew(
              remoteRelativePath: artikel.remoteBildPfad!,
              localPath: localImagePath,
            );
            final fileExists = await File(localImagePath).exists();
            if (fileExists) {
              await AppLogService().log('Bild heruntergeladen: $localImagePath');
              artikel = artikel.copyWith(bildPfad: localImagePath);
              artikelList[i] = artikel;
              successfulImages++;
            } else {
              errors.add('Bild-Datei nicht gefunden nach Download: $localImagePath');
              await AppLogService().logError('Bild-Datei nicht gefunden nach Download: $localImagePath');
              failedImages++;
            }
          } catch (e) {
            failedImages++;
            errors.add('Fehler bei Artikel ${artikel.name}: $e');
            await AppLogService().logError('Failed to download image for article ${artikel.name}: $e');
          }
        }
      }

      // 6. Artikel in Datenbank importieren
      final db = await ArtikelDbService().database;
      await db.transaction((txn) async {
        await txn.delete('artikel');
        for (final a in artikelList) {
          final map = a.toMap();
          try {
            await txn.insert('artikel', map, conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (e) {
            errors.add('Fehler beim Einfügen von Artikel ${a.name}: $e');
            await AppLogService().logError('Fehler beim Einfügen von Artikel ${a.name}: $e');
          }
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

      // 👉 HIER: Logging nach dem Import hinzufügen (Lösung 2)
      final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM artikel');
      final artikelCount = countResult.first['count'] as int;
      await AppLogService().log('Artikel in DB nach Import: $artikelCount');

      // 7. Artikelliste neu laden
      if (reloadArtikel != null) {
        await reloadArtikel();
        await AppLogService().log('reloadArtikel aufgerufen');
      } else {
        errors.add('reloadArtikel ist null - Liste wird nicht neu geladen');
        await AppLogService().logError('reloadArtikel ist null - Liste wird nicht neu geladen');
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
            title: const Text('Fehler und Warnungen beim Import'),
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

  /// Importiert ein ZIP-Backup inklusive Bilder
  static Future<void> importBackupFromZip(BuildContext context, [Future<void> Function()? reloadArtikel, bool setzePlatzhalter = false]) async {
    List<String> errors = [];
    List<Artikel> artikelList = [];
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'ZIP-Backup auswählen',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.isEmpty) return;
    final zipFile = File(result.files.single.path!);
    if (!await zipFile.exists()) {
      await AppLogService().logError('ZIP-Datei nicht gefunden: ${zipFile.path}');
      return;
    }
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    String? jsonContent;
    final imageFiles = <ArchiveFile>[];
    for (final file in archive) {
      if (file.isFile) {
        if (file.name == 'artikel_backup.json') {
          jsonContent = utf8.decode(file.content as List<int>);
        } else if (file.name.startsWith('images/') && file.name.endsWith('.jpg')) {
          imageFiles.add(file);
        }
      }
    }
    if (jsonContent == null) {
      errors.add('Keine artikel_backup.json im ZIP gefunden.');
      await AppLogService().logError('Keine artikel_backup.json im ZIP gefunden.');
      _showImportErrors(context, errors);
      return;
    }
    try {
      artikelList = await ArtikelImportService().importFromJson(jsonContent);
      if (artikelList.isEmpty) {
        errors.add('Keine Artikel im Backup gefunden.');
        await AppLogService().logError('Keine Artikel im Backup gefunden.');
      }
    } catch (e) {
      errors.add('Fehler beim Verarbeiten der JSON: $e');
      await AppLogService().logError('Fehler beim Verarbeiten der JSON: $e');
    }
    // Bilder ins lokale Verzeichnis kopieren und bildPfad aktualisieren
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'images'));
    await imagesDir.create(recursive: true);
    int successfulImages = 0;
    int failedImages = 0;
    for (final artikel in artikelList) {
      final imageFile = imageFiles.firstWhere(
        (img) => img.name.contains('images/${artikel.id}_'),
        orElse: () => ArchiveFile('', 0, []),
      );
      if (imageFile.name.isNotEmpty) {
        final localImagePath = p.join(imagesDir.path, p.basename(imageFile.name));
        try {
          final outFile = File(localImagePath);
          await outFile.writeAsBytes(imageFile.content as List<int>);
          artikelList = artikelList.map((a) => a.id == artikel.id ? a.copyWith(bildPfad: localImagePath) : a).toList();
          successfulImages++;
        } catch (e) {
          failedImages++;
          errors.add('Fehler beim Schreiben von Bild für Artikel ${artikel.name}: $e');
          await AppLogService().logError('Fehler beim Schreiben von Bild für Artikel ${artikel.name}: $e');
        }
      } else {
        failedImages++;
        errors.add('Kein Bild im ZIP für Artikel ${artikel.name} gefunden.');
        await AppLogService().logError('Kein Bild im ZIP für Artikel ${artikel.name} gefunden.');
      }
    }
    // Artikel in DB importieren
    final db = await ArtikelDbService().database;
    try {
      await db.transaction((txn) async {
        await txn.delete('artikel');
        for (final a in artikelList) {
          final map = a.toMap();
          try {
            await txn.insert('artikel', map, conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (e) {
            errors.add('Fehler beim Einfügen von Artikel ${a.name}: $e');
            await AppLogService().logError('Fehler beim Einfügen von Artikel ${a.name}: $e');
          }
        }
        final maxIdRow = await txn.rawQuery('SELECT MAX(id) as maxId FROM artikel');
        final maxId = (maxIdRow.isNotEmpty && maxIdRow.first['maxId'] != null)
            ? maxIdRow.first['maxId'] as int
            : 0;
        if (maxId > 0) {
          await txn.rawUpdate('UPDATE sqlite_sequence SET seq = ? WHERE name = ?', [maxId, 'artikel']);
        }
      });
      if (reloadArtikel != null) {
        await reloadArtikel();
        if (!context.mounted) return;
      }
    } catch (e) {
      errors.add('Fehler beim DB-Import: $e');
      await AppLogService().logError('Fehler beim DB-Import: $e');
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'ZIP-Backup erfolgreich wiederhergestellt!\n'
          'Artikel: ${artikelList.length}\n'
          'Bilder: $successfulImages erfolgreich, $failedImages Fehler'
        ),
        duration: const Duration(seconds: 5),
      ),
    );
    // Platzhalterbilder setzen falls gewünscht
    if (setzePlatzhalter) {
      artikelList = setzePlatzhalterBilder(artikelList);
    }
    if (errors.isNotEmpty && context.mounted) {
      _showImportErrors(context, errors);
    }

    // Konsistenzprüfung nach dem Restore
    final konsistenzWarnungen = <String>[];
    // 1. Prüfe, ob alle Artikel ein Bild haben
    final artikelOhneBild = artikelList.where((a) => a.bildPfad.isEmpty).toList();
    if (artikelOhneBild.isNotEmpty) {
      konsistenzWarnungen.add('Artikel ohne Bild: ${artikelOhneBild.map((a) => a.name).join(', ')}');
    }
    // 2. Prüfe, ob alle IDs eindeutig sind
    final idSet = <int>{};
    final doppelteIds = <int>[];
    for (final a in artikelList) {
      if (a.id != null) {
        if (!idSet.add(a.id!)) doppelteIds.add(a.id!);
      }
    }
    if (doppelteIds.isNotEmpty) {
      konsistenzWarnungen.add('Doppelte IDs gefunden: ${doppelteIds.join(', ')}');
    }
    // 3. Prüfe, ob Namen eindeutig sind
    final nameSet = <String>{};
    final doppelteNamen = <String>[];
    for (final a in artikelList) {
      if (!nameSet.add(a.name)) doppelteNamen.add(a.name);
    }
    if (doppelteNamen.isNotEmpty) {
      konsistenzWarnungen.add('Doppelte Namen gefunden: ${doppelteNamen.join(', ')}');
    }
    // Konsistenzwarnungen zu Fehlern hinzufügen
    if (konsistenzWarnungen.isNotEmpty) {
      errors.add('Konsistenzwarnungen:\n${konsistenzWarnungen.join('\n')}');
      await AppLogService().logError('Konsistenzwarnungen: ${konsistenzWarnungen.join('; ')}');
    }
  }

  /// Zeigt Fehler und Warnungen nach dem Import als Dialog an
  static void _showImportErrors(BuildContext context, List<String> errors) {
    if (!context.mounted || errors.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fehler und Warnungen beim Import'),
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

  /// Dialog zur Auswahl des Backup-Ordners aus verfügbaren Ordnern
  static Future<String?> _showBackupFolderSelectionDialog(
    BuildContext context, 
    NextcloudWebDavClient webdavClient,
    String baseFolder,
  ) async {
    try {
      // Verfügbare Ordner in baseFolder abrufen
      await AppLogService().log('Lade verfügbare Backup-Ordner...');
      final folders = await webdavClient.listFolders(baseFolder);
      
      // Nur Backup-Ordner filtern (beginnen mit "backup_")
      final backupFolders = folders
          .where((folder) => folder.startsWith('backup_'))
          .toList();
      
      if (backupFolders.isEmpty) {
        if (!context.mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Backup-Ordner gefunden.')),
        );
        return null;
      }
      
      // Nach Datum sortieren (neueste zuerst)
      backupFolders.sort((a, b) => b.compareTo(a));
      
      if (!context.mounted) return null;
      
      return showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Backup-Ordner auswählen'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backupFolders.length,
              itemBuilder: (context, index) {
                final folder = backupFolders[index];
                final displayName = _formatBackupFolderName(folder);
                
                return ListTile(
                  title: Text(folder),
                  subtitle: Text(displayName),
                  leading: const Icon(Icons.folder),
                  onTap: () => Navigator.pop(ctx, folder),
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
      
    } catch (e) {
      await AppLogService().logError('Fehler beim Laden der Backup-Ordner: $e');
      if (!context.mounted) return null;
      
      // Fallback: Manuelle Eingabe
      return _showBackupFolderDialog(context);
    }
  }

  /// Formatiert Backup-Ordner-Namen für bessere Lesbarkeit
  static String _formatBackupFolderName(String folderName) {
    // backup_202509221430 -> 22.09.2025 14:30
    if (folderName.startsWith('backup_') && folderName.length == 19) {
      final timestamp = folderName.substring(7); // Remove "backup_"
      if (timestamp.length == 12) {
        final year = timestamp.substring(0, 4);
        final month = timestamp.substring(4, 6);
        final day = timestamp.substring(6, 8);
        final hour = timestamp.substring(8, 10);
        final minute = timestamp.substring(10, 12);
        
        return '$day.$month.$year $hour:$minute';
      }
    }
    return folderName;
  }

  /// Dialog zur Eingabe des Backup-Ordner-Namens (Fallback)
  static Future<String?> _showBackupFolderDialog(BuildContext context) async {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup-Ordner eingeben'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Geben Sie den Namen des Backup-Ordners in Nextcloud ein:\n'
              '(z.B. backup_202509221430)',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Backup-Ordner-Name',
                hintText: 'backup_202509221430',
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

  /// Konsistenzprüfung für Artikelliste
  static List<String> konsistenzPruefung(List<Artikel> artikelList) {
    final warnungen = <String>[];
    final artikelOhneBild = artikelList.where((a) => a.bildPfad.isEmpty).toList();
    if (artikelOhneBild.isNotEmpty) {
      warnungen.add('Artikel ohne Bild: ${artikelOhneBild.map((a) => a.name).join(', ')}');
    }
    final idSet = <int>{};
    final doppelteIds = <int>[];
    for (final a in artikelList) {
      if (a.id != null) {
        if (!idSet.add(a.id!)) doppelteIds.add(a.id!);
      }
    }
    if (doppelteIds.isNotEmpty) {
      warnungen.add('Doppelte IDs gefunden: ${doppelteIds.join(', ')}');
    }
    final nameSet = <String>{};
    final doppelteNamen = <String>[];
    for (final a in artikelList) {
      if (!nameSet.add(a.name)) doppelteNamen.add(a.name);
    }
    if (doppelteNamen.isNotEmpty) {
      warnungen.add('Doppelte Namen gefunden: ${doppelteNamen.join(', ')}');
    }
    return warnungen;
  }

  /// Pfad zum Platzhalterbild
  static const String placeholderImagePath = 'assets/images/placeholder.jpg';

  /// Ersetzt fehlende Bilder durch Platzhalterbild
  static List<Artikel> setzePlatzhalterBilder(List<Artikel> artikelList) {
    return artikelList.map((a) {
      if (a.bildPfad.isEmpty) {
        return a.copyWith(bildPfad: placeholderImagePath);
      }
      return a;
    }).toList();
  }
}
