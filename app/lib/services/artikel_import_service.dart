// lib/services/artikel_import_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart' show ArchiveFile, ZipDecoder;
import '../models/artikel_model.dart';
import 'artikel_db_service.dart';
import 'pocketbase_service.dart';
import 'app_log_service.dart';

// Conditional imports
import 'import_io.dart'
    if (dart.library.html) 'import_stub.dart' as platform;

// Nextcloud-Import (nur Mobile)
import 'import_nextcloud.dart' as nextcloud_import;

class ArtikelImportService {
  // ==================== JSON/CSV PARSING ====================

  /// Importiert Artikel aus einem JSON-String
  Future<List<Artikel>> importFromJson(String jsonString) async {
    final List<dynamic> jsonList = json.decode(jsonString);
    final artikelList = <Artikel>[];

    for (final item in jsonList) {
      try {
        final map = item as Map<String, dynamic>;
        if (!map.containsKey('name')) {
          await AppLogService().logError('Artikel übersprungen - Fehlende Felder: $map');
          continue;
        }
        map['bildPfad'] ??= '';
        artikelList.add(Artikel.fromMap(map));
      } catch (e) {
        await AppLogService().logError('Fehler bei Artikel: $item - $e');
        continue;
      }
    }
    return artikelList;
  }

  /// Importiert Artikel aus einem CSV-String
  Future<List<Artikel>> importFromCsv(String csvString) async {
    final rows = const LineSplitter().convert(csvString.trim());
    if (rows.isEmpty) return [];

    final header = rows.first.split(',').map((h) => h.trim()).toList();
    final artikelList = <Artikel>[];

    for (final row in rows.skip(1)) {
      final values = row.split(',').map((v) => v.trim()).toList();
      if (values.length < header.length) continue;

      final map = Map<String, String>.fromIterables(header, values);

      if (map['menge'] != null && map['menge']!.isNotEmpty) {
        map['menge'] = (int.tryParse(map['menge']!) ?? 0).toString();
      } else {
        map['menge'] = '0';
      }

      if (map['bildPfad'] == null || map['bildPfad']!.isEmpty) {
        map['bildPfad'] = '';
      }

      artikelList.add(Artikel.fromMap(map));
    }
    return artikelList;
  }

  // ==================== DATENBANK-OPERATIONEN ====================

  /// Fügt Artikel in die Datenbank ein (Mobile: SQLite, Web: PocketBase)
  Future<void> insertArtikelList(List<Artikel> artikelList) async {
    if (kIsWeb) {
      await _insertArtikelListWeb(artikelList);
    } else {
      await _insertArtikelListMobile(artikelList);
    }
  }

  Future<void> _insertArtikelListMobile(List<Artikel> artikelList) async {
    final db = ArtikelDbService();
    int insertedCount = 0;
    for (var artikel in artikelList) {
      if (artikel.isValid()) {
        await db.insertArtikel(artikel);
        insertedCount++;
      } else {
        await AppLogService().logError(
          'Artikel nicht eingefügt - isValid() false: ${artikel.name}',
        );
      }
    }
    await AppLogService().log(
      'Artikel eingefügt: $insertedCount von ${artikelList.length}',
    );
  }

  Future<void> _insertArtikelListWeb(List<Artikel> artikelList) async {
    final pb = PocketBaseService().client;
    int insertedCount = 0;
    for (var artikel in artikelList) {
      if (artikel.isValid()) {
        try {
          final body = artikel.toMap();
          body.remove('id');
          await pb.collection('artikel').create(body: body);
          insertedCount++;
        } catch (e) {
          await AppLogService().logError(
            'PocketBase Insert Fehler (${artikel.name}): $e',
          );
        }
      }
    }
    await AppLogService().log(
      'Artikel in PocketBase eingefügt: $insertedCount von ${artikelList.length}',
    );
  }

  // ==================== DATEI-IMPORT (JSON/CSV) ====================

  /// Zeigt Datei-Picker und importiert JSON/CSV
  static Future<void> importArtikel(
    BuildContext context,
    Future<void> Function() reloadArtikel,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['json', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final ext = file.extension?.toLowerCase();

    // Datei-Inhalt lesen (Web: aus bytes, Mobile: aus Datei)
    String content;
    if (file.bytes != null) {
      content = String.fromCharCodes(file.bytes!);
    } else if (!kIsWeb && file.path != null) {
      content = await platform.readFileAsString(file.path!);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datei konnte nicht gelesen werden')),
        );
      }
      return;
    }

