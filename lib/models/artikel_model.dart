  //Diese Klasse bildet die Grundlage für die Datenstruktur deiner Artikel
  // und ist kompatibel mit SQLite.

  import 'dart:convert';
  import 'dart:math';

class Artikel {
  final int? id;
  final String name;
  final int menge;
  final String ort;
  final String fach;
  final String beschreibung;
  final String bildPfad;
  final String? thumbnailPfad;
  final String? thumbnailEtag;
  final DateTime erstelltAm;
  final DateTime aktualisiertAm;
  final String? remoteBildPfad;
  
  // Neue Felder für Sync
  final String uuid; // UUID für eindeutige Identifikation
  final int updatedAt; // Milliseconds seit Epoch (UTC)
  final bool deleted; // Soft Delete Flag
  final String? etag; // ETag vom Server für Konflikterkennung
  final String? remotePath; // Pfad auf dem Nextcloud Server
  final String? deviceId; // ID des Geräts, das zuletzt geändert hat 

  Artikel({
    this.id,
    required this.name,
    required this.menge,
    required this.ort,
    required this.fach,
    required this.beschreibung,
    required this.bildPfad,
    this.thumbnailPfad,
    this.thumbnailEtag,
    required this.erstelltAm,
    required this.aktualisiertAm,
    this.remoteBildPfad,
    // Neue Sync-Parameter
    String? uuid,
    int? updatedAt,
    this.deleted = false,
    this.etag,
    this.remotePath,
    this.deviceId,
  }) : uuid = uuid ?? _generateUUID(),
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  // Generiert eine UUID für neue Artikel
  static String _generateUUID() {
    return '${_randomHex(8)}-${_randomHex(4)}-${_randomHex(4)}-${_randomHex(4)}-${_randomHex(12)}';
  }

  static String _randomHex(int length) {
    final random = Random();
    const chars = '0123456789abcdef';
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(16)))
    );
  }

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
    'thumbnailPfad': thumbnailPfad,
    'thumbnailEtag': thumbnailEtag,
      'erstelltAm': erstelltAm.toIso8601String(),
      'aktualisiertAm': aktualisiertAm.toIso8601String(),
      'remoteBildPfad': remoteBildPfad,
      // Neue Sync-Felder
      'uuid': uuid,
      'updated_at': updatedAt,
      'deleted': deleted ? 1 : 0,
      'etag': etag,
      'remote_path': remotePath,
      'device_id': deviceId,
    };
  }

  // Konstruktor aus Map
  factory Artikel.fromMap(Map<String, dynamic> map) {
    return Artikel(
      id: map['id'] ?? 0,
      name: map['name'] ?? '',
      menge: map['menge'] is int
          ? map['menge'] as int
          : int.tryParse(map['menge'].toString()) ?? 0,
      ort: map['ort'] ?? '',
      fach: map['fach'] ?? '',
      beschreibung: map['beschreibung'] ?? '',
    bildPfad: map['bildPfad'] ?? '',
    thumbnailPfad: map['thumbnailPfad'],
    thumbnailEtag: map['thumbnailEtag'],
      erstelltAm: map['erstelltAm'] != null
          ? DateTime.parse(map['erstelltAm'])
          : DateTime.now(),
      aktualisiertAm: map['aktualisiertAm'] != null
          ? DateTime.parse(map['aktualisiertAm'])
          : DateTime.now(),
      remoteBildPfad: map['remoteBildPfad'],
      // Neue Sync-Felder
      uuid: map['uuid'] ?? _generateUUID(),
      updatedAt: map['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
      deleted: (map['deleted'] ?? 0) == 1,
      etag: map['etag'],
      remotePath: map['remote_path'],
      deviceId: map['device_id'],
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
    String? thumbnailPfad,
    String? thumbnailEtag,
    DateTime? erstelltAm,
    DateTime? aktualisiertAm,
    String? remoteBildPfad,
    String? uuid,
    int? updatedAt,
    bool? deleted,
    String? etag,
    String? remotePath,
    String? deviceId,
  }) {
    return Artikel(
      id: id ?? this.id,
      name: name ?? this.name,
      menge: menge ?? this.menge,
      ort: ort ?? this.ort,
      fach: fach ?? this.fach,
      beschreibung: beschreibung ?? this.beschreibung,
      bildPfad: bildPfad ?? this.bildPfad,
      thumbnailPfad: thumbnailPfad ?? this.thumbnailPfad,
      thumbnailEtag: thumbnailEtag ?? this.thumbnailEtag,
      erstelltAm: erstelltAm ?? this.erstelltAm,
      aktualisiertAm: aktualisiertAm ?? this.aktualisiertAm,
      remoteBildPfad: remoteBildPfad ?? this.remoteBildPfad,
      uuid: uuid ?? this.uuid,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      etag: etag ?? this.etag,
      remotePath: remotePath ?? this.remotePath,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  // JSON Serialisierung für Nextcloud Sync
  String toJson() => json.encode(toMap());
  
  factory Artikel.fromJson(String source) => Artikel.fromMap(json.decode(source));

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
