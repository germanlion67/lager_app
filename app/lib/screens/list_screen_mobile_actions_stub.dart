// lib/screens/list_screen_mobile_actions_stub.dart

import 'package:flutter/material.dart';

import '../models/artikel_model.dart';

Future<void> generateArtikelListePdf(
  BuildContext context,
  List<Artikel> artikelListe,
) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('PDF-Export ist im Web nicht verfügbar.'),
      backgroundColor: Colors.orange,
      duration: Duration(seconds: 3),
    ),
  );
}

Future<void> generateFilteredArtikelListePdf(
  BuildContext context,
  List<Artikel> gefilterteArtikel,
) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('PDF-Export ist im Web nicht verfügbar.'),
      backgroundColor: Colors.orange,
      duration: Duration(seconds: 3),
    ),
  );
}

Future<void> generateArtikelDetailPdf(
  BuildContext context,
  Artikel artikel,
) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('PDF-Export ist im Web nicht verfügbar.'),
      backgroundColor: Colors.orange,
      duration: Duration(seconds: 3),
    ),
  );
}

Future<void> showZipBackupDialog(
  BuildContext context,
  Future<void> Function() reloadArtikel,
) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('ZIP-Backup ist im Web nicht verfügbar.'),
      backgroundColor: Colors.orange,
      duration: Duration(seconds: 3),
    ),
  );
}