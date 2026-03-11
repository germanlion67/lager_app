// lib/models/artikel_model.dart
//
// Datenmodell für Artikel (Elektronikbauteile).
// Kompatibel mit SQLite (lokal) UND PocketBase (remote).
//
// Änderungen gegenüber Vorversion:
// - UUID-Generierung → UuidGenerator (kryptografisch sicher)
// - toPocketBaseMap() → exakt passend zum echten PB-Schema (camelCase)
// - fromPocketBase() → liest PB-Felder korrekt (camelCase, bool, kein .json)
// - fromMap()        → unterstützt snake_case (SQLite) UND camelCase (PocketBase)
// - isValid()        → prüft jetzt auch menge >= 0

import 'dart:convert';
import '../utils/uuid_generator.dart';

class Artikel {
  final int? id; // SQLite Auto-Increment ID (nur lokal, nie zu PB senden)
  final String name;
  final int menge;
  final String ort;
  final String fach;
  final String beschreibung;
  final String bildPfad; // Lokaler Bildpfad (nur Mobile/Desktop)
  final String? thumbnailPfad;
  final String? thumbnailEtag;
  final DateTime erstelltAm;
  final DateTime aktualisiertAm;
  final String? remoteBildPfad; // PocketBase Dateiname (aus 'bild'-Feld)

