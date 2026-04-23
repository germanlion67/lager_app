// lib/services/artikel_import_service.dart

import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart' show ArchiveFile, ZipDecoder;
import 'package:logger/logger.dart';
import '../config/app_images.dart';
import '../models/artikel_model.dart';
import 'artikel_db_service.dart';
import 'pocketbase_service.dart';
import 'app_log_service.dart';

// Conditional imports
import 'import_io.dart'
    if (dart.library.html) 'import_stub.dart' as platform;

// Nextcloud-Import (nur Mobile)
import 'import_nextcloud.dart' as nextcloud_import;

// ✅ Lokale Logger-Referenz — einmal definiert, überall nutzbar
final Logger _logger = AppLogService.logger;

class ArtikelImportService {
  // ==================== JSON/CSV PARSING ====================

  static const _requiredFields = ['name', 'ort', 'fach', 'menge'];

  static String? _validateArtikelMap(Map<String, dynamic> map) {
    for (final field in _requiredFields) {
      if (!map.containsKey(field) || map[field] == null) {
        return 'Pflichtfeld "$field" fehlt oder ist null';
      }
    }
    if (map['name'] is! String || (map['name'] as String).trim().isEmpty) {
      return '"name" muss ein nicht-leerer String sein';
    }
    if (map['ort'] is! String) {
      return '"ort" muss ein String sein';
    }
    if (map['fach'] is! String) {
      return '"fach" muss ein String sein';
    }
    final mengeRaw = map['menge'];
    if (mengeRaw is! int) {
      final parsed = int.tryParse(mengeRaw?.toString() ?? '');
      if (parsed == null) {
        return '"menge" muss eine Ganzzahl sein (Wert: $mengeRaw)';
      }
    }
    return null;
  }

  /// Importiert Artikel aus einem JSON-String
  Future<List<Artikel>> importFromJson(String jsonString) async {
    dynamic decoded;
    try {
      decoded = json.decode(jsonString);
    } catch (e, stack) {
      // ✅ named parameters
      _logger.e('JSON-Parse-Fehler:', error: e, stackTrace: stack);
      throw FormatException('Ungültiges JSON: $e');
    }

    if (decoded is! List) {
      // ✅ kein await — void
      _logger.e(
        'JSON-Schema-Fehler: Erwartet eine Liste, '
        'erhalten: ${decoded.runtimeType}',
      );
      throw FormatException(
        'JSON muss eine Liste von Artikeln sein, '
        'nicht ${decoded.runtimeType}',
      );
    }

    final List<dynamic> jsonList = decoded;
    final artikelList = <Artikel>[];

    for (int i = 0; i < jsonList.length; i++) {
      final item = jsonList[i];
      try {
        if (item is! Map<String, dynamic>) {
          // ✅ kein await — void
          _logger.e(
            'Artikel[$i] übersprungen — kein Objekt: ${item.runtimeType}',
          );
          continue;
        }

        final validationError = _validateArtikelMap(item);
        if (validationError != null) {
          // ✅ kein await — void
          _logger.e('Artikel[$i] übersprungen — $validationError: $item');
          continue;
        }

        item['bildPfad'] ??= '';
        artikelList.add(Artikel.fromMap(item));
      } catch (e, stack) {
        // ✅ named parameters
        _logger.e('Fehler bei Artikel[$i]:', error: e, stackTrace: stack);
        continue;
      }
    }
    return artikelList;
  }

