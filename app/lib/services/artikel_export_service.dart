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
import 'package:pocketbase/pocketbase.dart';
import 'pocketbase_service.dart';
import '../models/artikel_model.dart'; // NEU ✅

// Conditional imports
import 'export_io.dart'
    if (dart.library.html) 'export_stub.dart' as platform;

// Nextcloud nur auf Mobile
import 'export_nextcloud_stub.dart'
    if (dart.library.io) 'export_nextcloud.dart' as nextcloud;

final JsonEncoder _prettyJsonEncoder = const JsonEncoder.withIndent('  ');

class ArtikelExportService {

  // ==================== JSON/CSV EXPORT ====================

  Future<String> exportAllArtikelAsJson() async {
    final artikelList = await _loadArtikel();
    final jsonList = artikelList.map((a) => a.toMap()).toList();
    return _prettyJsonEncoder.convert(jsonList);
  }

  Future<Uint8List> exportAllArtikelAsCsvBytes() async {
    final csvString = await exportAllArtikelAsCsv();
    final bom = Uint8List.fromList([0xEF, 0xBB, 0xBF]);
    final csvBytes = Uint8List.fromList(utf8.encode(csvString));
    return Uint8List.fromList([...bom, ...csvBytes]);
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
      rows.add(
        header
            .map((h) => _sanitizeCsvValue(map[h]?.toString() ?? ''))
            .toList(),
      );
    }

    return const ListToCsvConverter().convert(rows);
  }

  String _sanitizeCsvValue(String v) {
    if (v.startsWith(RegExp(r'[=+\-@]'))) {
      v = "'$v";
    }
    if (v.contains(';') || v.contains('"') || v.contains('\n')) {
      v = '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  /// Lädt Artikel plattformabhängig — gibt immer List<`Artikel`> zurück ✅
  Future<List<Artikel>> _loadArtikel() async {
    if (kIsWeb) {
      final pb = PocketBaseService().client;
      final records =
          await pb.collection('artikel').getFullList(sort: '-created');
      return records
          .map((r) => Artikel.fromMap(_recordToArtikelMap(r)))
          .toList();
    } else {
      return await ArtikelDbService().getAlleArtikel();
    }
  }

  Map<String, dynamic> _recordToArtikelMap(RecordModel record) {
    return {
      ...record.data,
      'id': record.id,
    };
  }

  // ==================== EXPORT DIALOG ====================

  Future<void> showExportDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
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

      Uint8List bytes;
      if (exportType == 'json') {
        final exportData = await exportAllArtikelAsJson();
        if (exportData.isEmpty || exportData == '[]') {
          if (!context.mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text('Keine Artikeldaten vorhanden.')),
          );
          return;
        }
        bytes = Uint8List.fromList(utf8.encode(exportData));
      } else {
        bytes = await exportAllArtikelAsCsvBytes();
        if (bytes.length <= 3) {
          if (!context.mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text('Keine Artikeldaten vorhanden.')),
          );
          return;
        }
      }

      final fileName =
          'artikel_export_${DateTime.now().toIso8601String().replaceAll(':', '-')}.$exportType';

      await AppLogService().log('Export gestartet ($exportType)');

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Exportiere Artikeldaten',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [exportType],
        bytes: bytes,
      );

      if (savedPath != null) {
        await AppLogService().log('Export erfolgreich: $savedPath');
        if (context.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Export erfolgreich: $fileName')),
          );
        }
      }
    } catch (e, stack) {
      await AppLogService().logError('Fehler beim Export: $e', stack);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Export: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==================== ZIP BACKUP ====================

  Future<String?> backupToZipFile(BuildContext context) async {
    if (kIsWeb) {
      return await _backupToZipWeb(context);
    } else {
      return await _backupToZipMobile(context);
    }
  }

  /// Web: ZIP-Backup nur mit JSON-Daten (keine lokalen Bilder)
  Future<String?> _backupToZipWeb(BuildContext context) async {
    final messenger2 = ScaffoldMessenger.of(context);
    await AppLogService().log('ZIP-Backup (Web) gestartet');

    try {
      final jsonString = await exportAllArtikelAsJson();
      if (jsonString == '[]') {
        if (context.mounted) {
          messenger2.showSnackBar(
            const SnackBar(
              content: Text('Keine Artikel für Backup vorhanden'),
            ),
          );
        }
        return null;
      }

      final archive = Archive();
      archive.addFile(ArchiveFile(
        'artikel_backup.json',
        jsonString.length,
        utf8.encode(jsonString),
      ),);

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
        await AppLogService().log('ZIP-Backup (Web) gespeichert: $filename');
        if (context.mounted) {
          messenger2.showSnackBar(
            const SnackBar(
              content: Text('ZIP-Backup erfolgreich gespeichert'),
            ),
          );
        }
      }

      return result;
    } catch (e, stack) {
      await AppLogService().logError('ZIP-Backup (Web) Fehler: $e', stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.red,
          ),
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
            const SnackBar(
              content: Text('Keine Artikel für Backup vorhanden'),
            ),
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
      ),);

      // Bilder hinzufügen (nur Mobile)
      for (final artikel in artikelList) {
        if (artikel.bildPfad.isNotEmpty) {
          try {
            final imageBytes =
                await platform.readFileBytesIfExists(artikel.bildPfad);
            if (imageBytes != null) {
              final fileName =
                  'images/${artikel.id}_${_slug(artikel.name)}.jpg';
              archive.addFile(
                ArchiveFile(fileName, imageBytes.length, imageBytes),
              );
            }
          } catch (e, stack) {
            await AppLogService().logError(
              'Fehler beim Lesen des Bildes für Artikel '
              '${artikel.id} (${artikel.name}): $e',
              stack,
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Fehler beim Lesen eines Bildes: $e'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        }
      }

      final zipData = ZipEncoder().encode(archive);
      final filename = _buildBackupFilename();

      try {
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
              const SnackBar(
                content: Text('ZIP-Backup erfolgreich gespeichert'),
              ),
            );
          }
        }
        return result;
      } catch (e, stack) {
        await AppLogService().logError(
          'Fehler beim Speichern der ZIP-Backup-Datei: $e',
          stack,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Speichern des ZIP-Backups: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }
    } catch (e, stack) {
      await AppLogService()
          .logError('Fehler während des ZIP-Backup-Prozesses: $e', stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler während des ZIP-Backup-Prozesses: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  // ==================== NEXTCLOUD BACKUP ====================

  /// ZIP-Backup zu Nextcloud hochladen (nur Mobile)
  Future<void> backupZipToNextcloud(
    String zipFilePath, {
    BuildContext? context,
  }) async {
    if (kIsWeb) return;
    try {
      await nextcloud.uploadZipToNextcloud(zipFilePath, context: context);
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ZIP-Backup erfolgreich zu Nextcloud hochgeladen'),
          ),
        );
      }
    } catch (e, stack) {
      await AppLogService().logError(
        'Fehler beim Hochladen des ZIP-Backups zu Nextcloud: $e',
        stack,
      );
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Hochladen zu Nextcloud: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Vollständiges Backup mit Bildern zu Nextcloud (nur Mobile)
  Future<void> backupWithImagesToNextcloud(BuildContext context) async {
    if (kIsWeb) return;
    try {
      await nextcloud.backupWithImagesToNextcloud(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Backup mit Bildern erfolgreich zu Nextcloud hochgeladen',
            ),
          ),
        );
      }
    } catch (e, stack) {
      await AppLogService().logError(
        'Fehler beim Hochladen des Backups mit Bildern zu Nextcloud: $e',
        stack,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Hochladen zu Nextcloud: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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