    List<Artikel> artikelList = [];
    String importMsg = '';

    try {
      if (ext == 'json') {
        await AppLogService().log('JSON-Import gestartet');
        artikelList = await ArtikelImportService().importFromJson(content);
        importMsg = 'Importierte Artikel aus JSON: ${artikelList.length}';
      } else if (ext == 'csv') {
        await AppLogService().log('CSV-Import gestartet');
        artikelList = await ArtikelImportService().importFromCsv(content);
        importMsg = 'Importierte Artikel aus CSV: ${artikelList.length}';
      } else {
        importMsg = 'Dateiformat nicht unterstützt.';
      }

      if (artikelList.isNotEmpty) {
        await ArtikelImportService().insertArtikelList(artikelList);
        await reloadArtikel();
      }

      await AppLogService().log(importMsg);
    } catch (e, stack) {
      importMsg = 'Fehler beim Import: $e';
      await AppLogService().logError(importMsg, stack);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(importMsg)),
    );
  }

  // ==================== ZIP-IMPORT ====================

  /// Parst ein ZIP-Backup und gibt Artikel + Bilddateien zurück
  static Future<(List<Artikel>, List<ArchiveFile>)> parseZipBackup(
    List<int> zipBytes, {
    List<String>? errors,
    bool setzePlatzhalter = false,
  }) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    String? jsonContent;
    final imageFiles = <ArchiveFile>[];

    for (final file in archive) {
      if (!file.isFile) continue;
      if (file.name == 'artikel_backup.json') {
        jsonContent = utf8.decode(file.content as List<int>);
      } else if (file.name.startsWith('images/') && file.name.endsWith('.jpg')) {
        imageFiles.add(file);
      }
    }

    if (jsonContent == null) {
      errors?.add('Keine artikel_backup.json im ZIP gefunden.');
      throw StateError('artikel_backup.json fehlt im ZIP-Backup');
    }

    List<Artikel> artikelList;
    try {
      artikelList = await ArtikelImportService().importFromJson(jsonContent);
    } catch (e) {
      errors?.add('Fehler beim Verarbeiten der JSON: $e');
      throw StateError('JSON im ZIP konnte nicht verarbeitet werden');
    }

    final warnungen = konsistenzPruefung(artikelList);
    if (warnungen.isNotEmpty) {
      errors?.add('Konsistenzwarnungen:\n${warnungen.join('\n')}');
    }

    if (setzePlatzhalter) {
      artikelList = setzePlatzhalterBilder(artikelList);
    }

    return (artikelList, imageFiles);
  }

  /// ZIP-Import Service (ohne UI)
  static Future<(bool, List<String>)> importBackupFromZipService({
    Future<void> Function()? reloadArtikel,
    bool setzePlatzhalter = false,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'ZIP-Backup auswählen',
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return (false, ['Keine ZIP-Datei ausgewählt.']);
    }

    // Bytes lesen (Web: aus bytes, Mobile: aus Datei)
    Uint8List bytes;
    if (result.files.single.bytes != null) {
      bytes = result.files.single.bytes!;
    } else if (!kIsWeb && result.files.single.path != null) {
      bytes = await platform.readFileBytes(result.files.single.path!);
    } else {
      return (false, ['Datei konnte nicht gelesen werden.']);
    }

    return await importZipBytesService(
      bytes,
      reloadArtikel,
      setzePlatzhalter,
    );
  }

  /// Importiert ZIP-Bytes (Service-Logik, ohne UI)
  static Future<(bool, List<String>)> importZipBytesService(
    List<int> zipBytes, [
    Future<void> Function()? reloadArtikel,
    bool setzePlatzhalter = false,
  ]) async {
    final errors = <String>[];
    List<Artikel> artikelList;
    List<ArchiveFile> imageFiles;

    try {
      final parsed = await parseZipBackup(
        zipBytes,
        errors: errors,
        setzePlatzhalter: setzePlatzhalter,
      );
      artikelList = parsed.$1;
      imageFiles = parsed.$2;
    } catch (_) {
      return (false, errors);
    }

    // Bilder lokal speichern (nur Mobile)
    if (!kIsWeb) {
      artikelList = await platform.extractImagesToLocal(
        artikelList,
        imageFiles,
        errors,
      );
    }

    // In Datenbank importieren
    try {
      if (kIsWeb) {
        await _replaceArtikelInPocketBase(artikelList, errors: errors);
      } else {
        await _replaceArtikelInSqlite(artikelList, errors: errors);
      }
      if (reloadArtikel != null) await reloadArtikel();
    } catch (e) {
      errors.add('Fehler beim DB-Import: $e');
      return (false, errors);
    }

    return (true, errors);
  }

  /// Ersetzt alle Artikel in der lokalen SQLite-DB
  static Future<void> _replaceArtikelInSqlite(
    List<Artikel> artikelList, {
    List<String>? errors,
  }) async {
    final dbService = ArtikelDbService();
    await dbService.resetDatabase();

    for (final artikel in artikelList) {
      try {
        await dbService.insertArtikel(artikel);
      } catch (e) {
        errors?.add('Fehler beim Einfügen: ${artikel.name}: $e');
        await AppLogService().logError('DB Insert Fehler (${artikel.name}): $e');
      }
    }

    await AppLogService().log(
      'Artikel in SQLite importiert: ${artikelList.length}',
    );
  }

  /// Ersetzt alle Artikel in PocketBase (Web)
  static Future<void> _replaceArtikelInPocketBase(
    List<Artikel> artikelList, {
    List<String>? errors,
  }) async {
    final pb = PocketBaseService().client;

    // Bestehende Artikel löschen
    try {
      final existing = await pb.collection('artikel').getFullList();
      for (final record in existing) {
        await pb.collection('artikel').delete(record.id);
      }
    } catch (e) {
      errors?.add('Fehler beim Löschen bestehender Artikel: $e');
    }

    // Neue Artikel einfügen
    for (final artikel in artikelList) {
      try {
        final body = artikel.toMap();
        body.remove('id');
        await pb.collection('artikel').create(body: body);
      } catch (e) {
        errors?.add('PB Insert Fehler (${artikel.name}): $e');
      }
    }

    await AppLogService().log(
      'Artikel in PocketBase importiert: ${artikelList.length}',
    );
  }

  // ==================== NEXTCLOUD ZIP-IMPORT ====================

  /// ZIP-Backup von Nextcloud importieren (nur Mobile)
  static Future<void> importZipBackupAuto(
    BuildContext context, [
    Future<void> Function()? reloadArtikel,
    bool setzePlatzhalter = false,
  ]) async {
    if (kIsWeb) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nextcloud-Import im Web nicht verfügbar')),
        );
      }
      return;
    }
    await nextcloud_import.importZipBackupAuto(
      context,
      reloadArtikel,
      setzePlatzhalter,
    );
  }

  // ==================== HILFSFUNKTIONEN ====================

  /// Konsistenzprüfung für Artikelliste
  static List<String> konsistenzPruefung(List<Artikel> artikelList) {
    final warnungen = <String>[];

    final artikelOhneBild = artikelList.where((a) => a.bildPfad.isEmpty).toList();
    if (artikelOhneBild.isNotEmpty) {
      warnungen.add(
        'Artikel ohne Bild: ${artikelOhneBild.map((a) => a.name).join(', ')}',
      );
    }

    final idSet = <int>{};
    final doppelteIds = <int>[];
    for (final a in artikelList) {
      if (a.id != null && !idSet.add(a.id!)) doppelteIds.add(a.id!);
    }
    if (doppelteIds.isNotEmpty) {
      warnungen.add('Doppelte IDs: ${doppelteIds.join(', ')}');
    }

    final nameSet = <String>{};
    final doppelteNamen = <String>[];
    for (final a in artikelList) {
      if (!nameSet.add(a.name)) doppelteNamen.add(a.name);
    }
    if (doppelteNamen.isNotEmpty) {
      warnungen.add('Doppelte Namen: ${doppelteNamen.join(', ')}');
    }

    return warnungen;
  }

  static const String placeholderImagePath = 'assets/images/placeholder.jpg';

  static List<Artikel> setzePlatzhalterBilder(List<Artikel> artikelList) {
    return artikelList.map((a) {
      if (a.bildPfad.isEmpty) return a.copyWith(bildPfad: placeholderImagePath);
      return a;
    }).toList();
  }

  /// Fehler-Dialog anzeigen
  static void showImportErrors(BuildContext context, List<String> errors) {
    if (!context.mounted || errors.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fehler und Warnungen beim Import'),
        content: SingleChildScrollView(child: Text(errors.join('\n\n'))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
