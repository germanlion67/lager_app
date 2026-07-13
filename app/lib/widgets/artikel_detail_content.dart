// lib/widgets/artikel_detail_content.dart
//
// F-011.7: Extrahierter Inhalt des ArtikelDetailScreen.
//
// Wird in zwei Modi verwendet:
//   embedded: false → eigenständiger Screen (mit Navigator.pop)
//   embedded: true  → inline im Master-Detail-Panel (Callbacks statt Navigation)
//
// Die gesamte Logik (Speichern, Löschen, Bild, Anhänge, PDF) bleibt hier.
// ArtikelDetailScreen ist nur noch ein dünner Scaffold-Wrapper.

import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../config/app_config.dart';
import '../core/responsive.dart';
import '../models/artikel_model.dart';
import '../services/app_log_service.dart';
import '../services/artikel_db_service.dart';
import '../services/image_picker.dart';
import '../services/pocketbase_service.dart';
import '../widgets/artikel_bild_widget.dart';
import '../widgets/app_loading_overlay.dart';

import '../screens/detail_screen_io.dart'
    if (dart.library.html) '../screens/detail_screen_stub.dart' as platform;
import '../services/pdf_service_stub.dart'
    if (dart.library.io) '../services/pdf_service.dart';

import '../services/attachment_service.dart';
import '../widgets/attachment_list_widget.dart';
import '../widgets/attachment_upload_widget.dart';

class ArtikelDetailContent extends StatefulWidget {
  const ArtikelDetailContent({
    super.key,
    required this.artikel,
    this.embedded = false,
    this.onSaved,
    this.onDeleted,
    this.onStateChanged,  // ← NEU
  });

  final Artikel artikel;

  /// true = inline im Master-Detail-Panel (kein Scaffold, kein Navigator.pop)
  final bool embedded;

  /// Wird nach erfolgreichem Speichern aufgerufen (nur im embedded-Modus).
  final ValueChanged<Artikel>? onSaved;

  /// Wird nach erfolgreichem Löschen aufgerufen (nur im embedded-Modus).
  final VoidCallback? onDeleted;

  /// Wird bei jedem setState aufgerufen, damit der Wrapper sich rebuilden kann.
  final VoidCallback? onStateChanged;  // ← NEU

  @override
  State<ArtikelDetailContent> createState() => ArtikelDetailContentState();
}

