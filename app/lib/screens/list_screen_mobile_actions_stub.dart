// lib/screens/list_screen_mobile_actions_stub.dart
//
// Stub-Implementierung — wird verwendet wenn weder dart:io noch dart:html
// verfügbar sind (theoretischer Fall, z.B. Tests ohne Plattform-Kontext).
//
// Alle Methoden zeigen einen "nicht verfügbar"-Hinweis.
//
// Hinweis: Colors.orange wird hier bewusst beibehalten, da diese Stub-Datei
// keinen garantierten Widget-Tree-Kontext hat und nur als Fallback dient.

import 'package:flutter/material.dart';

import '../models/artikel_model.dart';

Future<void> generateArtikelListePdf(
  BuildContext context,
  List<Artikel> artikelListe,
) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('PDF-Export ist auf dieser Plattform nicht verfügbar.'),
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
      content: Text('PDF-Export ist auf dieser Plattform nicht verfügbar.'),
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
      content: Text('ZIP-Backup ist auf dieser Plattform nicht verfügbar.'),
      backgroundColor: Colors.orange,
      duration: Duration(seconds: 3),
    ),
  );
}

/// Signatur korrigiert: [artikelListe] ist `List<Artikel>`, nicht Artikel.
/// Konsistent mit list_screen_mobile_actions.dart und list_screen_web_actions.dart.
Future<void> generateArtikelDetailPdf(
  BuildContext context,
  List<Artikel> artikelListe,
) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('PDF-Export ist auf dieser Plattform nicht verfügbar.'),
      backgroundColor: Colors.orange,
      duration: Duration(seconds: 3),
    ),
  );
}