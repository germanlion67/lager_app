// lib/widgets/attachment_upload_widget.dart
//
// M-012: Upload-Dialog für Dokumentenanhänge.
// Plattformunabhängig — nutzt file_picker für Web, Mobile und Desktop.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
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
        setState(
            () => _validierungsFehler = 'Datei konnte nicht gelesen werden.',);
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
      setState(
          () => _validierungsFehler = 'Datei konnte nicht gelesen werden.',);
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final limitErreicht =
        widget.aktuelleAnzahl >= kMaxAttachmentsPerArtikel;

    return Padding(
      padding: EdgeInsets.only(
        left: AppConfig.spacingLarge,
        right: AppConfig.spacingLarge,
        top: AppConfig.spacingLarge,
        bottom:
            MediaQuery.of(context).viewInsets.bottom + AppConfig.spacingLarge,
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
                Icon(Icons.upload_file, color: colorScheme.onSurface),
                const SizedBox(width: AppConfig.spacingSmall),
                Text(
                  'Anhang hinzufügen',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.aktuelleAnzahl}/$kMaxAttachmentsPerArtikel',
                  style: textTheme.bodySmall?.copyWith(
                    color: limitErreicht
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConfig.spacingLarge),

            // Limit-Warnung
            if (limitErreicht)
              Container(
                padding: const EdgeInsets.all(AppConfig.spacingMedium),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius:
                      BorderRadius.circular(AppConfig.borderRadiusMedium),
                  border: Border.all(
                    color: colorScheme.error
                        .withValues(alpha: AppConfig.opacityMedium),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: colorScheme.onErrorContainer,
                      size: AppConfig.iconSizeMedium,
                    ),
                    const SizedBox(width: AppConfig.spacingSmall),
                    Expanded(
                      child: Text(
                        'Maximale Anzahl von $kMaxAttachmentsPerArtikel '
                        'Anhängen erreicht.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
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
                const SizedBox(height: AppConfig.spacingXSmall),
                Text(
                  _formatBytes(gewaehlteDatei!.size),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],

              // Validierungsfehler
              if (_validierungsFehler != null) ...[
                const SizedBox(height: AppConfig.spacingSmall),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConfig.spacingMedium,
                    vertical: AppConfig.spacingSmall,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(
                      AppConfig.cardBorderRadiusSmall,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.error,
                        size: AppConfig.iconSizeSmall,
                      ),
                      const SizedBox(width: AppConfig.spacingSmall),
                      Expanded(
                        child: Text(
                          _validierungsFehler!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppConfig.spacingLarge),

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
              const SizedBox(height: AppConfig.spacingMedium),

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
              const SizedBox(height: AppConfig.spacingLarge),

              // Aktions-Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _uploading ? null : () => Navigator.pop(context),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: AppConfig.spacingSmall),
                  FilledButton.icon(
                    onPressed: (_uploading || gewaehlteDatei == null)
                        ? null
                        : _hochladen,
                    icon: _uploading
                        ? const SizedBox(
                            width: AppConfig.iconSizeSmall,
                            height: AppConfig.iconSizeSmall,
                            child: CircularProgressIndicator(
                              strokeWidth: AppConfig.strokeWidthMedium,
                            ),
                          )
                        : const Icon(Icons.upload),
                    label: Text(
                        _uploading ? 'Wird hochgeladen…' : 'Hochladen',),
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