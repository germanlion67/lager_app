// lib/services/attachment_service.dart
//
// M-012: PocketBase-Service für Dokumentenanhänge.
// Kapselt alle CRUD-Operationen gegen die "attachments" Collection.
// Plattformunabhaengig — funktioniert auf Web, Mobile und Desktop.

import 'package:http/http.dart' as http;

import '../models/attachment_model.dart';
import '../services/app_log_service.dart';
import '../services/pocketbase_service.dart';

class AttachmentService {
  static const String _collection = 'attachments';

  static final _logger = AppLogService.logger;

  // Singleton
  static final AttachmentService _instance = AttachmentService._();
  factory AttachmentService() => _instance;
  AttachmentService._();

  // ---------------------------------------------------------------------------
  // READ
  // ---------------------------------------------------------------------------

  /// Laedt alle Anhaenge fuer einen Artikel (nach sort_order, dann created).
  ///
  /// [artikelUuid] — UUID des Artikels
  /// Gibt eine leere Liste zurueck bei Fehler (kein rethrow — UI zeigt
  /// Leerstand statt Crash).
  Future<List<AttachmentModel>> getForArtikel(String artikelUuid) async {
    try {
      final pb = PocketBaseService().client;

      final result = await pb.collection(_collection).getList(
        filter: 'artikel_uuid = "$artikelUuid"',
        sort: 'sort_order,created',
        perPage: kMaxAttachmentsPerArtikel,
      );

      return result.items.map((record) {
        final dateiName = record.data['datei']?.toString() ?? '';
        final downloadUrl = dateiName.isNotEmpty
            ? pb.files.getUrl(record, dateiName).toString()
            : null;

        return AttachmentModel.fromPocketBase(
          record.data,
          record.id,
          downloadUrl: downloadUrl,
          // FIX: .created deprecated → get<String>('created')
          created: record.get<String>('created'),
        );
      }).toList();
    } catch (e, st) {
      _logger.e(
        'AttachmentService.getForArtikel() fehlgeschlagen '
        '(artikelUuid: $artikelUuid)',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// Gibt die Anzahl der Anhaenge fuer einen Artikel zurueck.
  /// Schneller als getForArtikel() — nur ein COUNT-Query.
  Future<int> countForArtikel(String artikelUuid) async {
    try {
      final pb = PocketBaseService().client;
      final result = await pb.collection(_collection).getList(
        filter: 'artikel_uuid = "$artikelUuid"',
        perPage: 1,
        page: 1,
      );
      return result.totalItems;
    } catch (e, st) {
      _logger.e(
        'AttachmentService.countForArtikel() fehlgeschlagen',
        error: e,
        stackTrace: st,
      );
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // CREATE
  // ---------------------------------------------------------------------------

  /// Laedt eine Datei als Anhang hoch.
  ///
  /// [artikelUuid] — UUID des Artikels
  /// [bytes] — Dateiinhalt
  /// [dateiName] — Originaldateiname (z.B. "rechnung.pdf")
  /// [bezeichnung] — Vom Nutzer vergebener Name
  /// [beschreibung] — Optionale Beschreibung
  /// [mimeType] — MIME-Typ (z.B. "application/pdf")
  ///
  /// Gibt das erstellte AttachmentModel zurueck, oder null bei Fehler.
  Future<AttachmentModel?> upload({
    required String artikelUuid,
    required List<int> bytes,
    required String dateiName,
    required String bezeichnung,
    String? beschreibung,
    String? mimeType,
  }) async {
    try {
      final pb = PocketBaseService().client;

      // Anzahl pruefen bevor Upload
      final count = await countForArtikel(artikelUuid);
      if (count >= kMaxAttachmentsPerArtikel) {
        _logger.w(
          'AttachmentService.upload(): Limit erreicht '
          '($kMaxAttachmentsPerArtikel Anhaenge) fuer Artikel $artikelUuid',
        );
        return null;
      }

      final body = <String, dynamic>{
        'artikel_uuid': artikelUuid,
        'bezeichnung': bezeichnung.trim(),
        if (beschreibung != null && beschreibung.trim().isNotEmpty)
          'beschreibung': beschreibung.trim(),
        if (mimeType != null) 'mime_type': mimeType,
        'datei_groesse': bytes.length,
        'sort_order': count,
      };

      final file = http.MultipartFile.fromBytes(
        'datei',
        bytes,
        filename: dateiName,
      );

      final record = await pb.collection(_collection).create(
        body: body,
        files: [file],
      );

      final gespeicherterDateiName = record.data['datei']?.toString() ?? '';
      final downloadUrl = gespeicherterDateiName.isNotEmpty
          ? pb.files.getUrl(record, gespeicherterDateiName).toString()
          : null;

      _logger.i(
        'AttachmentService.upload(): Anhang hochgeladen — '
        '$bezeichnung ($dateiName, ${bytes.length} bytes)',
      );

      return AttachmentModel.fromPocketBase(
        record.data,
        record.id,
        downloadUrl: downloadUrl,
        // FIX: .created deprecated → get<String>('created')
        created: record.get<String>('created'),
      );
    } catch (e, st) {
      _logger.e(
        'AttachmentService.upload() fehlgeschlagen '
        '(artikelUuid: $artikelUuid, datei: $dateiName)',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // UPDATE
  // ---------------------------------------------------------------------------

  /// Aktualisiert Bezeichnung und/oder Beschreibung eines Anhangs.
  ///
  /// Gibt true zurueck bei Erfolg.
  Future<bool> updateMetadata({
    required String attachmentId,
    required String bezeichnung,
    String? beschreibung,
  }) async {
    try {
      final pb = PocketBaseService().client;

      await pb.collection(_collection).update(
        attachmentId,
        body: {
          'bezeichnung': bezeichnung.trim(),
          'beschreibung': beschreibung?.trim() ?? '',
        },
      );

      _logger.i(
        'AttachmentService.updateMetadata(): '
        'Anhang $attachmentId aktualisiert',
      );
      return true;
    } catch (e, st) {
      _logger.e(
        'AttachmentService.updateMetadata() fehlgeschlagen '
        '(id: $attachmentId)',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  /// Loescht einen einzelnen Anhang.
  ///
  /// PocketBase loescht die Datei automatisch mit dem Record.
  /// Gibt true zurueck bei Erfolg.
  Future<bool> delete(String attachmentId) async {
    try {
      final pb = PocketBaseService().client;
      await pb.collection(_collection).delete(attachmentId);

      _logger.i(
        'AttachmentService.delete(): Anhang $attachmentId geloescht',
      );
      return true;
    } catch (e, st) {
      _logger.e(
        'AttachmentService.delete() fehlgeschlagen (id: $attachmentId)',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Loescht alle Anhaenge eines Artikels.
  ///
  /// Wird aufgerufen wenn ein Artikel geloescht wird.
  /// Gibt die Anzahl erfolgreich geloeschter Anhaenge zurueck.
  Future<int> deleteAllForArtikel(String artikelUuid) async {
    try {
      // FIX: anhaenge statt anhänge (illegal_character 228)
      final anhaenge = await getForArtikel(artikelUuid);
      var deleted = 0;

      for (final anhang in anhaenge) {
        final success = await delete(anhang.id);
        if (success) deleted++;
      }

      _logger.i(
        'AttachmentService.deleteAllForArtikel(): '
        '$deleted/${anhaenge.length} Anhaenge geloescht '
        '(artikelUuid: $artikelUuid)',
      );
      return deleted;
    } catch (e, st) {
      _logger.e(
        'AttachmentService.deleteAllForArtikel() fehlgeschlagen '
        '(artikelUuid: $artikelUuid)',
        error: e,
        stackTrace: st,
      );
      return 0;
    }
  }
}