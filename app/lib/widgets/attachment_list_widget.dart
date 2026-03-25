// lib/widgets/attachment_list_widget.dart
//
// M-012: Liste aller Anhaenge eines Artikels.
// Aktionen: Oeffnen, Bearbeiten (Bezeichnung), Loeschen.
// Plattformunabhaengig — Web, Mobile, Desktop.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // Kein Umlaut in Bezeichnern: _anhaenge statt _anhänge
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
    // Kein Umlaut in lokalem Bezeichner: bestaetigt statt bestätigt
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_fehler != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 8),
              Text(_fehler!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.attach_file, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Noch keine Anhänge vorhanden.',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 4),
              Text(
                'Tippe auf "Hinzufügen" um eine Datei hochzuladen.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
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
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) => _AnhangTile(
          anhang: _anhaenge[i],
          // Kein Umlaut in named params: onOeffnen, onLoeschen, onBearbeiten
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
    final color = colorForMimeType(anhang.mimeType);
    final icon = iconForMimeType(anhang.mimeType);

    Widget leading;
    if (anhang.istBild && anhang.downloadUrl != null) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 56,
          height: 48,
          child: CachedNetworkImage(
            imageUrl: anhang.downloadUrl!,
            fit: BoxFit.cover,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            errorWidget: (_, __, ___) => Icon(icon, color: color, size: 32),
          ),
        ),
      );
    } else {
      leading = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          // withOpacity deprecated → withValues
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 28),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        leading: leading,
        title: Text(
          anhang.bezeichnung,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${anhang.typLabel}'
              '${anhang.dateiGroesseFormatiert.isNotEmpty ? " · ${anhang.dateiGroesseFormatiert}" : ""}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (anhang.beschreibung != null && anhang.beschreibung!.isNotEmpty)
              Text(
                anhang.beschreibung!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        trailing: PopupMenuButton<_AnhangAktion>(
          icon: const Icon(Icons.more_vert),
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
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: _AnhangAktion.oeffnen,
              child: ListTile(
                leading: Icon(Icons.open_in_new),
                title: Text('Öffnen'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
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
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Löschen', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        onTap: onOeffnen,
      ),
    );
  }
}

// Kein Umlaut in enum-Werten: oeffnen, loeschen statt öffnen, löschen
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
            const SizedBox(height: 12),
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