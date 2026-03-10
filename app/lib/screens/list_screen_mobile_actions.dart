// lib/screens/list_screen_mobile_actions.dart
//
// Mobile/Desktop-spezifische Aktionen für den ArtikelListScreen.
// Enthält PDF-Generierung und ZIP-Backup – beides nur auf Mobile/Desktop.

import 'dart:io';
import 'package:flutter/material.dart';
import '../services/pdf_service.dart';
import '../services/app_log_service.dart';
import '../services/artikel_db_service.dart';
import '../services/artikel_export_service.dart';
import '../services/artikel_import_service.dart';
import '../models/artikel_model.dart';

/// Generiert eine PDF-Datei mit allen Artikeln und zeigt das Ergebnis an.
Future<void> generateArtikelListePdf(
  BuildContext context,
  List<Artikel> artikelListe,
) async {
  try {
    await AppLogService().log('PDF-Export gestartet: Komplette Artikelliste');
    final pdfService = PdfService();
    final alleArtikel = await ArtikelDbService().getAlleArtikel();

    if (alleArtikel.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine Artikel für PDF-Export vorhanden.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final pdfFile = await pdfService.generateArtikelListePdf(alleArtikel);

    if (pdfFile != null && context.mounted) {
      await AppLogService().log('PDF erstellt: ${pdfFile.path}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF erstellt!\nPfad: ${pdfFile.path}'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Öffnen',
            onPressed: () async {
              final success = await PdfService.openPdf(pdfFile.path);
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF konnte nicht geöffnet werden')),
                );
              }
            },
          ),
        ),
      );
    }
  } catch (e, stack) {
    await AppLogService().logError('PDF-Export Fehler: $e', stack);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

/// Generiert eine PDF-Datei mit gefilterten Artikeln.
Future<void> generateFilteredArtikelListePdf(
  BuildContext context,
  List<Artikel> gefilterteArtikel,
) async {
  try {
    if (gefilterteArtikel.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine gefilterten Artikel vorhanden.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final pdfFile =
        await PdfService().generateArtikelListePdf(gefilterteArtikel);

    if (pdfFile != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF erstellt! (${gefilterteArtikel.length} Artikel)'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Öffnen',
            onPressed: () async {
              await PdfService.openPdf(pdfFile.path);
            },
          ),
        ),
      );
    }
  } catch (e, stack) {
    await AppLogService().logError('PDF-Export Fehler: $e', stack);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

/// Zeigt den ZIP-Backup Dialog an.
Future<void> showZipBackupDialog(
  BuildContext context,
  Future<void> Function() reloadArtikel,
) async {
  await showDialog(
    context: context,
    builder: (ctx) {
      return SimpleDialog(
        title: const Text('ZIP-Backup Export/Import'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              final zipPath =
                  await ArtikelExportService().backupToZipFile(context);
              if (zipPath != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ZIP-Backup lokal gespeichert')),
                );
              }
            },
            child: const Row(children: [
              Icon(Icons.archive, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(child: Text('ZIP-Backup lokal exportieren')),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              final zipPath =
                  await ArtikelExportService().backupToZipFile(context);
              if (zipPath != null) {
                await ArtikelExportService().backupZipToNextcloud(zipPath);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('ZIP-Backup zu Nextcloud exportiert')),
                );
              }
            },
            child: const Row(children: [
              Icon(Icons.cloud_upload, color: Colors.green),
              SizedBox(width: 8),
              Expanded(child: Text('ZIP-Backup zu Nextcloud exportieren')),
            ]),
          ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              final (success, errors) =
                  await ArtikelImportService.importBackupFromZipService(
                      reloadArtikel: reloadArtikel);
              if (!context.mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('ZIP-Backup erfolgreich importiert!')),
                );
              } else {
                showDialog(
                  context: context,
                  builder: (ctx2) => AlertDialog(
                    title: const Text('Fehler beim ZIP-Import'),
                    content: SingleChildScrollView(
                        child: Text(errors.join('\n'))),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx2),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
            child: const Row(children: [
              Icon(Icons.archive, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text('ZIP-Backup lokal importieren')),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              await ArtikelImportService.importZipBackupAuto(
                  context, reloadArtikel);
            },
            child: const Row(children: [
              Icon(Icons.cloud_download, color: Colors.purple),
              SizedBox(width: 8),
              Expanded(child: Text('ZIP-Backup von Nextcloud importieren')),
            ]),
          ),
        ],
      );
    },
  );
}
