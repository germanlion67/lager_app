// lib/models/artikel_model.dart
//
// Datenmodell für Artikel (Elektronikbauteile).
// Kompatibel mit SQLite (lokal) UND PocketBase (remote).

import 'dart:convert';
import 'dart:math';

class Artikel {
  final int? id; // SQLite Auto-Increment ID (lokal)
  final String name;
  final int menge;
  final String ort;
  final String fach;
  final String beschreibung;
  final String bildPfad; // Lokaler Bildpfad (Mobile/Desktop)
  final String? thumbnailPfad;
  final String? thumbnailEtag;
  final DateTime erstelltAm;
  final DateTime aktualisiertAm;
  final String? remoteBildPfad; // PocketBase Bild-URL oder Dateiname

  // Sync-Felder
  final String uuid; // UUID für eindeutige Identifikation über alle Geräte
  final int updatedAt; // Milliseconds seit Epoch (UTC) für Sync-Erkennung
  final bool deleted; // Soft Delete Flag
  final String? etag; // PocketBase Record-ID oder Update-Timestamp für Konflikterkennung
  final String? remotePath; // PocketBase Record-ID (z.B. "abc123def456789")
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
    String? uuid,
    int? updatedAt,
    this.deleted = false,
    this.etag,
    this.remotePath,
    this.deviceId,
  })  : uuid = uuid ?? _generateUUID(),
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  // ==================== UUID ====================

  static String _generateUUID() {
    return '${_randomHex(8)}-${_randomHex(4)}-${_randomHex(4)}-${_randomHex(4)}-${_randomHex(12)}';
  }

  static String _randomHex(int length) {
    final random = Random();
    const chars = '0123456789abcdef';
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(16))),
    );
  }

  // ==================== SERIALISIERUNG ====================

  /// Konvertierung in Map für SQLite (enthält lokale `id`).
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
      'updated_at': updatedAt,
      'deleted': deleted ? 1 : 0,
      'etag': etag,
      'remote_path': remotePath,
      'device_id': deviceId,
    };
  }

  /// Konvertierung in Map für PocketBase API.
  /// Enthält KEINE lokale SQLite-`id` und keine lokalen Pfade.
  /// SQLite-spezifische Felder (thumbnailPfad etc.) werden nicht gesendet.
  Map<String, dynamic> toPocketBaseMap() {
    return {
      'name': name,
      'menge': menge,
      'ort': ort,
      'fach': fach,
      'beschreibung': beschreibung,
      'erstelltAm': erstelltAm.toIso8601String(),
      'aktualisiertAm': aktualisiertAm.toIso8601String(),
      'uuid': uuid,
      'updated_at': updatedAt,
      'deleted': deleted,
      'device_id': deviceId,
    };
  }

  /// Konstruktor aus Map – kompatibel mit SQLite UND PocketBase.
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
      // PocketBase verwendet 'created'/'updated', SQLite 'erstelltAm'/'aktualisiertAm'
      erstelltAm: _parseDateTime(map['erstelltAm'] ?? map['created']),
      aktualisiertAm: _parseDateTime(map['aktualisiertAm'] ?? map['updated']),
      remoteBildPfad: map['remoteBildPfad']?.toString(),
      // Sync-Felder
      uuid: map['uuid']?.toString() ?? _generateUUID(),
      updatedAt: map['updated_at'] is int
          ? map['updated_at'] as int
          : int.tryParse(map['updated_at']?.toString() ?? '') ??
              DateTime.now().millisecondsSinceEpoch,
      // SQLite speichert bool als int (0/1), PocketBase als bool
      deleted: map['deleted'] == 1 || map['deleted'] == true,
      etag: map['etag']?.toString(),
      remotePath: map['remote_path']?.toString(),
      deviceId: map['device_id']?.toString(),
    );
  }

  /// Konstruktor speziell für PocketBase Records.
  /// Mappt PocketBase-spezifische Felder korrekt.
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
      bildPfad: '', // Lokal nicht vorhanden bei PB-Records
      erstelltAm: _parseDateTime(data['erstelltAm'] ?? data['created']),
      aktualisiertAm: _parseDateTime(data['aktualisiertAm'] ?? data['updated']),
      remoteBildPfad: data['remoteBildPfad']?.toString(),
      uuid: data['uuid']?.toString() ?? _generateUUID(),
      updatedAt: data['updated_at'] is int
          ? data['updated_at'] as int
          : int.tryParse(data['updated_at']?.toString() ?? '') ??
              DateTime.now().millisecondsSinceEpoch,
      deleted: data['deleted'] == 1 || data['deleted'] == true,
      etag: recordId, // PocketBase Record-ID als ETag
      remotePath: '$recordId.json',
      deviceId: data['device_id']?.toString(),
    );
  }

  // ==================== HELPER ====================

  /// Parst verschiedene DateTime-Formate (ISO 8601, PocketBase-Format).
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
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

  /// JSON Serialisierung (für Export/Backup).
  String toJson() => json.encode(toMap());

  factory Artikel.fromJson(String source) =>
      Artikel.fromMap(json.decode(source));

  // ==================== VALIDIERUNG ====================

  /// Prüft ob die Pflichtfelder ausgefüllt sind.
  bool isValid() {
    return name.trim().isNotEmpty &&
        ort.trim().isNotEmpty &&
        fach.trim().isNotEmpty;
  }

  @override
  String toString() {
    return 'Artikel(uuid: $uuid, name: $name, menge: $menge, ort: $ort, fach: $fach)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Artikel && other.uuid == uuid;
  }

  @override
  int get hashCode => uuid.hashCode;
}
