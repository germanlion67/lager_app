// lib/screens/list_screen_mobile_actions_stub.dart

import 'package:flutter/material.dart';

import '../models/artikel_model.dart';

Future<void> generateArtikelListePdf(
  BuildContext context,
  List<Artikel> artikelListe,
) async =>
    throw UnsupportedError('PDF-Export ist im Web nicht verfügbar');

Future<void> generateFilteredArtikelListePdf(
  BuildContext context,
  List<Artikel> gefilterteArtikel,
) async =>
    throw UnsupportedError('PDF-Export ist im Web nicht verfügbar');

Future<void> showZipBackupDialog(
  BuildContext context,
  Future<void> Function() reloadArtikel,
) async =>
    throw UnsupportedError('ZIP-Backup ist im Web nicht verfügbar');