// lib/models/artikel_model.dart

import 'dart:convert';
import '../utils/uuid_generator.dart';
import 'package:logger/logger.dart';

// ✅ Sentinel für nullable copyWith-Felder
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

  static final Logger _logger = Logger();

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
        updatedAt = updatedAt ?? DateTime.now().toUtc().millisecondsSinceEpoch;
  // FIX #8: ↑ UTC-Normalisierung auch im Konstruktor

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
      // FIX #8: UTC-normalisierte ISO-Strings für konsistenten Sync
      'erstelltAm': erstelltAm.toUtc().toIso8601String(),
      'aktualisiertAm': aktualisiertAm.toUtc().toIso8601String(),
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

  /// PocketBase-Format: nur echte PB-Schema-Felder.
  /// remote_path und etag werden mitgeschickt damit PocketBase
  /// nach einem Bild-Upload den Datei-Pfad und ETag korrekt speichert.
  /// etag ist hier die PocketBase Record-ID (Surrogate-ETag) —
  /// sie identifiziert eindeutig den Stand des Remote-Records
  /// und wird für Konflikt-Erkennung beim Sync genutzt.
  Map<String, dynamic> toPocketBaseMap() {
    return {
      'name': name,
      'menge': menge,
      'ort': ort,
      'fach': fach,
      'beschreibung': beschreibung,
      'uuid': uuid,
      'deleted': deleted,
      'device_id': deviceId,
      // FIX: remote_path ergänzt — PocketBase speichert den Bild-Pfad
      // im Record. Ohne dieses Feld bleibt nach einem Upload der alte
      // Pfad im Record stehen.
      'remote_path': remotePath,
      // FIX: etag ergänzt — wird als Surrogate-ETag genutzt
      // (PocketBase Record-ID). Ermöglicht Konflikt-Erkennung
      // beim bidirektionalen Sync ohne separaten Versions-Counter.
      'etag': etag,
    };
  }

  /// SQLite → Artikel.
  ///
  /// Key-Konventionen:
  /// - SQLite speichert Felder in snake_case (z.B. remote_path, device_id).
  /// - PocketBase liefert Felder in camelCase (z.B. remotePath, deviceId).
  /// - Fallbacks (??) stellen sicher dass fromMap() für beide Quellen
  ///   funktioniert ohne separate fromSQLite()- und fromPocketBase()-Pfade.
  /// - Felder ohne Fallback (z.B. etag, uuid) existieren in beiden
  ///   Quellen unter demselben Key.
  factory Artikel.fromMap(Map<String, dynamic> map) {
    final parsedId = map['id'] is int
        ? map['id'] as int
        : int.tryParse(map['id']?.toString() ?? '');
    final parsedMenge = map['menge'] is int
        ? map['menge'] as int
        : int.tryParse(map['menge']?.toString() ?? '0') ?? 0;

    final erstelltAmValue = map['erstelltAm'] ?? map['created'];
    final aktualisiertAmValue = map['aktualisiertAm'] ?? map['updated'];

    return Artikel(
      id: parsedId,
      name: map['name']?.toString() ?? '',
      menge: parsedMenge,
      ort: map['ort']?.toString() ?? '',
      fach: map['fach']?.toString() ?? '',
      beschreibung: map['beschreibung']?.toString() ?? '',
      bildPfad: map['bildPfad']?.toString() ?? '',
      thumbnailPfad: map['thumbnailPfad']?.toString(),
      thumbnailEtag: map['thumbnailEtag']?.toString(),
      // FIX #8: _parseDateTime() gibt jetzt immer UTC zurück
      erstelltAm: _parseDateTime(erstelltAmValue),
      aktualisiertAm: _parseDateTime(aktualisiertAmValue),
      remoteBildPfad: map['remoteBildPfad']?.toString(),
      uuid: map['uuid']?.toString() ?? UuidGenerator.generate(),
      // snake_case (SQLite) mit camelCase-Fallback (PocketBase)
      updatedAt: _parseInt(map['updated_at'] ?? map['updatedAt']),
      deleted: map['deleted'] == 1 || map['deleted'] == true,
      // etag: gleicher Key in SQLite und PocketBase → kein Fallback nötig
      etag: map['etag']?.toString(),
      // snake_case (SQLite) mit camelCase-Fallback (PocketBase)
      remotePath: map['remote_path']?.toString()
          ?? map['remotePath']?.toString(),
      // snake_case (SQLite) mit camelCase-Fallback (PocketBase)
      deviceId: map['device_id']?.toString()
          ?? map['deviceId']?.toString(),
    );
  }

  /// PocketBase Record → Artikel.
  factory Artikel.fromPocketBase(
    Map<String, dynamic> data,
    String recordId, {
    String? created,
    String? updated,
  }) {
    final parsedMenge = data['menge'] is int
        ? data['menge'] as int
        : int.tryParse(data['menge']?.toString() ?? '0') ?? 0;

    final erstelltAmValue = created ?? data['created'];
    final aktualisiertAmValue = updated ?? data['updated'];

    final String? pbBildPfad = data['bild']?.toString();
    final String? pbRemoteBildPfad =
        pbBildPfad != null && pbBildPfad.isNotEmpty ? pbBildPfad : null;

    return Artikel(
      id: null,
      name: data['name']?.toString() ?? '',
      menge: parsedMenge,
      ort: data['ort']?.toString() ?? '',
      fach: data['fach']?.toString() ?? '',
      beschreibung: data['beschreibung']?.toString() ?? '',
      bildPfad: '',
      // FIX #8: _parseDateTime() gibt jetzt immer UTC zurück
      erstelltAm: _parseDateTime(erstelltAmValue),
      aktualisiertAm: _parseDateTime(aktualisiertAmValue),
      remoteBildPfad: pbRemoteBildPfad,
      uuid: data['uuid']?.toString() ?? UuidGenerator.generate(),
      updatedAt: aktualisiertAmValue != null
          ? _parseDateTimeToMillis(aktualisiertAmValue)
          : DateTime.now().toUtc().millisecondsSinceEpoch,
      // FIX #8: ↑ UTC-Normalisierung im Fallback
      deleted: data['deleted'] == true,
      // etag = PocketBase Record-ID als Surrogate-ETag.
      // Identifiziert eindeutig den Stand des Remote-Records.
      // Wird für Konflikt-Erkennung beim bidirektionalen Sync genutzt.
      etag: recordId,
      // remotePath = PocketBase Record-ID als Referenz auf den Remote-Record.
      // Wird genutzt um den lokalen Artikel mit dem PB-Record zu verknüpfen.
      remotePath: recordId,
      deviceId: data['deviceId']?.toString(),
    );
  }

  // ==================== HELPER ====================

  // FIX #8: _parseDateTime() normalisiert immer auf UTC
  // → verhindert Zeitzonenprobleme beim Sync zwischen Geräten
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) {
      _logger.w(
        '⚠️ _parseDateTime: Null-Wert erhalten, verwende aktuelles UTC-Datum.',
      );
      return DateTime.now().toUtc();
    }
    if (value is DateTime) return value.toUtc(); // FIX #8: .toUtc()
    try {
      return DateTime.parse(value.toString()).toUtc(); // FIX #8: .toUtc()
    } catch (e, stack) {
      _logger.e(
        '❌ _parseDateTime: Ungültiger Wert "$value" konnte nicht geparst '
        'werden. Verwende aktuelles UTC-Datum.',
        error: e,
        stackTrace: stack,
      );
      return DateTime.now().toUtc(); // FIX #8: .toUtc()
    }
  }

  // FIX #8: _parseDateTimeToMillis() normalisiert auf UTC vor Konvertierung
  static int _parseDateTimeToMillis(dynamic value) {
    if (value == null) return DateTime.now().toUtc().millisecondsSinceEpoch;
    if (value is DateTime) return value.toUtc().millisecondsSinceEpoch;
    try {
      // FIX #8: .toUtc() vor .millisecondsSinceEpoch
      return DateTime.parse(value.toString())
          .toUtc()
          .millisecondsSinceEpoch;
    } catch (e, stack) {
      _logger.e(
        '❌ _parseDateTimeToMillis: Ungültiger Wert "$value". '
        'Verwende aktuellen UTC-Timestamp.',
        error: e,
        stackTrace: stack,
      );
      return DateTime.now().toUtc().millisecondsSinceEpoch;
    }
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    final parsed = int.tryParse(value.toString());
    if (parsed == null) {
      _logger.w(
        '⚠️ _parseInt: Ungültiger Wert "$value" konnte nicht zu int '
        'geparst werden. Verwende 0.',
      );
    }
    return parsed ?? 0;
  }

  // ==================== COPY WITH ====================

  Artikel copyWith({
    Object? id = _undefined,
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
    Object? updatedAt = _undefined,
    bool? deleted,
    Object? etag = _undefined,
    Object? remotePath = _undefined,
    Object? deviceId = _undefined,
  }) {
    return Artikel(
      id: id is _Undefined ? this.id : id as int?,
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
      updatedAt: updatedAt is _Undefined
          ? this.updatedAt
          : updatedAt as int?,
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