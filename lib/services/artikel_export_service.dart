//lib/services/artikel_export_service.dart

//Exportiert alle Artikel als JSON-Array (Backup).
//Exportiert alle Artikel als CSV-Datei (Backup).
//Nutzt die Felder deiner Artikel-Klasse, inkl. aller Datenbankattribute.

import 'dart:convert';
import 'package:csv/csv.dart';
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
}
