// lib/screens/list_screen_mobile_actions.dart

import 'package:flutter/material.dart';

import '../models/artikel_model.dart';
import '../services/app_log_service.dart';
import '../services/artikel_db_service.dart';
import '../services/artikel_export_service.dart';
import '../services/artikel_import_service.dart';
import '../services/pdf_service.dart';

// ---------------------------------------------------------------------------
// PDF-Export: Alle Artikel
// ---------------------------------------------------------------------------

/// Generiert eine PDF-Datei mit allen Artikeln und zeigt das Ergebnis an.
Future<void> generateArtikelListePdf(
  BuildContext context,
  List<Artikel> artikelListe,
) async {
  // messenger VOR erstem await holen — context nach await evtl. ungültig
  final messenger = ScaffoldMessenger.of(context);

  try {
    await AppLogService().log('PDF-Export gestartet: Komplette Artikelliste');
    final alleArtikel = await ArtikelDbService().getAlleArtikel();

    if (alleArtikel.isEmpty) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Keine Artikel für PDF-Export vorhanden.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final pdfFile = await PdfService().generateArtikelListePdf(alleArtikel);

    if (pdfFile != null && context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('PDF erstellt!\nPfad: ${pdfFile.path}'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Öffnen',
            onPressed: () async {
              // Erste Snackbar sofort schließen bevor neue erscheint
              messenger.hideCurrentSnackBar();
              final success = await PdfService.openPdf(pdfFile.path);
              if (!success && context.mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('PDF konnte nicht geöffnet werden'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3), // ← Fix: kein ewiges Hängen
                  ),
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
      messenger.showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// PDF-Export: Gefilterte Artikel
// ---------------------------------------------------------------------------

/// Generiert eine PDF-Datei mit gefilterten Artikeln.
Future<void> generateFilteredArtikelListePdf(
  BuildContext context,
  List<Artikel> gefilterteArtikel,
) async {
  final messenger = ScaffoldMessenger.of(context);

  try {
    if (gefilterteArtikel.isEmpty) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Keine gefilterten Artikel vorhanden.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final pdfFile =
        await PdfService().generateArtikelListePdf(gefilterteArtikel);

    if (pdfFile != null && context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('PDF erstellt! (${gefilterteArtikel.length} Artikel)'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Öffnen',
            onPressed: () async {
              // Erste Snackbar sofort schließen bevor neue erscheint
              messenger.hideCurrentSnackBar();
              final success = await PdfService.openPdf(pdfFile.path);
              if (!success && context.mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('PDF konnte nicht geöffnet werden'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3), // ← Fix: kein ewiges Hängen
                  ),
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
      messenger.showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// ZIP-Backup Dialog
// ---------------------------------------------------------------------------

/// Zeigt den ZIP-Backup Dialog an.
Future<void> showZipBackupDialog(
  BuildContext context,
  Future<void> Function() reloadArtikel,
) async {
  await showDialog<void>(
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
                  const SnackBar(
                    content: Text('ZIP-Backup lokal gespeichert'),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Row(
              children: [
                Icon(Icons.archive, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(child: Text('ZIP-Backup lokal exportieren')),
              ],
            ),
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
                    content: Text('ZIP-Backup zu Nextcloud exportiert'),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Row(
              children: [
                Icon(Icons.cloud_upload, color: Colors.green),
                SizedBox(width: 8),
                Expanded(child: Text('ZIP-Backup zu Nextcloud exportieren')),
              ],
            ),
          ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              final (success, errors) =
                  await ArtikelImportService.importBackupFromZipService(
                reloadArtikel: reloadArtikel,
              );
              if (!context.mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('ZIP-Backup erfolgreich importiert!'),
                    duration: Duration(seconds: 3),
                  ),
                );
              } else {
                await showDialog<void>(
                  context: context,
                  builder: (ctx2) => AlertDialog(
                    title: const Text('Fehler beim ZIP-Import'),
                    content: SingleChildScrollView(
                      child: Text(errors.join('\n')),
                    ),
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
            child: const Row(
              children: [
                Icon(Icons.archive, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(child: Text('ZIP-Backup lokal importieren')),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              await ArtikelImportService.importZipBackupAuto(
                context,
                reloadArtikel,
              );
            },
            child: const Row(
              children: [
                Icon(Icons.cloud_download, color: Colors.purple),
                SizedBox(width: 8),
                Expanded(child: Text('ZIP-Backup von Nextcloud importieren')),
              ],
            ),
          ),
        ],
      );
    },
  );
}

// ---------------------------------------------------------------------------
// PDF-Export: Artikel-Detail
// ---------------------------------------------------------------------------

/// Zeigt einen Artikel-Auswahl-Dialog und generiert ein Detail-PDF.
Future<void> generateArtikelDetailPdf(
  BuildContext context,
  List<Artikel> artikelListe,
) async {
  if (artikelListe.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Keine Artikel vorhanden.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
    return;
  }

  final selected = await showDialog<Artikel>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Artikel für Detail-PDF wählen'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: artikelListe.length,
          itemBuilder: (_, i) {
            final a = artikelListe[i];
            return ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(a.name),
              subtitle: Text('${a.ort} • ${a.fach} • Menge: ${a.menge}'),
              onTap: () => Navigator.pop(ctx, a),
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

  if (selected == null || !context.mounted) return;

  // messenger NACH dem Dialog-await holen — context ist hier noch gültig
  final messenger = ScaffoldMessenger.of(context);

  try {
    await AppLogService().log(
      'PDF-Export gestartet: Artikel-Detail "${selected.name}"',
    );

    final pdfFile = await PdfService().generateArtikelDetailPdf(selected);

    if (pdfFile != null && context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Detail-PDF erstellt!\nPfad: ${pdfFile.path}'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Öffnen',
            onPressed: () async {
              // Erste Snackbar sofort schließen bevor neue erscheint
              messenger.hideCurrentSnackBar();
              final success = await PdfService.openPdf(pdfFile.path);
              if (!success && context.mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('PDF konnte nicht geöffnet werden'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3), // ← Fix: kein ewiges Hängen
                  ),
                );
              }
            },
          ),
        ),
      );
    }
  } catch (e, stack) {
    await AppLogService().logError('Detail-PDF Fehler: $e', stack);
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}