//..lib/models/artikel_model.dart

//Diese Klasse bildet die Grundlage für die Datenstruktur deiner Artikel
// und ist kompatibel mit SQLite.

// lib/models/artikel_model.dart

class Artikel {
  final int? id;
  final String name;
  final int menge;
  final String ort;
  final String fach;
  final String beschreibung;
  final String bildPfad;
  final DateTime erstelltAm;
  final DateTime aktualisiertAm;
  final String? remoteBildPfad; 

  Artikel({
    this.id,
    required this.name,
    required this.menge,
    required this.ort,
    required this.fach,
    required this.beschreibung,
    required this.bildPfad,
    required this.erstelltAm,
    required this.aktualisiertAm,
    this.remoteBildPfad,
  });

  // Konvertierung in Map für SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'menge': menge,
      'ort': ort,
      'fach': fach,
      'beschreibung': beschreibung,
      'bildPfad': bildPfad,
      'erstelltAm': erstelltAm.toIso8601String(),
      'aktualisiertAm': aktualisiertAm.toIso8601String(),
      'remoteBildPfad': remoteBildPfad,
    };
  }

  // Konstruktor aus Map
  factory Artikel.fromMap(Map<String, dynamic> map) {
    return Artikel(
      id: map['id'],
      name: map['name'] ?? '',
      menge: map['menge'] ?? 0,
      ort: map['ort'] ?? '',
      fach: map['fach'] ?? '',
      beschreibung: map['beschreibung'] ?? '',
      bildPfad: map['bildPfad'] ?? '',
      erstelltAm: map['erstelltAm'] != null
          ? DateTime.parse(map['erstelltAm'])
          : DateTime.now(),
      aktualisiertAm: map['aktualisiertAm'] != null
          ? DateTime.parse(map['aktualisiertAm'])
          : DateTime.now(),
      remoteBildPfad: map['remoteBildPfad'],
    );
  }

  // Neue Methode: copyWith
  Artikel copyWith({
    int? id,
    String? name,
    int? menge,
    String? ort,
    String? fach,
    String? beschreibung,
    String? bildPfad,
    DateTime? erstelltAm,
    DateTime? aktualisiertAm,
    String? remoteBildPfad,
  }) {
    return Artikel(
      id: id ?? this.id,
      name: name ?? this.name,
      menge: menge ?? this.menge,
      ort: ort ?? this.ort,
      fach: fach ?? this.fach,
      beschreibung: beschreibung ?? this.beschreibung,
      bildPfad: bildPfad ?? this.bildPfad,
      erstelltAm: erstelltAm ?? this.erstelltAm,
      aktualisiertAm: aktualisiertAm ?? this.aktualisiertAm,
      remoteBildPfad: remoteBildPfad ?? this.remoteBildPfad,
    );
  }

  // Validierung: prüft wichtige Felder
  bool isValid() {
    return name.trim().isNotEmpty &&
           ort.trim().isNotEmpty &&
           fach.trim().isNotEmpty;
  }
}

// Die toMap- und fromMap-Methoden ermöglichen die einfache
// Speicherung und Wiederherstellung von Artikeln in einer SQLite-Datenbank.
// Die copyWith-Methode erleichtert das Erstellen modifizierter Kopien von Artikeln,
// und die isValid-Methode stellt sicher, dass wichtige Felder nicht leer sind.
// Diese Struktur bietet eine solide Grundlage für die Verwaltung
// von Elektronikartikeln in deiner App.
