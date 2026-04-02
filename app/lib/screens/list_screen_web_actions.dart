// lib/screens/list_screen_web_actions.dart
//
// Web-Implementierung der Screen-Actions für die Artikelliste.
//
// Wird per conditional import in artikel_list_screen.dart eingebunden:
//   import 'list_screen_mobile_actions.dart'
//       if (dart.library.html) 'list_screen_web_actions.dart';
//
// PDF-Export: Löst Browser-Download aus (kein lokaler Pfad).
// ZIP-Backup: Nicht verfügbar im Web → Snackbar-Hinweis.

import 'package:flutter/material.dart';

import '../models/artikel_model.dart';
import '../services/artikel_db_service.dart';
import '../services/pdf_service.dart';

// ---------------------------------------------------------------------------
// PDF-Export: Alle Artikel
// ---------------------------------------------------------------------------

/// Generiert eine PDF-Liste mit allen Artikeln und löst Browser-Download aus.
Future<void> generateArtikelListePdf(
  BuildContext context,
  List<Artikel> artikelListe,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final colorScheme = Theme.of(context).colorScheme;

  try {
    final alleArtikel = await ArtikelDbService().getAlleArtikel();

    if (alleArtikel.isEmpty) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Keine Artikel für PDF-Export vorhanden.'),
          backgroundColor: colorScheme.secondary,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Löst Browser-Download aus — gibt null zurück (kein lokaler Pfad)
    await PdfService().generateArtikelListePdf(alleArtikel);

    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('PDF wird heruntergeladen …'),
        duration: Duration(seconds: 3),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Fehler beim PDF-Export: $e'),
        backgroundColor: colorScheme.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PDF-Export: Gefilterte Artikel
// ---------------------------------------------------------------------------

/// Generiert eine PDF mit gefilterten Artikeln und löst Browser-Download aus.
Future<void> generateFilteredArtikelListePdf(
  BuildContext context,
  List<Artikel> gefilterteArtikel,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final colorScheme = Theme.of(context).colorScheme;

  try {
    if (gefilterteArtikel.isEmpty) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Keine gefilterten Artikel vorhanden.'),
          backgroundColor: colorScheme.secondary,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    await PdfService().generateArtikelListePdf(gefilterteArtikel);

    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'PDF wird heruntergeladen … (${gefilterteArtikel.length} Artikel)',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Fehler beim PDF-Export: $e'),
        backgroundColor: colorScheme.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ZIP-Backup Dialog (Web: nicht verfügbar)
// ---------------------------------------------------------------------------

/// ZIP-Backup ist im Web nicht verfügbar — zeigt Snackbar-Hinweis.
Future<void> showZipBackupDialog(
  BuildContext context,
  Future<void> Function() reloadArtikel,
) async {
  if (!context.mounted) return;
  final colorScheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('ZIP-Backup ist im Web nicht verfügbar.'),
      backgroundColor: colorScheme.secondary,
      duration: const Duration(seconds: 3),
    ),
  );
}

// ---------------------------------------------------------------------------
// PDF-Export: Artikel-Detail
// ---------------------------------------------------------------------------

/// Zeigt Artikel-Auswahl-Dialog und löst Browser-Download der Detail-PDF aus.
Future<void> generateArtikelDetailPdf(
  BuildContext context,
  List<Artikel> artikelListe,
) async {
  final colorScheme = Theme.of(context).colorScheme;

  if (artikelListe.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Keine Artikel vorhanden.'),
        backgroundColor: colorScheme.secondary,
        duration: const Duration(seconds: 3),
      ),
    );
    return;
  }

  // Artikel-Auswahl-Dialog
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

  final messenger = ScaffoldMessenger.of(context);

  try {
    await PdfService().generateArtikelDetailPdf(selected);

    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
            'Detail-PDF für "${selected.name}" wird heruntergeladen …',),
        duration: const Duration(seconds: 3),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Fehler beim Detail-PDF: $e'),
        backgroundColor: colorScheme.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}