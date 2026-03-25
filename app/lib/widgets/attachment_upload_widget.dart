// lib/widgets/attachment_upload_widget.dart
//
// M-012: Upload-Dialog für Dokumentenanhänge.
// Plattformunabhängig — nutzt file_picker für Web, Mobile und Desktop.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/attachment_model.dart';
import '../services/app_log_service.dart';
import '../services/attachment_service.dart';
import '../utils/attachment_utils.dart';

class AttachmentUploadWidget extends StatefulWidget {
  final String artikelUuid;
  final int aktuelleAnzahl;

  /// Callback nach erfolgreichem Upload.
  final void Function(AttachmentModel neuerAnhang)? onUploaded;

  const AttachmentUploadWidget({
    super.key,
    required this.artikelUuid,
    required this.aktuelleAnzahl,
    this.onUploaded,
  });

  @override
  State<AttachmentUploadWidget> createState() =>
      _AttachmentUploadWidgetState();
}

class _AttachmentUploadWidgetState extends State<AttachmentUploadWidget> {
  final _service = AttachmentService();
  final _logger = AppLogService.logger;
  final _formKey = GlobalKey<FormState>();
  final _bezeichnungCtrl = TextEditingController();
  final _beschreibungCtrl = TextEditingController();

  PlatformFile? gewaehlteDatei;
  bool _uploading = false;
  String? _validierungsFehler;

  @override
  void dispose() {
    _bezeichnungCtrl.dispose();
    _beschreibungCtrl.dispose();
    super.dispose();
  }

  Future<void> dateiWaehlen() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'doc', 'docx', 'odt',
          'xls', 'xlsx', 'csv', 'txt',
          'jpg', 'jpeg', 'png', 'webp',
        ],
        withData: true, // Bytes direkt laden (wichtig für Web)
      );

      if (result == null || result.files.isEmpty) return;

      final datei = result.files.first;

      // Vorvalidierung
      final bytes = datei.bytes;
      if (bytes == null) {
        setState(() => _validierungsFehler = 'Datei konnte nicht gelesen werden.');
        return;
      }

      final mimeType = mimeTypeFromExtension(datei.name);
      final validation = validateAttachment(
        bytes: bytes,
        dateiName: datei.name,
        mimeType: mimeType,
        aktuelleAnzahl: widget.aktuelleAnzahl,
      );

      if (!validation.isValid) {
        setState(() => _validierungsFehler = validation.fehler);
        return;
      }

      // Bezeichnung vorbelegen mit Dateiname (ohne Erweiterung)
      if (_bezeichnungCtrl.text.isEmpty) {
        final nameOhneExt = datei.name.contains('.')
            ? datei.name.substring(0, datei.name.lastIndexOf('.'))
            : datei.name;
        _bezeichnungCtrl.text = nameOhneExt;
      }

      setState(() {
        gewaehlteDatei = datei;
        _validierungsFehler = null;
      });
    } catch (e, st) {
      _logger.e(
        'AttachmentUpload: Dateiauswahl fehlgeschlagen',
        error: e,
        stackTrace: st,
      );
      setState(() => _validierungsFehler = 'Fehler bei der Dateiauswahl: $e');
    }
  }

  Future<void> _hochladen() async {
    if (!_formKey.currentState!.validate()) return;
    if (gewaehlteDatei == null) {
      setState(() => _validierungsFehler = 'Bitte zuerst eine Datei wählen.');
      return;
    }

    final bytes = gewaehlteDatei!.bytes;
    if (bytes == null) {
      setState(() => _validierungsFehler = 'Datei konnte nicht gelesen werden.');
      return;
    }

    setState(() => _uploading = true);

    try {
      final mimeType = mimeTypeFromExtension(gewaehlteDatei!.name);

      final neuerAnhang = await _service.upload(
        artikelUuid: widget.artikelUuid,
        bytes: bytes,
        dateiName: gewaehlteDatei!.name,
        bezeichnung: _bezeichnungCtrl.text.trim(),
        beschreibung: _beschreibungCtrl.text.trim().isEmpty
            ? null
            : _beschreibungCtrl.text.trim(),
        mimeType: mimeType,
      );

      if (!mounted) return;

      if (neuerAnhang != null) {
        _logger.i(
          'AttachmentUpload: Erfolgreich hochgeladen — '
          '${neuerAnhang.bezeichnung}',
        );
        widget.onUploaded?.call(neuerAnhang);
        Navigator.pop(context, neuerAnhang);
      } else {
        setState(() {
          _uploading = false;
          _validierungsFehler =
              'Upload fehlgeschlagen. Bitte erneut versuchen.';
        });
      }
    } catch (e, st) {
      _logger.e(
        'AttachmentUpload: Upload fehlgeschlagen',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        setState(() {
          _uploading = false;
          _validierungsFehler = 'Fehler beim Upload: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final limitErreicht =
        widget.aktuelleAnzahl >= kMaxAttachmentsPerArtikel;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.upload_file),
                const SizedBox(width: 8),
                const Text(
                  'Anhang hinzufügen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.aktuelleAnzahl}/$kMaxAttachmentsPerArtikel',
                  style: TextStyle(
                    color: limitErreicht ? Colors.red : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Limit-Warnung
            if (limitErreicht)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Maximale Anzahl von $kMaxAttachmentsPerArtikel '
                        'Anhängen erreicht.',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Datei wählen
              OutlinedButton.icon(
                onPressed: _uploading ? null : dateiWaehlen,
                icon: const Icon(Icons.attach_file),
                label: Text(
                  gewaehlteDatei == null
                      ? 'Datei wählen'
                      : gewaehlteDatei!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Datei-Info
              if (gewaehlteDatei != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatBytes(gewaehlteDatei!.size),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],

              // Validierungsfehler
              if (_validierungsFehler != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 18,),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _validierungsFehler!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13,),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Bezeichnung
              TextFormField(
                controller: _bezeichnungCtrl,
                enabled: !_uploading,
                decoration: const InputDecoration(
                  labelText: 'Bezeichnung *',
                  hintText: 'z.B. Lieferschein März 2024',
                  border: OutlineInputBorder(),
                ),
                maxLength: 100,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 12),

              // Beschreibung
              TextFormField(
                controller: _beschreibungCtrl,
                enabled: !_uploading,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 500,
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Aktions-Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _uploading
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: (_uploading || gewaehlteDatei == null)
                        ? null
                        : _hochladen,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.upload),
                    label: Text(_uploading ? 'Wird hochgeladen…' : 'Hochladen'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}