  /// Importiert Artikel aus einem CSV-String
  Future<List<Artikel>> importFromCsv(String csvString) async {
    if (csvString.trim().isEmpty) return [];

    final cleanedCsv = csvString.startsWith('\uFEFF')
        ? csvString.substring(1)
        : csvString;

    List<List<dynamic>> rows;
    try {
      rows = const CsvDecoder().convert(cleanedCsv);
    } catch (e, stack) {
      // ✅ named parameters
      _logger.e('CSV-Parse-Fehler:', error: e, stackTrace: stack);
      throw FormatException('Ungültiges CSV-Format: $e');
    }

    if (rows.isEmpty) return [];

    final header = rows.first.map((h) => h.toString().trim()).toList();

    for (final field in _requiredFields) {
      if (!header.contains(field)) {
        // ✅ kein await — void
        _logger.e('CSV-Schema-Fehler: Pflichtfeld "$field" fehlt im Header');
        throw FormatException(
          'CSV-Header enthält nicht das Pflichtfeld "$field"',
        );
      }
    }

    final artikelList = <Artikel>[];

    for (int i = 1; i < rows.length; i++) {
      final values = rows[i];

      if (values.every((v) => v.toString().trim().isEmpty)) continue;

      final paddedValues = List<String>.generate(
        header.length,
        (idx) => idx < values.length ? values[idx].toString().trim() : '',
      );

      final map = Map<String, String>.fromIterables(header, paddedValues);

      final mengeStr = map['menge'] ?? '';
      map['menge'] = (int.tryParse(mengeStr) ?? 0).toString();

      map['bildPfad'] ??= '';
      if (map['bildPfad']!.isEmpty) map['bildPfad'] = '';

      final mapDynamic = Map<String, dynamic>.from(map);
      final validationError = _validateArtikelMap(mapDynamic);
      if (validationError != null) {
        // ✅ kein await — void
        _logger.e('CSV-Zeile[$i] übersprungen — $validationError');
        continue;
      }

      try {
        artikelList.add(Artikel.fromMap(mapDynamic));
      } catch (e, stack) {
        // ✅ named parameters
        _logger.e('Fehler bei CSV-Zeile[$i]:', error: e, stackTrace: stack);
        continue;
      }
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
        // ✅ kein await — void
        _logger.e(
          'Artikel nicht eingefügt — isValid() false: ${artikel.name}',
        );
      }
    }
    // ✅ kein await — void
    _logger.i('Artikel eingefügt: $insertedCount von ${artikelList.length}');
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
        } catch (e, stack) {
          // ✅ named parameters
          _logger.e(
            'PocketBase Insert Fehler (${artikel.name}):',
            error: e,
            stackTrace: stack,
          );
        }
      }
    }
    // ✅ kein await — void
    _logger.i(
      'Artikel in PocketBase eingefügt: '
      '$insertedCount von ${artikelList.length}',
    );
  }

  // ==================== DATEI-IMPORT (JSON/CSV) ====================

  /// Zeigt Datei-Picker und importiert JSON/CSV
  static Future<void> importArtikel(
    BuildContext context,
    Future<void> Function() reloadArtikel,
  ) async {
    final FilePickerResult? result;
        try {
          result = await FilePicker.pickFiles(
            allowMultiple: false,
            type: FileType.custom,
            allowedExtensions: ['json', 'csv'],
            withData: true,
          );
        } catch (e) {
          _logger.w('FilePicker nicht verfügbar (z.B. WSL2/headless): $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Dateiauswahl nicht verfügbar. '
                  'Unter WSL2/Linux ohne Desktop-Portal nicht unterstützt.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final ext = file.extension?.toLowerCase();

    String content;
    if (file.bytes != null) {
      content = utf8.decode(file.bytes!, allowMalformed: true);
    } else if (!kIsWeb && file.path != null) {
      content = await platform.readFileAsString(file.path!);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datei konnte nicht gelesen werden'),
          ),
        );
      }
      return;
    }

    List<Artikel> artikelList = [];
    String importMsg = '';

    try {
      if (ext == 'json') {
        // ✅ kein await — void
        _logger.i('JSON-Import gestartet');
        artikelList = await ArtikelImportService().importFromJson(content);
        importMsg = 'Importierte Artikel aus JSON: ${artikelList.length}';
      } else if (ext == 'csv') {
        // ✅ kein await — void
        _logger.i('CSV-Import gestartet');
        artikelList = await ArtikelImportService().importFromCsv(content);
        importMsg = 'Importierte Artikel aus CSV: ${artikelList.length}';
      } else {
        importMsg = 'Dateiformat nicht unterstützt.';
      }

      if (artikelList.isNotEmpty) {
        await ArtikelImportService().insertArtikelList(artikelList);
        await reloadArtikel();
      }

      // ✅ kein await — void
      _logger.i(importMsg);
    } catch (e, stack) {
      importMsg = 'Fehler beim Import: $e';
      // ✅ named parameters — war positional
      _logger.e('Fehler beim Import:', error: e, stackTrace: stack);
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
      } else if (file.name.startsWith('images/') &&
          file.name.endsWith('.jpg')) {
        imageFiles.add(file);
      }
    }

    if (jsonContent == null) {
      errors?.add('Keine artikel_backup.json im ZIP gefunden.');
      throw StateError('artikel_backup.json fehlt im ZIP-Backup');
    }

    List<Artikel> artikelList;
    try {
      artikelList =
          await ArtikelImportService().importFromJson(jsonContent);
    } catch (e, stack) {
      errors?.add('Fehler beim Verarbeiten der JSON: $e');
      // ✅ named parameters
      _logger.e(
        'ZIP JSON-Verarbeitung fehlgeschlagen:',
        error: e,
        stackTrace: stack,
      );
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
    final FilePickerResult? result;
        try {
          result = await FilePicker.pickFiles(
            dialogTitle: 'ZIP-Backup auswählen',
            type: FileType.custom,
            allowedExtensions: ['zip'],
            withData: true,
          );
        } catch (e) {
          _logger.w('FilePicker nicht verfügbar (z.B. WSL2/headless): $e');
          return (false, [
            'Dateiauswahl nicht verfügbar. '
            'Unter WSL2/Linux ohne Desktop-Portal nicht unterstützt.',
          ]);
        }
        if (result == null || result.files.isEmpty) {
          return (false, ['Keine ZIP-Datei ausgewählt.']);
        }

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

    if (!kIsWeb) {
      artikelList = await platform.extractImagesToLocal(
        artikelList,
        imageFiles,
        errors,
      );
    }

    try {
      if (kIsWeb) {
        await _replaceArtikelInPocketBase(artikelList, errors: errors);
      } else {
        await _replaceArtikelInSqlite(artikelList, errors: errors);
      }
      if (reloadArtikel != null) await reloadArtikel();
    } catch (e, stack) {
      errors.add('Fehler beim DB-Import: $e');
      // ✅ named parameters
      _logger.e('DB-Import fehlgeschlagen:', error: e, stackTrace: stack);
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
      } catch (e, stack) {
        errors?.add('Fehler beim Einfügen: ${artikel.name}: $e');
        // ✅ named parameters
        _logger.e(
          'DB Insert Fehler (${artikel.name}):',
          error: e,
          stackTrace: stack,
        );
      }
    }

    // ✅ kein await — void
    _logger.i('Artikel in SQLite importiert: ${artikelList.length}');
  }

  /// Ersetzt alle Artikel in PocketBase (Web)
  static Future<void> _replaceArtikelInPocketBase(
    List<Artikel> artikelList, {
    List<String>? errors,
  }) async {
    final pb = PocketBaseService().client;

    try {
      final existing = await pb.collection('artikel').getFullList();
      for (final record in existing) {
        await pb.collection('artikel').delete(record.id);
      }
    } catch (e, stack) {
      errors?.add('Fehler beim Löschen bestehender Artikel: $e');
      // ✅ named parameters
      _logger.e(
        'PocketBase Löschen fehlgeschlagen:',
        error: e,
        stackTrace: stack,
      );
    }

    for (final artikel in artikelList) {
      try {
        final body = artikel.toMap();
        body.remove('id');
        await pb.collection('artikel').create(body: body);
      } catch (e, stack) {
        errors?.add('PB Insert Fehler (${artikel.name}): $e');
        // ✅ named parameters
        _logger.e(
          'PocketBase Insert Fehler (${artikel.name}):',
          error: e,
          stackTrace: stack,
        );
      }
    }

    // ✅ kein await — void
    _logger.i(
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
          const SnackBar(
            content: Text('Nextcloud-Import im Web nicht verfügbar'),
          ),
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

    final artikelOhneBild =
        artikelList.where((a) => a.bildPfad.isEmpty).toList();
    if (artikelOhneBild.isNotEmpty) {
      warnungen.add(
        'Artikel ohne Bild: '
        '${artikelOhneBild.map((a) => a.name).join(', ')}',
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

  static List<Artikel> setzePlatzhalterBilder(List<Artikel> artikelList) {
    return artikelList.map((a) {
      if (a.bildPfad.isEmpty) {
        return a.copyWith(bildPfad: AppImages.platzhalterBildPfad);
      }
      return a;
    }).toList();
  }

  /// Fehler-Dialog anzeigen
  static void showImportErrors(
    BuildContext context,
    List<String> errors,
  ) {
    if (!context.mounted || errors.isEmpty) return;
    showDialog<void>(
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
}