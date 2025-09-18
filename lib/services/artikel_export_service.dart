//lib/services/artikel_export_service.dart

//Exportiert alle Artikel als JSON-Array (Backup).
//Exportiert alle Artikel als CSV-Datei (Backup).
//Nutzt die Felder deiner Artikel-Klasse, inkl. aller Datenbankattribute.

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../services/app_log_service.dart';
import 'artikel_db_service.dart';

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
}
