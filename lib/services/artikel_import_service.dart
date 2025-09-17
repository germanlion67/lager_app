//lib/services/artikel_import_service.dart

//Importiert Artikel aus JSON- und CSV-String (z.B. aus Datei-Inhalt).
//Prüft Gültigkeit der Artikel vor Einfügen.
//Überspringt fehlerhafte Einträge.
//Fügt alle Artikel in die Datenbank ein.


import 'dart:convert';
import 'package:csv/csv.dart';
import '../models/artikel_model.dart';
import 'artikel_db_service.dart';

class ArtikelImportService {
  /// Importiert Artikel aus einer JSON-Datei (String-Inhalt).
  /// Erwartet ein Array von Artikel-Objekten im JSON.
  Future<List<Artikel>> importFromJson(String jsonString) async {
    final List<dynamic> jsonList = json.decode(jsonString);
    final artikelList = <Artikel>[];

    for (final item in jsonList) {
      try {
        artikelList.add(Artikel.fromMap(item as Map<String, dynamic>));
      } catch (e) {
        // Fehlerhafte Einträge überspringen
        continue;
      }
    }
    return artikelList;
  }

  /// Importiert Artikel aus einer CSV-Datei (String-Inhalt).
  /// Erwartet Header: name,menge,ort,fach,beschreibung,bildPfad,erstelltAm,aktualisiertAm,remoteBildPfad
  Future<List<Artikel>> importFromCsv(String csvString) async {
    final rows = const CsvToListConverter(eol: '\n').convert(csvString, eol: '\n');
    if (rows.isEmpty) return [];

    // Header verarbeiten
    final header = rows.first.map((e) => e.toString()).toList();
    final artikelList = <Artikel>[];

    for (final row in rows.skip(1)) {
      if (row.length < header.length) continue;
      final map = <String, dynamic>{};
      for (var i = 0; i < header.length; i++) {
        map[header[i]] = row[i];
      }
      try {
        artikelList.add(Artikel.fromMap(map));
      } catch (e) {
        continue;
      }
    }
    return artikelList;
  }

  /// Fügt eine Liste von Artikeln in die Datenbank ein.
  Future<void> insertArtikelList(List<Artikel> artikelList) async {
    final db = ArtikelDbService();
    for (var artikel in artikelList) {
      // Validierung: Nur gültige Artikel importieren
      if (artikel.isValid()) {
        await db.insertArtikel(artikel);
      }
    }
  }
}
