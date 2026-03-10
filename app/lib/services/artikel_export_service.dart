// lib/services/artikel_export_service.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart' show Archive, ArchiveFile, ZipEncoder;
import 'app_log_service.dart';
import 'artikel_db_service.dart';
import 'pocketbase_service.dart';

// Conditional imports
import 'export_io.dart'
    if (dart.library.html) 'export_stub.dart' as platform;

// Nextcloud nur auf Mobile
import 'export_nextcloud_stub.dart'
    if (dart.library.io) 'export_nextcloud.dart' as nextcloud;

final JsonEncoder _prettyJsonEncoder = JsonEncoder.withIndent('  ');

class ArtikelExportService {

  // ==================== JSON/CSV EXPORT ====================

  Future<String> exportAllArtikelAsJson() async {
    final artikelList = await _loadArtikel();
    final jsonList = artikelList.map((a) => a.toMap()).toList();
    return _prettyJsonEncoder.convert(jsonList);
  }

  Future<String> exportAllArtikelAsCsv() async {
    final artikelList = await _loadArtikel();
    if (artikelList.isEmpty) return '';

    final header = [
      'id', 'name', 'menge', 'ort', 'fach', 'beschreibung',
      'bildPfad', 'erstelltAm', 'aktualisiertAm', 'remoteBildPfad',
    ];

    final List<List<String>> rows = [header];
    for (final artikel in artikelList) {
      final map = artikel.toMap();
      rows.add(header.map((h) => map[h]?.toString() ?? '').toList());
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Lädt Artikel plattformabhängig
  Future<List<dynamic>> _loadArtikel() async {
    if (kIsWeb) {
      final pb = PocketBaseService().client;
      final records = await pb.collection('artikel').getFullList(sort: '-created');
      // Rückgabe als Maps, damit toMap() nicht nötig ist
      return records.map((r) => _recordToArtikelMap(r)).toList();
    } else {
      return await ArtikelDbService().getAlleArtikel();
    }
  }

  Map<String, dynamic> _recordToArtikelMap(dynamic record) {
    return {
      ...Map<String, dynamic>.from(record.data),
      'id': record.id,
    };
  }

  // ==================== EXPORT DIALOG ====================

  Future<void> showExportDialog(BuildContext context) async {
    try {
      final exportType = await showDialog<String>(
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

      String exportData;
      if (exportType == 'json') {
        exportData = await exportAllArtikelAsJson();
      } else {
        exportData = await exportAllArtikelAsCsv();
      }

      if (exportData.isEmpty) {
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

  // ==================== ZIP BACKUP ====================

  Future<String?> backupToZipFile(BuildContext context) async {
    if (kIsWeb) {
      // Web: ZIP mit Daten aus PocketBase (ohne lokale Bilder)
      return await _backupToZipWeb(context);
    } else {
      // Mobile: ZIP mit lokalen Daten + Bildern
      return await _backupToZipMobile(context);
    }
  }

  /// Web: ZIP-Backup nur mit JSON-Daten (keine lokalen Bilder)
  Future<String?> _backupToZipWeb(BuildContext context) async {
    await AppLogService().log('ZIP-Backup (Web) gestartet');

    try {
      final jsonString = await exportAllArtikelAsJson();
      if (jsonString == '[]') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Keine Artikel für Backup vorhanden')),
          );
        }
        return null;
      }

      final archive = Archive();
      archive.addFile(ArchiveFile(
        'artikel_backup.json',
        jsonString.length,
        utf8.encode(jsonString),
      ));

      final zipData = ZipEncoder().encode(archive);
      final filename = _buildBackupFilename();

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Backup als ZIP speichern',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: Uint8List.fromList(zipData),
      );

      if (result != null && context.mounted) {
        await AppLogService().log('ZIP-Backup (Web) gespeichert: $filename');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ZIP-Backup erfolgreich gespeichert')),
        );
      }

      return result;
    } catch (e, stack) {
      await AppLogService().logError('ZIP-Backup (Web) Fehler: $e', stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

  /// Mobile: ZIP-Backup mit JSON + lokalen Bildern
  Future<String?> _backupToZipMobile(BuildContext context) async {
    await AppLogService().log('ZIP-Backup (Mobile) gestartet');

    try {
      final artikelList = await ArtikelDbService().getAlleArtikel();
      if (artikelList.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Keine Artikel für Backup vorhanden')),
          );
        }
        return null;
      }

      final jsonList = artikelList.map((a) => a.toMap()).toList();
      final jsonString = _prettyJsonEncoder.convert(jsonList);

      final archive = Archive();
      archive.addFile(ArchiveFile(
        'artikel_backup.json',
        jsonString.length,
        utf8.encode(jsonString),
      ));

      // Bilder hinzufügen (nur Mobile)
      for (final artikel in artikelList) {
        if (artikel.bildPfad.isNotEmpty) {
          final imageBytes = await platform.readFileBytesIfExists(artikel.bildPfad);
          if (imageBytes != null) {
            final fileName =
                'images/${artikel.id}_${_slug(artikel.name)}.jpg';
            archive.addFile(ArchiveFile(fileName, imageBytes.length, imageBytes));
          }
        }
      }

      final zipData = ZipEncoder().encode(archive);
      final filename = _buildBackupFilename();

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Backup als ZIP speichern',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: Uint8List.fromList(zipData),
      );

      if (result != null) {
        await AppLogService().log('ZIP-Backup gespeichert: $filename');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ZIP-Backup erfolgreich gespeichert')),
          );
        }
      }

      return result;
    } catch (e, stack) {
      await AppLogService().logError('ZIP-Backup Fehler: $e', stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

  // ==================== NEXTCLOUD BACKUP ====================

  /// ZIP-Backup zu Nextcloud hochladen (nur Mobile)
  Future<void> backupZipToNextcloud(String zipFilePath, {BuildContext? context}) async {
    if (kIsWeb) return; // Im Web nicht verfügbar
    await nextcloud.uploadZipToNextcloud(zipFilePath, context: context);
  }

  /// Vollständiges Backup mit Bildern zu Nextcloud (nur Mobile)
  Future<void> backupWithImagesToNextcloud(BuildContext context) async {
    if (kIsWeb) return;
    await nextcloud.backupWithImagesToNextcloud(context);
  }

  // ==================== HELPER ====================

  String _buildBackupFilename() {
    final now = DateTime.now();
    return 'backup_'
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '.zip';
  }

  String _slug(String input) {
    return input
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .toLowerCase();
  }
}