  // Sync-Felder
  final String uuid; // Eindeutiger Schlüssel über alle Geräte
  final int updatedAt; // Milliseconds seit Epoch (UTC) für Sync-Erkennung
  final bool deleted; // Soft-Delete Flag
  final String? etag; // PocketBase Record-ID für Konflikterkennung
  final String? remotePath; // PocketBase Record-ID (z.B. "abc123def456xyz")
  final String? deviceId; // Gerät, das zuletzt geändert hat

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
    String? uuid,
    int? updatedAt,
    this.deleted = false,
    this.etag,
    this.remotePath,
    this.deviceId,
  })  : uuid = uuid ?? UuidGenerator.generate(),
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  // ==================== SERIALISIERUNG ====================

  /// Konvertierung in Map für SQLite.
  /// Enthält lokale Felder (id, bildPfad, thumbnail etc.).
  /// Feldnamen: snake_case (SQLite-Konvention).
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
      'uuid': uuid,
      'updated_at': updatedAt, // SQLite: snake_case
      'deleted': deleted ? 1 : 0, // SQLite: bool als int
      'etag': etag,
      'remote_path': remotePath, // SQLite: snake_case
      'device_id': deviceId, // SQLite: snake_case
    };
  }

  /// Konvertierung in Map für PocketBase API.
  ///
  /// ⚠️  Wichtige Regeln:
  /// - Feldnamen: camelCase (exakt wie im PB-Schema definiert)
  /// - KEINE lokale SQLite-id senden
  /// - KEINE lokalen Pfade senden (bildPfad, thumbnailPfad etc.)
  /// - KEIN 'bild' hier → separater Multipart-Upload nötig!
  /// - KEIN 'created'/'updated' → PocketBase setzt diese automatisch
  Map<String, dynamic> toPocketBaseMap() {
    return {
      'name': name,
      'menge': menge,
      'ort': ort,
      'fach': fach,
      'beschreibung': beschreibung,
      'uuid': uuid,
      'updatedAt': updatedAt, // ✅ PB-Schema: camelCase
      'deleted': deleted, // ✅ PB-Schema: bool direkt (nicht 0/1)
      'etag': etag,
      'remotePath': remotePath, // ✅ PB-Schema: camelCase
      'deviceId': deviceId, // ✅ PB-Schema: camelCase
      // 'bild'          → separater Multipart-Upload!
      // 'created'       → PocketBase autodate, nicht senden
      // 'updated'       → PocketBase autodate, nicht senden
      // 'id'            → nur bei Update als URL-Parameter, nie im Body
    };
  }

  /// Konstruktor aus Map.
  ///
  /// Unterstützt BEIDE Quellen:
  /// - SQLite: snake_case Feldnamen (updated_at, remote_path, device_id)
  /// - PocketBase: camelCase Feldnamen (updatedAt, remotePath, deviceId)
  ///
  /// Bei Konflikten gilt: snake_case hat Vorrang (SQLite ist primäre Quelle
  /// für fromMap; für PocketBase-Records → fromPocketBase() verwenden).
  factory Artikel.fromMap(Map<String, dynamic> map) {
    return Artikel(
      // SQLite liefert int, PocketBase liefert String oder null für 'id'
      id: map['id'] is int ? map['id'] as int : null,
      name: map['name']?.toString() ?? '',
      menge: map['menge'] is int
          ? map['menge'] as int
          : int.tryParse(map['menge']?.toString() ?? '0') ?? 0,
      ort: map['ort']?.toString() ?? '',
      fach: map['fach']?.toString() ?? '',
      beschreibung: map['beschreibung']?.toString() ?? '',
      bildPfad: map['bildPfad']?.toString() ?? '',
      thumbnailPfad: map['thumbnailPfad']?.toString(),
      thumbnailEtag: map['thumbnailEtag']?.toString(),
      erstelltAm: _parseDateTime(map['erstelltAm'] ?? map['created']),
      aktualisiertAm: _parseDateTime(map['aktualisiertAm'] ?? map['updated']),
      remoteBildPfad: map['remoteBildPfad']?.toString(),
      uuid: map['uuid']?.toString() ?? UuidGenerator.generate(),

      // ✅ snake_case (SQLite) hat Vorrang, camelCase (PB) als Fallback
      updatedAt: _parseInt(map['updated_at'] ?? map['updatedAt']),

      // ✅ SQLite: int (0/1) | PocketBase: bool → beide Formate abfangen
      deleted: map['deleted'] == 1 || map['deleted'] == true,

      etag: map['etag']?.toString(),

      // ✅ snake_case (SQLite) hat Vorrang, camelCase (PB) als Fallback
      remotePath:
          map['remote_path']?.toString() ?? map['remotePath']?.toString(),
      deviceId: map['device_id']?.toString() ?? map['deviceId']?.toString(),
    );
  }

  /// Konstruktor speziell für PocketBase Records.
  ///
  /// Mappt PocketBase-spezifische Felder korrekt:
  /// - camelCase Feldnamen (updatedAt, remotePath, deviceId)
  /// - 'bild' → remoteBildPfad
  /// - 'created'/'updated' → erstelltAm/aktualisiertAm
  /// - recordId → etag UND remotePath (nur die ID, kein '.json'!)
  factory Artikel.fromPocketBase(Map<String, dynamic> data, String recordId) {
    return Artikel(
      id: null, // PocketBase hat keine int-IDs
      name: data['name']?.toString() ?? '',
      menge: data['menge'] is int
          ? data['menge'] as int
          : int.tryParse(data['menge']?.toString() ?? '0') ?? 0,
      ort: data['ort']?.toString() ?? '',
      fach: data['fach']?.toString() ?? '',
      beschreibung: data['beschreibung']?.toString() ?? '',
      bildPfad: '', // Kein lokaler Pfad bei PB-Records
      erstelltAm: _parseDateTime(data['created']), // ✅ PB autodate-Feld
      aktualisiertAm: _parseDateTime(data['updated']), // ✅ PB autodate-Feld
      remoteBildPfad: data['bild']?.toString(), // ✅ PB file-Feld heißt 'bild'
      uuid: data['uuid']?.toString() ?? UuidGenerator.generate(),

      // ✅ PB liefert camelCase
      updatedAt: _parseInt(data['updatedAt']),

      // ✅ PB liefert bool direkt
      deleted: data['deleted'] == true,

      etag: data['etag']?.toString() ?? recordId,

      // ✅ Nur die Record-ID – kein '.json' Suffix!
      remotePath: recordId,

      // ✅ PB liefert camelCase
      deviceId: data['deviceId']?.toString(),
    );
  }

  // ==================== HELPER ====================

  /// Parst verschiedene DateTime-Formate sicher.
  /// Unterstützt: ISO 8601, PocketBase-Format, DateTime-Objekte.
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Parst int-Werte sicher aus verschiedenen Typen.
  /// Unterstützt: int, String, null.
  static int _parseInt(dynamic value) {
    if (value == null) return DateTime.now().millisecondsSinceEpoch;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ??
        DateTime.now().millisecondsSinceEpoch;
  }

  // ==================== COPY WITH ====================

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

  // ==================== JSON ====================

  /// JSON-Serialisierung (für Export/Backup).
  /// Verwendet toMap() → snake_case Format.
  String toJson() => json.encode(toMap());

  factory Artikel.fromJson(String source) =>
      Artikel.fromMap(json.decode(source) as Map<String, dynamic>);

  // ==================== VALIDIERUNG ====================

  /// Prüft ob alle Pflichtfelder korrekt ausgefüllt sind.
  bool isValid() {
    return name.trim().isNotEmpty &&
        ort.trim().isNotEmpty &&
        fach.trim().isNotEmpty &&
        menge >= 0; // ✅ Negative Mengen sind kein gültiger Lagerbestand
  }

  // ==================== OBJECT OVERRIDES ====================

  @override
  String toString() {
    return 'Artikel(uuid: $uuid, name: $name, menge: $menge, '
        'ort: $ort, fach: $fach, deleted: $deleted)';
  }

  /// Gleichheit basiert auf UUID – eindeutig über alle Geräte.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Artikel && other.uuid == uuid;
  }

  @override
  int get hashCode => uuid.hashCode;
}