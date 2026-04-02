// lib/widgets/attachment_list_widget.dart
//
// M-012: Liste aller Anhaenge eines Artikels.
// Aktionen: Oeffnen, Bearbeiten (Bezeichnung), Loeschen.
// Plattformunabhaengig — Web, Mobile, Desktop.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/attachment_model.dart';
import '../services/app_log_service.dart';
import '../services/attachment_service.dart';
import '../utils/attachment_utils.dart';

class AttachmentListWidget extends StatefulWidget {
  final String artikelUuid;

  /// Callback wenn ein Anhang geloescht wurde → Parent kann Badge aktualisieren.
  final VoidCallback? onChanged;

  const AttachmentListWidget({
    super.key,
    required this.artikelUuid,
    this.onChanged,
  });

  @override
  State<AttachmentListWidget> createState() => _AttachmentListWidgetState();
}

class _AttachmentListWidgetState extends State<AttachmentListWidget> {
  final _service = AttachmentService();
  final _logger = AppLogService.logger;

  List<AttachmentModel> _anhaenge = [];
  bool _loading = true;
  String? _fehler;

  @override
  void initState() {
    super.initState();
    laden();
  }

  Future<void> laden() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _fehler = null;
    });

    final result = await _service.getForArtikel(widget.artikelUuid);

    if (!mounted) return;
    setState(() {
      _anhaenge = result;
      _loading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Aktionen
  // ---------------------------------------------------------------------------

  Future<void> oeffnen(AttachmentModel anhang) async {
    final url = anhang.downloadUrl;
    if (url == null || url.isEmpty) {
      zeigeFehler('Keine Download-URL verfügbar.');
      return;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _logger.i('AttachmentList: Datei geoeffnet — ${anhang.bezeichnung}');
      } else {
        zeigeFehler('Datei kann nicht geöffnet werden.');
      }
    } catch (e, st) {
      _logger.e(
        'AttachmentList: Fehler beim Oeffnen',
        error: e,
        stackTrace: st,
      );
      zeigeFehler('Fehler beim Öffnen: $e');
    }
  }

  Future<void> loeschen(AttachmentModel anhang) async {
    final colorScheme = Theme.of(context).colorScheme;

    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anhang löschen?'),
        content: Text(
          'Möchtest du "${anhang.bezeichnung}" wirklich löschen?\n'
          'Diese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (bestaetigt != true) return;

    final erfolg = await _service.delete(anhang.id);

    if (!mounted) return;

    if (erfolg) {
      setState(() => _anhaenge.removeWhere((a) => a.id == anhang.id));
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${anhang.bezeichnung}" gelöscht.')),
      );
    } else {
      zeigeFehler('Löschen fehlgeschlagen. Bitte erneut versuchen.');
    }
  }

  Future<void> bearbeiten(AttachmentModel anhang) async {
    final result = await showDialog<_MetadatenResult>(
      context: context,
      builder: (ctx) => _MetadatenDialog(
        bezeichnung: anhang.bezeichnung,
        beschreibung: anhang.beschreibung,
      ),
    );

    if (result == null) return;

    final erfolg = await _service.updateMetadata(
      attachmentId: anhang.id,
      bezeichnung: result.bezeichnung,
      beschreibung: result.beschreibung,
    );

    if (!mounted) return;

    if (erfolg) {
      setState(() {
        final idx = _anhaenge.indexWhere((a) => a.id == anhang.id);
        if (idx != -1) {
          _anhaenge[idx] = anhang.copyWith(
            bezeichnung: result.bezeichnung,
            beschreibung: result.beschreibung,
          );
        }
      });
    } else {
      zeigeFehler('Speichern fehlgeschlagen.');
    }
  }

  void zeigeFehler(String message) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppConfig.spacingXXLarge),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_fehler != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConfig.spacingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: colorScheme.error,
                size: AppConfig.uploadAreaIconSize,
              ),
              const SizedBox(height: AppConfig.spacingSmall),
              Text(_fehler!, textAlign: TextAlign.center),
              const SizedBox(height: AppConfig.spacingMedium),
              FilledButton.tonal(
                onPressed: laden,
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
    }

    if (_anhaenge.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConfig.spacingXXLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.attach_file,
                size: AppConfig.iconSizeXLarge,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppConfig.spacingSmall),
              Text(
                'Noch keine Anhänge vorhanden.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppConfig.spacingXSmall),
              Text(
                'Tippe auf "Hinzufügen" um eine Datei hochzuladen.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: laden,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _anhaenge.length,
        separatorBuilder: (_, __) => Divider(
          height: AppConfig.strokeWidthThin,
          color: colorScheme.outlineVariant,
        ),
        itemBuilder: (ctx, i) => _AnhangTile(
          anhang: _anhaenge[i],
          onOeffnen: () => oeffnen(_anhaenge[i]),
          onLoeschen: () => loeschen(_anhaenge[i]),
          onBearbeiten: () => bearbeiten(_anhaenge[i]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AnhangTile
// ---------------------------------------------------------------------------

class _AnhangTile extends StatelessWidget {
  final AttachmentModel anhang;
  final VoidCallback onOeffnen;
  final VoidCallback onLoeschen;
  final VoidCallback onBearbeiten;

  const _AnhangTile({
    required this.anhang,
    required this.onOeffnen,
    required this.onLoeschen,
    required this.onBearbeiten,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = colorForMimeType(anhang.mimeType);
    final icon = iconForMimeType(anhang.mimeType);

    Widget leading;
    if (anhang.istBild && anhang.downloadUrl != null) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(AppConfig.cardBorderRadiusSmall),
        child: SizedBox(
          width: AppConfig.attachmentImageWidth,
          height: AppConfig.attachmentImageHeight,
          child: CachedNetworkImage(
            imageUrl: anhang.downloadUrl!,
            fit: BoxFit.cover,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(
                strokeWidth: AppConfig.strokeWidthMedium,
              ),
            ),
            errorWidget: (_, __, ___) => Icon(
              icon,
              color: color,
              size: AppConfig.progressIndicatorSize,
            ),
          ),
        ),
      );
    } else {
      leading = Container(
        width: AppConfig.attachmentIconContainerSize,
        height: AppConfig.attachmentIconContainerSize,
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppConfig.opacitySubtle),
          borderRadius: BorderRadius.circular(AppConfig.borderRadiusMedium),
        ),
        child: Icon(
          icon,
          color: color,
          size: AppConfig.attachmentIconSize,
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacingSmall,
        vertical: AppConfig.spacingXSmall,
      ),
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConfig.spacingMedium,
          vertical: AppConfig.spacingSmall,
        ),
        leading: leading,
        title: Text(
          anhang.bezeichnung,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${anhang.typLabel}'
              '${anhang.dateiGroesseFormatiert.isNotEmpty ? " · ${anhang.dateiGroesseFormatiert}" : ""}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (anhang.beschreibung != null &&
                anhang.beschreibung!.isNotEmpty)
              Text(
                anhang.beschreibung!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<_AnhangAktion>(
          icon: Icon(
            Icons.more_vert,
            color: colorScheme.onSurfaceVariant,
          ),
          onSelected: (aktion) {
            switch (aktion) {
              case _AnhangAktion.oeffnen:
                onOeffnen();
              case _AnhangAktion.bearbeiten:
                onBearbeiten();
              case _AnhangAktion.loeschen:
                onLoeschen();
            }
          },
          itemBuilder: (ctx) {
            final menuColorScheme = Theme.of(ctx).colorScheme;
            return [
              const PopupMenuItem(
                value: _AnhangAktion.oeffnen,
                child: ListTile(
                  leading: Icon(Icons.open_in_new),
                  title: Text('Öffnen'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: _AnhangAktion.bearbeiten,
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Bezeichnung bearbeiten'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _AnhangAktion.loeschen,
                child: ListTile(
                  leading: Icon(
                    Icons.delete,
                    color: menuColorScheme.error,
                  ),
                  title: Text(
                    'Löschen',
                    style: TextStyle(color: menuColorScheme.error),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ];
          },
        ),
        onTap: onOeffnen,
      ),
    );
  }
}

enum _AnhangAktion { oeffnen, bearbeiten, loeschen }

// ---------------------------------------------------------------------------
// _MetadatenDialog
// ---------------------------------------------------------------------------

class _MetadatenResult {
  final String bezeichnung;
  final String? beschreibung;

  const _MetadatenResult({required this.bezeichnung, this.beschreibung});
}

class _MetadatenDialog extends StatefulWidget {
  final String bezeichnung;
  final String? beschreibung;

  const _MetadatenDialog({
    required this.bezeichnung,
    this.beschreibung,
  });

  @override
  State<_MetadatenDialog> createState() => _MetadatenDialogState();
}

class _MetadatenDialogState extends State<_MetadatenDialog> {
  late final TextEditingController _bezeichnungCtrl;
  late final TextEditingController _beschreibungCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _bezeichnungCtrl = TextEditingController(text: widget.bezeichnung);
    _beschreibungCtrl = TextEditingController(text: widget.beschreibung ?? '');
  }

  @override
  void dispose() {
    _bezeichnungCtrl.dispose();
    _beschreibungCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bezeichnung bearbeiten'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _bezeichnungCtrl,
              decoration: const InputDecoration(
                labelText: 'Bezeichnung *',
                border: OutlineInputBorder(),
              ),
              maxLength: 100,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
            ),
            const SizedBox(height: AppConfig.spacingMedium),
            TextFormField(
              controller: _beschreibungCtrl,
              decoration: const InputDecoration(
                labelText: 'Beschreibung (optional)',
                border: OutlineInputBorder(),
              ),
              maxLength: 500,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                _MetadatenResult(
                  bezeichnung: _bezeichnungCtrl.text.trim(),
                  beschreibung: _beschreibungCtrl.text.trim().isEmpty
                      ? null
                      : _beschreibungCtrl.text.trim(),
                ),
              );
            }
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}