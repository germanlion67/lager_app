// lib/models/attachment_model.dart
//
// M-012: Datenmodell für Dokumentenanhänge pro Artikel.
// Anhänge werden in PocketBase Collection "attachments" gespeichert.
// Funktioniert auf Web, Mobile und Desktop identisch.

/// Erlaubte MIME-Typen für Anhänge.
/// Wird sowohl für Client-seitige Validierung als auch
/// für den PocketBase-Collection-Filter verwendet.
const Set<String> kErlaubteMimeTypes = {
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'image/jpeg',
  'image/png',
  'image/webp',
  'text/plain',
  'text/csv',
};

/// Maximale Dateigröße pro Anhang: 10 MB.
const int kMaxAttachmentBytes = 10 * 1024 * 1024;

/// Maximale Anzahl Anhänge pro Artikel.
const int kMaxAttachmentsPerArtikel = 20;

class AttachmentModel {
  /// PocketBase Record-ID (leer bei neu erstellten, noch nicht gespeicherten Anhängen).
  final String id;

  /// UUID des zugehörigen Artikels.
  final String artikelUuid;

  /// Dateiname wie er in PocketBase gespeichert ist (z.B. "rechnung_abc123.pdf").
  /// Wird von PocketBase beim Upload automatisch vergeben/normalisiert.
  final String dateiName;

  /// Vom Nutzer vergebene Bezeichnung (z.B. "Lieferschein März 2024").
  final String bezeichnung;

  /// Optionale Beschreibung.
  final String? beschreibung;

  /// MIME-Typ der Datei (z.B. "application/pdf").
  final String? mimeType;

  /// Dateigröße in Bytes.
  final int? dateiGroesse;

  /// Sortierreihenfolge (aufsteigend).
  final int sortOrder;

  /// Erstellungszeitpunkt (aus PocketBase `created`-Feld).
  final DateTime? erstelltAm;

  /// Vollständige Download-URL (wird vom Service befüllt, nicht in PB gespeichert).
  final String? downloadUrl;

  const AttachmentModel({
    required this.id,
    required this.artikelUuid,
    required this.dateiName,
    required this.bezeichnung,
    this.beschreibung,
    this.mimeType,
    this.dateiGroesse,
    this.sortOrder = 0,
    this.erstelltAm,
    this.downloadUrl,
  });

  /// Erstellt ein AttachmentModel aus einem PocketBase Record.
  ///
  /// [data] — `record.data` aus PocketBase
  /// [recordId] — `record.id`
  /// [downloadUrl] — vollständige URL zur Datei (via `pb.files.getUrl()`)
  factory AttachmentModel.fromPocketBase(
    Map<String, dynamic> data,
    String recordId, {
    String? downloadUrl,
    String? created,
  }) {
    return AttachmentModel(
      id: recordId,
      artikelUuid: data['artikel_uuid']?.toString() ?? '',
      dateiName: data['datei']?.toString() ?? '',
      bezeichnung: data['bezeichnung']?.toString() ?? '',
      beschreibung: data['beschreibung']?.toString(),
      mimeType: data['mime_type']?.toString(),
      dateiGroesse: _parseInt(data['datei_groesse']),
      sortOrder: _parseInt(data['sort_order']) ?? 0,
      erstelltAm: _parseDateTime(created ?? data['created']),
      downloadUrl: downloadUrl,
    );
  }

  /// Gibt eine lesbare Dateigröße zurück (z.B. "2,4 MB").
  String get dateiGroesseFormatiert {
    final bytes = dateiGroesse;
    if (bytes == null || bytes == 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Gibt das Label passend zum MIME-Typ zurück.
  String get typLabel {
    final mime = mimeType ?? '';
    if (mime.startsWith('image/')) {
      return 'Bild';
    }
    if (mime == 'application/pdf') {
      return 'PDF';
    }
    if (mime.contains('word') || mime.contains('odt')) {
      return 'Dokument';
    }
    if (mime.contains('excel') || mime.contains('sheet') ||
        mime == 'text/csv') {
      return 'Tabelle';
    }
    if (mime == 'text/plain') {
      return 'Text';
    }
    return 'Datei';
  }

  /// Gibt zurück ob dieser Anhang ein Bild ist.
  bool get istBild => mimeType?.startsWith('image/') ?? false;

  AttachmentModel copyWith({
    String? id,
    String? artikelUuid,
    String? dateiName,
    String? bezeichnung,
    String? beschreibung,
    String? mimeType,
    int? dateiGroesse,
    int? sortOrder,
    DateTime? erstelltAm,
    String? downloadUrl,
  }) {
    return AttachmentModel(
      id: id ?? this.id,
      artikelUuid: artikelUuid ?? this.artikelUuid,
      dateiName: dateiName ?? this.dateiName,
      bezeichnung: bezeichnung ?? this.bezeichnung,
      beschreibung: beschreibung ?? this.beschreibung,
      mimeType: mimeType ?? this.mimeType,
      dateiGroesse: dateiGroesse ?? this.dateiGroesse,
      sortOrder: sortOrder ?? this.sortOrder,
      erstelltAm: erstelltAm ?? this.erstelltAm,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    try {
      return DateTime.parse(value.toString()).toUtc();
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() =>
      'AttachmentModel(id: $id, bezeichnung: $bezeichnung, '
      'dateiName: $dateiName, mimeType: $mimeType)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttachmentModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}