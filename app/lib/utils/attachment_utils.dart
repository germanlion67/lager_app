// lib/utils/attachment_utils.dart
//
// M-012: Validierung, MIME-Erkennung und Hilfsfunktionen für Anhänge.
// Plattformunabhängig — kein dart:io, kein dart:html.

import 'package:flutter/material.dart';

import '../models/attachment_model.dart';

/// Validierungsergebnis für einen Anhang-Upload.
class AttachmentValidation {
  final bool isValid;
  final String? fehler;

  const AttachmentValidation.ok() : isValid = true, fehler = null;
  const AttachmentValidation.fehler(this.fehler) : isValid = false;
}

/// Prüft ob ein Datei-Upload zulässig ist.
///
/// [bytes] — Dateiinhalt
/// [dateiName] — Originaldateiname
/// [mimeType] — Erkannter MIME-Typ (kann null sein)
/// [aktuelleAnzahl] — Bereits vorhandene Anhänge für diesen Artikel
AttachmentValidation validateAttachment({
  required List<int> bytes,
  required String dateiName,
  String? mimeType,
  required int aktuelleAnzahl,
}) {
  // Limit prüfen
  if (aktuelleAnzahl >= kMaxAttachmentsPerArtikel) {
    return const AttachmentValidation.fehler(
      'Maximale Anzahl von $kMaxAttachmentsPerArtikel Anhängen erreicht.',
    );
  }

  // Größe prüfen
  if (bytes.length > kMaxAttachmentBytes) {
    final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
    final maxMb = (kMaxAttachmentBytes / (1024 * 1024)).toStringAsFixed(0);
    return AttachmentValidation.fehler(
      'Datei zu groß: $mb MB (Maximum: $maxMb MB).',
    );
  }

  // Leer prüfen
  if (bytes.isEmpty) {
    return const AttachmentValidation.fehler('Datei ist leer.');
  }

  // MIME-Typ prüfen (wenn bekannt)
  if (mimeType != null && mimeType.isNotEmpty) {
    if (!kErlaubteMimeTypes.contains(mimeType)) {
      return AttachmentValidation.fehler(
        'Dateityp nicht erlaubt: $mimeType\n'
        'Erlaubt: PDF, Word, Excel, CSV, TXT, JPG, PNG, WebP',
      );
    }
  } else {
    // Fallback: Erweiterung prüfen
    final ext = _getExtension(dateiName);
    if (!_erlaubteErweiterungen.contains(ext)) {
      return AttachmentValidation.fehler(
        'Dateityp nicht erlaubt: .$ext\n'
        'Erlaubt: pdf, doc, docx, xls, xlsx, csv, txt, jpg, jpeg, png, webp',
      );
    }
  }

  return const AttachmentValidation.ok();
}

/// Gibt den MIME-Typ anhand der Dateiendung zurück.
/// Fallback wenn der Plattform-MIME-Typ nicht verfügbar ist.
String? mimeTypeFromExtension(String dateiName) {
  final ext = _getExtension(dateiName);
  return _extensionToMime[ext];
}

/// Gibt das passende Icon für einen MIME-Typ zurück.
IconData iconForMimeType(String? mimeType) {
  if (mimeType == null) return Icons.insert_drive_file;
  if (mimeType.startsWith('image/')) return Icons.image;
  if (mimeType == 'application/pdf') return Icons.picture_as_pdf;
  if (mimeType.contains('word') || mimeType.contains('odt')) {
    return Icons.description;
  }
  if (mimeType.contains('excel') || mimeType.contains('sheet') ||
      mimeType == 'text/csv') {
    return Icons.table_chart;
  }
  if (mimeType == 'text/plain') return Icons.text_snippet;
  return Icons.insert_drive_file;
}

/// Gibt die Farbe passend zum MIME-Typ zurück.
Color colorForMimeType(String? mimeType) {
  if (mimeType == null) return Colors.grey;
  if (mimeType.startsWith('image/')) return Colors.blue;
  if (mimeType == 'application/pdf') return Colors.red;
  if (mimeType.contains('word') || mimeType.contains('odt')) {
    return Colors.indigo;
  }
  if (mimeType.contains('excel') || mimeType.contains('sheet') ||
      mimeType == 'text/csv') {
    return Colors.green;
  }
  if (mimeType == 'text/plain') return Colors.blueGrey;
  return Colors.grey;
}

// ---------------------------------------------------------------------------
// Private Hilfsfunktionen
// ---------------------------------------------------------------------------

String _getExtension(String dateiName) {
  final dot = dateiName.lastIndexOf('.');
  return dot != -1 ? dateiName.substring(dot + 1).toLowerCase() : '';
}

const Set<String> _erlaubteErweiterungen = {
  'pdf', 'doc', 'docx', 'odt',
  'xls', 'xlsx', 'csv', 'txt',
  'jpg', 'jpeg', 'png', 'webp',
};

const Map<String, String> _extensionToMime = {
  'pdf':  'application/pdf',
  'doc':  'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument'
          '.wordprocessingml.document',
  'odt':  'application/vnd.oasis.opendocument.text',
  'xls':  'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument'
          '.spreadsheetml.sheet',
  'csv':  'text/csv',
  'txt':  'text/plain',
  'jpg':  'image/jpeg',
  'jpeg': 'image/jpeg',
  'png':  'image/png',
  'webp': 'image/webp',
};