class ArtikelDetailContentState extends State<ArtikelDetailContent> {
  final Logger _logger = AppLogService.logger;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    // F-011.7: Wrapper über State-Änderung informieren (für AppBar-Rebuild)
    widget.onStateChanged?.call();
  }

  late final TextEditingController _nameController;
  late final TextEditingController _beschreibungController;
  late final TextEditingController _ortController;
  late final TextEditingController _fachController;
  late final TextEditingController _kategorieController;
  late int _menge;
  bool _isEditing = false;
  bool _hasChanged = false;

  bool _isSaving = false;
  bool _isDeleting = false;

  Uint8List? _pendingBytes;
  String? _bildPfad;
  String? _remoteBildUrl;

  late final ArtikelDbService _db;
  late final PocketBaseService _pbService;

  bool _isLoadingRemoteBild = false;

  int _anhangCount = 0;
  final _attachmentService = AttachmentService();

  bool get _hatBild =>
      _pendingBytes != null ||
      (_bildPfad != null && _bildPfad!.isNotEmpty) ||
      _remoteBildUrl != null;

  /// Ob ungespeicherte Änderungen vorliegen — für PopScope im Wrapper.
  bool get hasUnsavedChanges => _isEditing && _hasChanged;

  /// Öffentlich: Artikel speichern (z.B. aus dem Close-Dialog heraus).
  Future<void> speichern() => _speichern();

  @override
  void initState() {
    super.initState();

    _db = ArtikelDbService();
    _pbService = PocketBaseService();

    _nameController = TextEditingController(text: widget.artikel.name)
      ..addListener(_onChanged);
    _beschreibungController =
        TextEditingController(text: widget.artikel.beschreibung)
          ..addListener(_onChanged);
    _ortController = TextEditingController(text: widget.artikel.ort)
      ..addListener(_onChanged);
    _fachController = TextEditingController(text: widget.artikel.fach)
      ..addListener(_onChanged);
    _kategorieController = TextEditingController(
      text: widget.artikel.kategorie ?? '',
    )..addListener(_onChanged);
    _menge = widget.artikel.menge;
    _bildPfad =
        widget.artikel.bildPfad.isNotEmpty ? widget.artikel.bildPfad : null;

    if (kIsWeb) {
      _loadRemoteBildUrl();
    }
    _ladeAnhangCount();
  }

  @override
  void didUpdateWidget(covariant ArtikelDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    // F-011.7: Wenn im embedded-Modus ein anderer Artikel ausgewählt wird,
    // alle Felder neu initialisieren.
    if (widget.artikel.uuid != oldWidget.artikel.uuid) {
      _reinitializeForNewArtikel();
    }
  }

  void _reinitializeForNewArtikel() {
    _nameController.removeListener(_onChanged);
    _beschreibungController.removeListener(_onChanged);
    _ortController.removeListener(_onChanged);
    _fachController.removeListener(_onChanged);
    _kategorieController.removeListener(_onChanged);

    _nameController.text = widget.artikel.name;
    _beschreibungController.text = widget.artikel.beschreibung;
    _ortController.text = widget.artikel.ort;
    _fachController.text = widget.artikel.fach;
    _kategorieController.text = widget.artikel.kategorie ?? '';
    _menge = widget.artikel.menge;
    _bildPfad =
        widget.artikel.bildPfad.isNotEmpty ? widget.artikel.bildPfad : null;
    _pendingBytes = null;
    _remoteBildUrl = null;
    _isEditing = false;
    _hasChanged = false;
    _isSaving = false;
    _isDeleting = false;

    _nameController.addListener(_onChanged);
    _beschreibungController.addListener(_onChanged);
    _ortController.addListener(_onChanged);
    _fachController.addListener(_onChanged);
    _kategorieController.addListener(_onChanged);

    if (kIsWeb) {
      _loadRemoteBildUrl();
    }
    _ladeAnhangCount();

    setState(() {});
  }

  // ══════════════════════════════════════════════════════════════════════
  // Bild-Optionen BottomSheet
  // ══════════════════════════════════════════════════════════════════════

  void _showBildOptionen() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hatBild = _hatBild;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConfig.borderRadiusXLarge),
        ),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppConfig.spacingMedium),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: AppConfig.spacingMedium,
                  bottom: AppConfig.spacingSmall,
                ),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadiusXXSmall,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConfig.spacingLarge,
                  vertical: AppConfig.spacingSmall,
                ),
                child: Row(
                  children: [
                    Icon(
                      hatBild ? Icons.image : Icons.add_photo_alternate,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: AppConfig.spacingSmall),
                    Text(
                      hatBild ? 'Bild ändern' : 'Bild hinzufügen',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Aus Datei wählen'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickImageFile();
                },
              ),
              if (ImagePickerService.isCameraAvailable)
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Kamera'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _pickImageCamera();
                  },
                ),
              if (_pendingBytes != null ||
                  (!kIsWeb && _bildPfad != null && _bildPfad!.isNotEmpty))
                ListTile(
                  leading: const Icon(Icons.crop),
                  title: const Text('Zuschneiden'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _cropImageFromAny();
                  },
                ),
              if (hatBild) ...[
                const Divider(),
                ListTile(
                  leading: Icon(
                    Icons.image_not_supported_outlined,
                    color: colorScheme.error,
                  ),
                  title: Text(
                    'Bild entfernen',
                    style: TextStyle(color: colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _bildEntfernen();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cropImageFromAny() async {
    Uint8List? bytesToCrop = _pendingBytes;

    if (bytesToCrop == null && !kIsWeb && _bildPfad != null) {
      try {
        bytesToCrop = await platform.readFileBytes(_bildPfad!);
      } catch (e, st) {
        _logger.e(
          'Lokales Bild konnte nicht geladen werden',
          error: e,
          stackTrace: st,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bild konnte nicht geladen werden'),
            ),
          );
        }
        return;
      }
    }

    if (bytesToCrop == null) return;
    if (!mounted) return;

    final cropResult = await ImagePickerService.openCropDialog(
      context,
      bytesToCrop,
    );
    if (!mounted || cropResult == null) return;

    setState(() {
      _pendingBytes = cropResult.bytes;
      _hasChanged = true;
    });
  }

  // ══════════════════════════════════════════════════════════════════════
  // Bild entfernen
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _bildEntfernen() async {
    final colorScheme = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.image_not_supported_outlined,
          color: colorScheme.error,
          size: AppConfig.iconSizeXLarge,
        ),
        title: const Text('Bild entfernen?'),
        content: const Text(
          'Das Bild wird lokal gelöscht und beim nächsten '
          'Sync auch auf dem Server entfernt.',
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
            child: const Text('Bild entfernen'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    _logger.i('Bild entfernen für ${widget.artikel.uuid}');

    if (!kIsWeb) {
      await _deleteLocalImageFiles();
    }

    _clearImageCache();

    setState(() {
      _pendingBytes = null;
      _bildPfad = null;
      _remoteBildUrl = null;
      _hasChanged = true;
    });
  }

  Future<void> _deleteLocalImageFiles() async {
    try {
      if (_bildPfad != null) {
        await platform.deleteFileIfExists(_bildPfad!);
      }
      final thumbPfad = widget.artikel.thumbnailPfad;
      if (thumbPfad != null && thumbPfad.isNotEmpty) {
        await platform.deleteFileIfExists(thumbPfad);
      }
    } catch (e, st) {
      _logger.w(
        'Lokale Bilddateien konnten nicht gelöscht werden',
        error: e,
        stackTrace: st,
      );
    }
  }

  // NACHHER:
  Future<void> _ladeAnhangCount() async {
    try {
      final count = await _attachmentService.countForArtikel(
        widget.artikel.uuid,
      );
      if (mounted) setState(() => _anhangCount = count);
    } catch (e) {
      // PocketBase nicht verfügbar (z.B. in Tests) → ignorieren
      _logger.w('Anhang-Count konnte nicht geladen werden: $e');
    }
  }

  Future<void> _loadRemoteBildUrl() async {
    if (mounted) setState(() => _isLoadingRemoteBild = true);

    try {
      final filter = 'uuid = "${widget.artikel.uuid}"';
      final list = await _pbService.client
          .collection('artikel')
          .getList(filter: filter);

      if (list.items.isNotEmpty) {
        final record = list.items.first;
        final bildField = record.data['bild'];
        if (bildField != null && bildField.toString().isNotEmpty) {
          final url = _pbService.client.files
              .getUrl(record, bildField.toString())
              .toString();
          if (mounted) setState(() => _remoteBildUrl = url);
        }
      }
    } catch (e, st) {
      _logger.e('Bild-URL laden fehlgeschlagen:', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isLoadingRemoteBild = false);
    }
  }

  void _onChanged() {
    if (_isEditing) {
      setState(() => _hasChanged = true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _beschreibungController.dispose();
    _ortController.dispose();
    _kategorieController.dispose();
    _fachController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════
  // Bild-Auswahl
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _pickImageFile() async {
    final PickedImage picked =
        await ImagePickerService.pickImageFile(context);
    if (!picked.hasImage) return;
    await _applyPickedImage(picked);
  }

  Future<void> _pickImageCamera() async {
    if (!ImagePickerService.isCameraAvailable) return;
    final PickedImage picked =
        await ImagePickerService.pickImageCamera(context);
    if (!picked.hasImage) return;
    await _applyPickedImage(picked);
  }

  Future<void> _applyPickedImage(PickedImage picked) async {
    final artikelId = widget.artikel.id;

    if (!kIsWeb && artikelId != null && picked.pfad != null) {
      try {
        final persistenterPfad = await platform.persistSelectedImage(
          bildBytes: picked.bytes,
          bildPfad: picked.pfad,
          artikelId: artikelId,
          artikelName: widget.artikel.name,
          onThumbnailSaved: (thumbPath) async {
            await _db.setThumbnailPfadByUuid(
              widget.artikel.uuid,
              thumbPath,
            );
          },
        );

        _clearImageCache();

        setState(() {
          _pendingBytes = picked.bytes;
          _bildPfad = persistenterPfad;
          _hasChanged = true;
        });
      } catch (e, st) {
        _logger.e(
          'Persistentes Speichern fehlgeschlagen',
          error: e,
          stackTrace: st,
        );
        setState(() {
          _pendingBytes = picked.bytes;
          _bildPfad = null;
          _hasChanged = true;
        });
      }
    } else {
      setState(() {
        _pendingBytes = picked.bytes;
        _bildPfad = picked.pfad;
        _hasChanged = true;
      });
    }
  }

  void _clearImageCache() {
    imageCache.clear();
    imageCache.clearLiveImages();
    if (_remoteBildUrl != null) {
      CachedNetworkImage.evictFromCache(_remoteBildUrl!);
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // Speichern
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _speichern() async {
    if (!_hasChanged) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Änderungen zum Speichern gefunden'),
          ),
        );
      }
      return;
    }
    if (mounted) setState(() => _isSaving = true);
    try {
      if (kIsWeb) {
        await _speichernWeb();
      } else {
        await _speichernMobile();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _speichernWeb() async {
    try {
      final filter = 'uuid = "${widget.artikel.uuid}"';
      final list = await _pbService.client
          .collection('artikel')
          .getList(filter: filter);

      if (list.items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Artikel nicht in PocketBase gefunden'),
            ),
          );
        }
        return;
      }

      final recordId = list.items.first.id;
      final now = DateTime.now().toUtc();

      // Bild wurde entfernt → leeres bild-Feld an PocketBase senden.
      // Im Web-Mode ist _bildPfad immer null — daher zusätzlich _remoteBildUrl == null
      // prüfen: URL ist nur null wenn der Nutzer das Bild explizit entfernt hat.
      final bildEntfernt = _bildPfad == null &&
          _pendingBytes == null &&
          _remoteBildUrl == null &&
          widget.artikel.remoteBildPfad != null &&
          widget.artikel.remoteBildPfad!.isNotEmpty;

      if (bildEntfernt && _remoteBildUrl != null) {
        // Cache leeren — kein DB-Aufruf im Web
        await CachedNetworkImage.evictFromCache(_remoteBildUrl!);
      }

      final body = <String, dynamic>{
        'name': _nameController.text.trim(),
        'menge': _menge,
        'ort': _ortController.text,
        'fach': _fachController.text,
        'beschreibung': _beschreibungController.text,
        'kategorie': _kategorieController.text.trim().isEmpty
            ? null
            : _kategorieController.text.trim(),
        'aktualisiertAm': now.toIso8601String(),
        'updated_at': now.millisecondsSinceEpoch,
      };

      // Bild entfernen: leeres bild-Feld senden
      // PocketBase löscht das Bild wenn ein leerer String gesendet wird
      if (bildEntfernt) {
        body['bild'] = '';
      }

      final List<http.MultipartFile> files = [];
      if (_pendingBytes != null) {
        files.add(
          http.MultipartFile.fromBytes(
            'bild',
            _pendingBytes!,
            filename: 'bild_${widget.artikel.uuid}.jpg',
          ),
        );
      }

      await _pbService.client
          .collection('artikel')
          .update(recordId, body: body, files: files);

      final updatedRecord = await _pbService.client
          .collection('artikel')
          .getOne(recordId);

      final neuerBildPfad =
          updatedRecord.data['bild']?.toString() ?? '';

      if (_remoteBildUrl != null) {
        await CachedNetworkImage.evictFromCache(_remoteBildUrl!);
      }

      if (!mounted) return;

      final gespeicherterArtikel = widget.artikel.copyWith(
        name: _nameController.text.trim(),
        menge: _menge,
        ort: _ortController.text,
        fach: _fachController.text,
        beschreibung: _beschreibungController.text,
        kategorie: _kategorieController.text.trim().isEmpty
            ? null
            : _kategorieController.text.trim(),
        aktualisiertAm: now,
        remoteBildPfad: neuerBildPfad,
        remotePath: recordId,
      );

      setState(() {
        _isEditing = false;
        _hasChanged = false;
        _pendingBytes = null;
      });

      // Remote-Bild-URL neu laden nach erfolgreichem Speichern
      if (neuerBildPfad.isNotEmpty) {
        unawaited(_loadRemoteBildUrl()); // ← Fire-and-forget ist hier korrekt
      } else {
        setState(() => _remoteBildUrl = null);
      }

      _finishSave(gespeicherterArtikel);
    } catch (e, st) {
      _logger.e('Speichern (Web) fehlgeschlagen:', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
        );
      }
    }
  }

  Future<void> _speichernMobile() async {
    final artikelId = widget.artikel.id;
    if (artikelId == null) return;

    final hasNewImage =
        _bildPfad != null && _bildPfad != widget.artikel.bildPfad;
    final bildEntfernt =
        _bildPfad == null && widget.artikel.bildPfad.isNotEmpty;

    final artikelMitAenderungen = widget.artikel.copyWith(
      name: _nameController.text.trim(),
      menge: _menge,
      ort: _ortController.text,
      fach: _fachController.text,
      beschreibung: _beschreibungController.text,
      kategorie: _kategorieController.text.trim().isEmpty
          ? null
          : _kategorieController.text.trim(),
      bildPfad: _bildPfad ?? '',
      aktualisiertAm: DateTime.now().toUtc(),
    );

    try {
      await _db.updateArtikel(artikelMitAenderungen);

      if (bildEntfernt) {
        await _db.clearBildInfoByUuidSilent(widget.artikel.uuid);
        await _db.markAsModified(widget.artikel.uuid);
      }

      if (hasNewImage) {
        unawaited(
          _uploadImageToPocketBase(
            uuid: widget.artikel.uuid,
            localImagePath: _bildPfad,
            bildBytes: _pendingBytes,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _isEditing = false;
        _hasChanged = false;
        _pendingBytes = null;
        _bildPfad = artikelMitAenderungen.bildPfad.isNotEmpty
            ? artikelMitAenderungen.bildPfad
            : null;
      });

      _finishSave(artikelMitAenderungen);
    } catch (e, st) {
      _logger.e('Speichern (Mobile) fehlgeschlagen', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
    }
  }

  /// F-011.7: Einheitlicher Abschluss nach Speichern.
  /// Im embedded-Modus: Callback. Sonst: Navigator.pop().
  void _finishSave(Artikel gespeicherterArtikel) {
    if (widget.embedded) {
      widget.onSaved?.call(gespeicherterArtikel);
    } else {
      Navigator.pop(context, gespeicherterArtikel);
    }
  }

  Future<void> _uploadImageToPocketBase({
    required String uuid,
    String? localImagePath,
    Uint8List? bildBytes,
  }) async {
    try {
      final filter = 'uuid = "$uuid"';
      final list = await _pbService.client
          .collection('artikel')
          .getList(filter: filter);
      if (list.items.isEmpty) return;

      final recordId = list.items.first.id;

      final Uint8List bytes;
      final String filename;

      if (bildBytes != null) {
        bytes = bildBytes;
        filename = 'bild_$uuid.jpg';
      } else if (localImagePath != null) {
        bytes = await platform.readFileBytes(localImagePath);
        filename = p.basename(localImagePath);
      } else {
        return;
      }

      await _pbService.client.collection('artikel').update(
        recordId,
        files: [
          http.MultipartFile.fromBytes('bild', bytes, filename: filename),
        ],
      );

      await _db.markSynced(uuid, recordId);
    } catch (e, st) {
      _logger.e(
        'PocketBase Bild-Upload fehlgeschlagen:',
        error: e,
        stackTrace: st,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // Löschen
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _loeschen() async {
    final colorScheme = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Artikel löschen?'),
        content: Text(
          'Möchtest du "${widget.artikel.name}" wirklich löschen?',
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

    if (confirm != true) return;
    if (!mounted) return;

    setState(() => _isDeleting = true);

    try {
      unawaited(
        _attachmentService.deleteAllForArtikel(widget.artikel.uuid),
      );

      if (kIsWeb) {
        final filter = 'uuid = "${widget.artikel.uuid}"';
        final list = await _pbService.client
            .collection('artikel')
            .getList(filter: filter);
        if (list.items.isNotEmpty) {
          await _pbService.client
              .collection('artikel')
              .delete(list.items.first.id);
        }
      } else {
        await _db.deleteArtikel(widget.artikel);
      }

      if (!mounted) return;

      if (widget.embedded) {
        widget.onDeleted?.call();
      } else {
        Navigator.pop(context, null);
      }
    } catch (e, st) {
      _logger.e('Löschen fehlgeschlagen:', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Löschen fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // PDF
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _generateArtikelDetailPdf() async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF-Export ist im Web noch nicht verfügbar'),
          ),
        );
      }
      return;
    }

    try {
      final pdfService = PdfService();

      final aktuellerArtikel = widget.artikel.copyWith(
        name: _nameController.text.trim(),
        menge: _menge,
        ort: _ortController.text,
        fach: _fachController.text,
        beschreibung: _beschreibungController.text,
        bildPfad: _bildPfad ?? widget.artikel.bildPfad,
        aktualisiertAm: DateTime.now().toUtc(),
      );

      final pdfFile =
          await pdfService.generateArtikelDetailPdf(aktuellerArtikel);

      if (pdfFile != null && mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('PDF gespeichert:\n$pdfFile'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Öffnen',
              onPressed: () async {
                messenger.clearSnackBars();
                final success = await PdfService.openPdf(pdfFile);
                if (!success && mounted) {
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('PDF konnte nicht geöffnet werden'),
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
    } catch (e, st) {
      _logger.e('Fehler beim PDF-Export:', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text('Fehler beim PDF-Export: $e')),
          );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // Mengen-Steuerung
  // ══════════════════════════════════════════════════════════════════════

  void _mengeErhoehen() {
    setState(() {
      _menge++;
      _hasChanged = true;
    });
  }

  void _mengeVerringern() {
    if (_menge > 0) {
      setState(() {
        _menge--;
        _hasChanged = true;
      });
    }
  }

  void _enableEdit() {
    setState(() {
      _isEditing = true;
      _hasChanged = false;
    });
  }

  // ══════════════════════════════════════════════════════════════════════
  // Vollbild
  // ══════════════════════════════════════════════════════════════════════

  void _zeigeBildVollbild() {
    final hasPending = _pendingBytes != null;
    final hasRemote = kIsWeb && _remoteBildUrl != null;
    final hasLocal = !kIsWeb && _bildPfad != null;

    if (!hasPending && !hasRemote && !hasLocal) return;

    final colorScheme = Theme.of(context).colorScheme;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogCtx) => GestureDetector(
        onTap: () => Navigator.pop(dialogCtx),
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: colorScheme.onInverseSurface,
            title: Text(
              _nameController.text.isNotEmpty
                  ? _nameController.text
                  : widget.artikel.name,
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: _buildVollbildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVollbildContent() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_pendingBytes != null) {
      return Image.memory(_pendingBytes!, fit: BoxFit.contain);
    }
    if (kIsWeb && _remoteBildUrl != null) {
      return CachedNetworkImage(
        imageUrl: _remoteBildUrl!,
        fit: BoxFit.contain,
        placeholder: (_, __) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (_, __, ___) => Icon(
          Icons.image_not_supported,
          color: colorScheme.onInverseSurface,
          size: 64,
        ),
      );
    }
    if (!kIsWeb && _bildPfad != null) {
      return platform.buildFileImage(_bildPfad!, fit: BoxFit.contain);
    }
    return Icon(
      Icons.image_not_supported,
      color: colorScheme.onInverseSurface,
      size: 64,
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // Shared Field Widgets
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildMengeField(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isBlocked,
  ) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Menge',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: _isEditing
            ? colorScheme.surface
            : colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConfig.spacingMedium,
          vertical: AppConfig.spacingXSmall,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$_menge', style: textTheme.titleMedium),
          if (_isEditing && !isBlocked)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _mengeVerringern,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _mengeErhoehen,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildArtikelnummerField(
    Artikel artikel,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Artikelnummer',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
      ),
      child: Text(
        artikel.artikelnummer?.toString() ?? '-',
        style: textTheme.titleMedium,
      ),
    );
  }

  Widget _buildBildBereich(Artikel artikel, ColorScheme colorScheme) {
    if (_isLoadingRemoteBild && _remoteBildUrl == null && _pendingBytes == null) {
      return Container(
        height: AppConfig.artikelDetailBildHoehe,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(
            AppConfig.cardBorderRadiusLarge,
          ),
        ),
        child: const CircularProgressIndicator(),
      );
    }
    return ArtikelDetailBild(
      artikel: artikel.copyWith(
        bildPfad: _bildPfad ?? '',
        remoteBildPfad:
            _remoteBildUrl != null ? artikel.remoteBildPfad : '',
        remotePath: _remoteBildUrl != null ? artikel.remotePath : '',
      ),
      pendingBytes: _pendingBytes,
      remoteBildUrl: _remoteBildUrl,
      onTap: _zeigeBildVollbild,
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // Felder-Liste (Mobile-Layout)
  // ══════════════════════════════════════════════════════════════════════

  List<Widget> _buildFelder({
    required Artikel artikel,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required bool isBlocked,
  }) {
    return [
      TextField(
        controller: _nameController,
        enabled: _isEditing && !isBlocked,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Name',
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: _isEditing
              ? colorScheme.surface
              : colorScheme.surfaceContainerLow,
        ),
      ),
      const SizedBox(height: AppConfig.spacingMedium),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _ortController,
              enabled: _isEditing && !isBlocked,
              decoration: InputDecoration(
                labelText: 'Ort',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: _isEditing
                    ? colorScheme.surface
                    : colorScheme.surfaceContainerLow,
              ),
            ),
          ),
          const SizedBox(width: AppConfig.detailFieldSpacing),
          Expanded(
            child: TextField(
              controller: _fachController,
              enabled: _isEditing && !isBlocked,
              decoration: InputDecoration(
                labelText: 'Fach',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: _isEditing
                    ? colorScheme.surface
                    : colorScheme.surfaceContainerLow,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppConfig.spacingSectionGap),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildMengeField(colorScheme, textTheme, isBlocked),
          ),
          const SizedBox(width: AppConfig.detailFieldSpacing),
          Expanded(
            child: _buildArtikelnummerField(artikel, colorScheme, textTheme),
          ),
        ],
      ),
      const SizedBox(height: AppConfig.spacingSectionGap),
      TextField(
        controller: _beschreibungController,
        enabled: _isEditing && !isBlocked,
        decoration: InputDecoration(
          labelText: 'Beschreibung',
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: _isEditing
              ? colorScheme.surface
              : colorScheme.surfaceContainerLow,
        ),
        maxLines: 3,
      ),
      const SizedBox(height: AppConfig.spacingSectionGap),
      if (_anhangCount > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: AppConfig.spacingMedium),
          child: Text(
            'Anhänge: $_anhangCount',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      TextField(
        controller: _kategorieController,
        enabled: _isEditing && !isBlocked,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Kategorie',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.category_outlined),
          filled: true,
          fillColor: _isEditing
              ? colorScheme.surface
              : colorScheme.surfaceContainerLow,
        ),
      ),
      const SizedBox(height: AppConfig.spacingSectionGap),
      _buildBildBereich(artikel, colorScheme),
    ];
  }

  Widget _buildMobileLayout({
    required Artikel artikel,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required bool isBlocked,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildFelder(
        artikel: artikel,
        colorScheme: colorScheme,
        textTheme: textTheme,
        isBlocked: isBlocked,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // Desktop-Layout (zweispaltig)
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildDesktopLayout({
    required Artikel artikel,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required bool isBlocked,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                enabled: _isEditing && !isBlocked,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: _isEditing
                      ? colorScheme.surface
                      : colorScheme.surfaceContainerLow,
                ),
              ),
              const SizedBox(height: AppConfig.spacingMedium),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ortController,
                      enabled: _isEditing && !isBlocked,
                      decoration: InputDecoration(
                        labelText: 'Ort',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: _isEditing
                            ? colorScheme.surface
                            : colorScheme.surfaceContainerLow,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConfig.detailFieldSpacing),
                  Expanded(
                    child: TextField(
                      controller: _fachController,
                      enabled: _isEditing && !isBlocked,
                      decoration: InputDecoration(
                        labelText: 'Fach',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: _isEditing
                            ? colorScheme.surface
                            : colorScheme.surfaceContainerLow,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConfig.spacingSectionGap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildMengeField(colorScheme, textTheme, isBlocked),
                  ),
                  const SizedBox(width: AppConfig.detailFieldSpacing),
                  Expanded(
                    child: _buildArtikelnummerField(
                      artikel,
                      colorScheme,
                      textTheme,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppConfig.spacingLarge),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBildBereich(artikel, colorScheme),
              const SizedBox(height: AppConfig.spacingSectionGap),
              TextField(
                controller: _beschreibungController,
                enabled: _isEditing && !isBlocked,
                decoration: InputDecoration(
                  labelText: 'Beschreibung',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: _isEditing
                      ? colorScheme.surface
                      : colorScheme.surfaceContainerLow,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: AppConfig.spacingSectionGap),
              TextField(
                controller: _kategorieController,
                enabled: _isEditing && !isBlocked,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Kategorie',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.category_outlined),
                  filled: true,
                  fillColor: _isEditing
                      ? colorScheme.surface
                      : colorScheme.surfaceContainerLow,
                ),
              ),
              if (_anhangCount > 0) ...[
                const SizedBox(height: AppConfig.spacingMedium),
                Text(
                  'Anhänge: $_anhangCount',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // AppBar-Aktionen (wiederverwendbar für Wrapper + embedded)
  // ══════════════════════════════════════════════════════════════════════

  /// Baut die Liste der AppBar-Actions.
  /// Wird vom ArtikelDetailScreen-Wrapper und vom Master-Detail-Panel
  /// verwendet.
  List<Widget> buildActions(ColorScheme colorScheme) {
    final bool isBlocked = _isSaving || _isDeleting;
    final bool isReadonly = _pbService.isReadonlyUser; // M-014

    return [
      if (_isEditing && !isReadonly)
        IconButton(
          icon: Icon(_hatBild ? Icons.image : Icons.add_photo_alternate),
          tooltip: _hatBild ? 'Bild ändern' : 'Bild hinzufügen',
          onPressed: isBlocked ? null : _showBildOptionen,
        ),
      Stack(
        alignment: Alignment.topRight,
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            tooltip:
                _anhangCount == 0 ? 'Anhänge' : 'Anhänge ($_anhangCount)',
            onPressed: isBlocked
                ? null
                : () => AnhaengeSektion(
                      artikelUuid: widget.artikel.uuid,
                      anhangCount: _anhangCount,
                      onCountChanged: (c) =>
                          setState(() => _anhangCount = c),
                    ).zeigeAnhaengeSheet(context),
          ),
          if (_anhangCount > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 14,
                  minHeight: 14,
                ),
                child: Text(
                  '$_anhangCount',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: AppConfig.fontSizeXSmall,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      if (!isReadonly)
        IconButton(
          icon: Icon(!_isEditing ? Icons.edit : Icons.save),
          tooltip: !_isEditing
              ? 'Ändern'
              : (_hasChanged ? 'Speichern' : 'Keine Änderungen'),
          onPressed: isBlocked
              ? null
              : !_isEditing
                  ? _enableEdit
                  : (_hasChanged ? _speichern : null),
        ),
      IconButton(
        icon: const Icon(Icons.picture_as_pdf),
        onPressed: isBlocked ? null : _generateArtikelDetailPdf,
        tooltip: 'Als PDF exportieren',
      ),
      if (!isReadonly)
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: (_isEditing || isBlocked) ? null : _loeschen,
          tooltip: _isEditing
              ? 'Erst speichern oder Bearbeitung abbrechen'
              : 'Artikel löschen',
        ),
    ];
  }

  /// Titel-Text für AppBar.
  String get titleText => _isEditing
      ? (_nameController.text.isEmpty
          ? widget.artikel.name
          : _nameController.text)
      : widget.artikel.name;

  // ══════════════════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final artikel = widget.artikel;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bool isBlocked = _isSaving || _isDeleting;

    final Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop =
            Responsive.fromConstraints(constraints) == ScreenSize.desktop;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppConfig.spacingLarge),
          child: isDesktop
              ? _buildDesktopLayout(
                  artikel: artikel,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  isBlocked: isBlocked,
                )
              : _buildMobileLayout(
                  artikel: artikel,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  isBlocked: isBlocked,
                ),
        );
      },
    );

    // Loading-Overlays
    return Stack(
      children: [
        content,
        if (_isSaving) const AppLoadingOverlay(message: 'Speichern...'),
        if (_isDeleting) const AppLoadingOverlay(message: 'Löschen...'),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// AnhaengeSektion + AnhaengeSheet — unverändert aus artikel_detail_screen.dart
// ══════════════════════════════════════════════════════════════════════════

class AnhaengeSektion extends StatelessWidget {
  final String artikelUuid;
  final int anhangCount;
  final void Function(int count) onCountChanged;

  const AnhaengeSektion({
    super.key,
    required this.artikelUuid,
    required this.anhangCount,
    required this.onCountChanged,
  });

  void zeigeAnhaengeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConfig.borderRadiusXLarge),
        ),
      ),
      builder: (_) => AnhaengeSheet(
        artikelUuid: artikelUuid,
        onCountChanged: onCountChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class AnhaengeSheet extends StatefulWidget {
  final String artikelUuid;
  final void Function(int count) onCountChanged;

  const AnhaengeSheet({
    super.key,
    required this.artikelUuid,
    required this.onCountChanged,
  });

  @override
  State<AnhaengeSheet> createState() => AnhaengeSheetState();
}

class AnhaengeSheetState extends State<AnhaengeSheet> {
  final AttachmentService service = AttachmentService();
  int count = 0;

  @override
  void initState() {
    super.initState();
    ladeCount();
  }

  Future<void> ladeCount() async {
    final result = await service.countForArtikel(widget.artikelUuid);
    if (mounted) {
      setState(() => count = result);
      widget.onCountChanged(result);
    }
  }

  void zeigeUploadDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConfig.borderRadiusXLarge),
        ),
      ),
      builder: (_) => AttachmentUploadWidget(
        artikelUuid: widget.artikelUuid,
        aktuelleAnzahl: count,
        onUploaded: (_) => ladeCount(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConfig.spacingLarge,
              AppConfig.spacingMedium,
              AppConfig.spacingLarge,
              0,
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadiusXXSmall,
                    ),
                  ),
                ),
                const SizedBox(height: AppConfig.spacingMedium),
                Row(
                  children: [
                    const Icon(Icons.attach_file),
                    const SizedBox(width: AppConfig.spacingSmall),
                    Text(
                      count > 0 ? 'Anhänge ($count)' : 'Anhänge',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: zeigeUploadDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Hinzufügen'),
                    ),
                  ],
                ),
                const SizedBox(height: AppConfig.spacingSmall),
                const Divider(),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              child: AttachmentListWidget(
                artikelUuid: widget.artikelUuid,
                onChanged: ladeCount,
              ),
            ),
          ),
        ],
      ),
    );
  }
}