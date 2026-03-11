// lib/models/artikel_model.dart

import 'dart:convert';
import '../utils/uuid_generator.dart';

// ✅ Fix Bug 4: Sentinel für nullable copyWith-Felder
class _Undefined {
  const _Undefined();
}
const _undefined = _Undefined();

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

  // Sync-Felder
  final String uuid;
  final int updatedAt;
  final bool deleted;
  final String? etag;
  final String? remotePath;
  final String? deviceId;

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

  /// SQLite-Format: snake_case, bool als int, id nur wenn vorhanden.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
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
    if (id != null) map['id'] = id;
    return map;
  }

  /// PocketBase-Format: nur echte PB-Schema-Felder, kein updatedAt.
  Map<String, dynamic> toPocketBaseMap() {
    return {
      'name': name,
      'menge': menge,
      'ort': ort,
      'fach': fach,
      'beschreibung': beschreibung,
      'uuid': uuid,
      // ✅ Fix Bug 1: updatedAt entfernt → PocketBase autodate
      'deleted': deleted,
      'deviceId': deviceId,
    };
  }

  /// SQLite → Artikel.
  factory Artikel.fromMap(Map<String, dynamic> map) {
    return Artikel(
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
      updatedAt: _parseInt(map['updated_at'] ?? map['updatedAt']),
      deleted: map['deleted'] == 1 || map['deleted'] == true,
      etag: map['etag']?.toString(),
      remotePath: map['remote_path']?.toString() ?? map['remotePath']?.toString(),
      deviceId: map['device_id']?.toString() ?? map['deviceId']?.toString(),
    );
  }

  /// PocketBase Record → Artikel.
  factory Artikel.fromPocketBase(
    Map<String, dynamic> data,
    String recordId, {
    String? created,
    String? updated,
  }) {
    return Artikel(
      id: null,
      name: data['name']?.toString() ?? '',
      menge: data['menge'] is int
          ? data['menge'] as int
          : int.tryParse(data['menge']?.toString() ?? '0') ?? 0,
      ort: data['ort']?.toString() ?? '',
      fach: data['fach']?.toString() ?? '',
      beschreibung: data['beschreibung']?.toString() ?? '',
      bildPfad: '',
      erstelltAm: _parseDateTime(created ?? data['created']),
      aktualisiertAm: _parseDateTime(updated ?? data['updated']),
      remoteBildPfad: data['bild']?.toString(),
      uuid: data['uuid']?.toString() ?? UuidGenerator.generate(),
      // ✅ Fix Bug 2: 'updated' named param → Millisekunden
      updatedAt: updated != null
          ? _parseDateTimeToMillis(updated)
          : DateTime.now().millisecondsSinceEpoch,
      deleted: data['deleted'] == true,
      etag: recordId, // ✅ recordId als etag → markiert als gesynct
      remotePath: recordId,
      deviceId: data['deviceId']?.toString(),
    );
  }

  // ==================== HELPER ====================

  // ✅ Fix Bug 3: assert im Debug-Mode bei Parse-Fehler
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      assert(false, '⚠️ _parseDateTime: Ungültiger Wert "$value" → $e');
      return DateTime.now();
    }
  }

  // ✅ Fix Bug 2: Neuer Helper – ISO 8601 String → Millisekunden
  static int _parseDateTimeToMillis(String value) {
    try {
      return DateTime.parse(value).millisecondsSinceEpoch;
    } catch (e) {
      assert(false, '⚠️ _parseDateTimeToMillis: Ungültiger Wert "$value" → $e');
      return DateTime.now().millisecondsSinceEpoch;
    }
  }

  static int _parseInt(dynamic value) {
    if (value == null) return DateTime.now().millisecondsSinceEpoch;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ??
        DateTime.now().millisecondsSinceEpoch;
  }

  // ==================== COPY WITH ====================

  // ✅ Fix Bug 4: Sentinel-Pattern für nullable Felder
  Artikel copyWith({
    int? id,
    String? name,
    int? menge,
    String? ort,
    String? fach,
    String? beschreibung,
    String? bildPfad,
    Object? thumbnailPfad = _undefined,
    Object? thumbnailEtag = _undefined,
    DateTime? erstelltAm,
    DateTime? aktualisiertAm,
    Object? remoteBildPfad = _undefined,
    String? uuid,
    int? updatedAt,
    bool? deleted,
    Object? etag = _undefined,
    Object? remotePath = _undefined,
    Object? deviceId = _undefined,
  }) {
    return Artikel(
      id: id ?? this.id,
      name: name ?? this.name,
      menge: menge ?? this.menge,
      ort: ort ?? this.ort,
      fach: fach ?? this.fach,
      beschreibung: beschreibung ?? this.beschreibung,
      bildPfad: bildPfad ?? this.bildPfad,
      thumbnailPfad: thumbnailPfad is _Undefined
          ? this.thumbnailPfad
          : thumbnailPfad as String?,
      thumbnailEtag: thumbnailEtag is _Undefined
          ? this.thumbnailEtag
          : thumbnailEtag as String?,
      erstelltAm: erstelltAm ?? this.erstelltAm,
      aktualisiertAm: aktualisiertAm ?? this.aktualisiertAm,
      remoteBildPfad: remoteBildPfad is _Undefined
          ? this.remoteBildPfad
          : remoteBildPfad as String?,
      uuid: uuid ?? this.uuid,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      etag: etag is _Undefined ? this.etag : etag as String?,
      remotePath: remotePath is _Undefined
          ? this.remotePath
          : remotePath as String?,
      deviceId: deviceId is _Undefined
          ? this.deviceId
          : deviceId as String?,
    );
  }

  // ==================== JSON ====================

  String toJson() => json.encode(toMap());

  factory Artikel.fromJson(String source) =>
      Artikel.fromMap(json.decode(source) as Map<String, dynamic>);

  // ==================== VALIDIERUNG ====================

  bool isValid() {
    return name.trim().isNotEmpty &&
        ort.trim().isNotEmpty &&
        fach.trim().isNotEmpty &&
        menge >= 0;
  }

  // ==================== OBJECT OVERRIDES ====================

  @override
  String toString() {
    return 'Artikel(uuid: $uuid, name: $name, menge: $menge, '
        'ort: $ort, fach: $fach, deleted: $deleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Artikel && other.uuid == uuid;
  }

  @override
  int get hashCode => uuid.hashCode;
}