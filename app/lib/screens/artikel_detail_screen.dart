// lib/screens/artikel_detail_screen.dart
//
// O-004 Batch 3: Alle hardcodierten Farben durch colorScheme ersetzt,
// alle Magic-Number-Abstände/Radien durch AppConfig-Tokens.
//
// M-004: Loading States — _isSaving, _isDeleting, AppLoadingOverlay,
//        AppLoadingButton. Inkonsistenter ElevatedButton ersetzt.

import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../config/app_config.dart';
import '../models/artikel_model.dart';
import '../services/app_log_service.dart';
import '../services/artikel_db_service.dart';
import '../services/image_picker.dart';
import '../services/pocketbase_service.dart';
// M-011: Zentrales Bild-Widget
import '../widgets/artikel_bild_widget.dart';
// M-004: Zentrales Loading-Widget
import '../widgets/app_loading_overlay.dart';

import 'detail_screen_io.dart'
    if (dart.library.html) 'detail_screen_stub.dart' as platform;
import '../services/pdf_service_stub.dart'
    if (dart.library.io) '../services/pdf_service.dart';

// M-012: Anhänge
import '../services/attachment_service.dart';
import '../widgets/attachment_list_widget.dart';
import '../widgets/attachment_upload_widget.dart';

class ArtikelDetailScreen extends StatefulWidget {
  final Artikel artikel;

  const ArtikelDetailScreen({super.key, required this.artikel});

  @override
  State<ArtikelDetailScreen> createState() => _ArtikelDetailScreenState();
}

class _ArtikelDetailScreenState extends State<ArtikelDetailScreen> {
  final Logger _logger = AppLogService.logger;

  late final TextEditingController _beschreibungController;
  late final TextEditingController _ortController;
  late final TextEditingController _fachController;
  late int _menge;
  bool _isEditing = false;
  bool _hasChanged = false;

  // M-004: Loading States für Speichern und Löschen
  bool _isSaving = false;
  bool _isDeleting = false;

  // M-011: pendingBytes für neu gewähltes (noch nicht gespeichertes) Bild
  Uint8List? _pendingBytes;
  String? _bildPfad;
  String? _remoteBildUrl;

  late final ArtikelDbService _db;
  late final PocketBaseService _pbService;

  bool _isLoadingRemoteBild = false;

  // M-012: Anhänge
  int _anhangCount = 0;
  final _attachmentService = AttachmentService();

  @override
  void initState() {
    super.initState();

    _db = ArtikelDbService();
    _pbService = PocketBaseService();

    _beschreibungController =
        TextEditingController(text: widget.artikel.beschreibung)
          ..addListener(_onChanged);
    _ortController = TextEditingController(text: widget.artikel.ort)
      ..addListener(_onChanged);
    _fachController = TextEditingController(text: widget.artikel.fach)
      ..addListener(_onChanged);
    _menge = widget.artikel.menge;
    _bildPfad =
        widget.artikel.bildPfad.isNotEmpty ? widget.artikel.bildPfad : null;

    if (kIsWeb) {
      _loadRemoteBildUrl();
    }
    // M-012: Anhang-Anzahl für Badge laden
    ladeAnhangCount();
  }

  // M-012: kein führender Underscore → kein Lint-Fehler
  Future<void> ladeAnhangCount() async {
    final count = await _attachmentService.countForArtikel(
      widget.artikel.uuid,
    );
    if (mounted) setState(() => _anhangCount = count);
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
    _beschreibungController.dispose();
    _ortController.dispose();
    _fachController.dispose();
    super.dispose();
  }

  // ==================== BILD AUSWAHL ====================

  Future<void> _pickImageFile() async {
    _logger.i('Bildauswahl (Datei) gestartet');

    final PickedImage picked =
        await ImagePickerService.pickImageFile(context);
    if (!picked.hasImage) {
      _logger.w('Bildauswahl abgebrochen – kein Bild gewählt');
      return;
    }

    _logger.d(
      'Bild gewählt – Pfad: ${picked.pfad}, '
      'Bytes: ${picked.bytes?.length ?? 0}',
    );
    await _applyPickedImage(picked);
  }

  Future<void> _pickImageCamera() async {
    if (!ImagePickerService.isCameraAvailable) {
      _logger.w('Kamera nicht verfügbar');
      return;
    }

    _logger.i('Bildauswahl (Kamera) gestartet');

    final PickedImage picked =
        await ImagePickerService.pickImageCamera(context);
    if (!picked.hasImage) {
      _logger.w('Kameraaufnahme abgebrochen');
      return;
    }

    _logger.d(
      'Kamerabild aufgenommen – Bytes: ${picked.bytes?.length ?? 0}',
    );
    await _applyPickedImage(picked);
  }

  Future<void> _applyPickedImage(PickedImage picked) async {
    final artikelId = widget.artikel.id;

    if (!kIsWeb && artikelId != null && picked.pfad != null) {
      _logger.d('Starte persistentes Speichern des Bildes...');

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
            _logger.d('Thumbnail sofort gespeichert: $thumbPath');
          },
        );

        _logger.i('Bild persistent gespeichert: $persistenterPfad');
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
      _logger.d(
        'Web-Modus: Bild als Bytes gemerkt '
        '(${picked.bytes?.length ?? 0} bytes)',
      );
      setState(() {
        _pendingBytes = picked.bytes;
        _bildPfad = picked.pfad;
        _hasChanged = true;
      });
    }
  }

  void _clearImageCache() {
    _logger.d('Image-Cache wird geleert');
    imageCache.clear();
    imageCache.clearLiveImages();

    if (_remoteBildUrl != null) {
      CachedNetworkImage.evictFromCache(_remoteBildUrl!);
      _logger.t('CachedNetworkImage-Cache geleert: $_remoteBildUrl');
    }

    _logger.d('Image-Cache geleert');
  }

  // ==================== SPEICHERN ====================

  // M-004: _speichern() setzt _isSaving und zeigt AppLoadingOverlay.
  Future<void> _speichern() async {
    if (mounted) setState(() => _isSaving = true);
    try {
      if (kIsWeb) {
        await _speichernWeb();
      } else {
        await _speichernMobile();
      }
    } finally {
      // Nur zurücksetzen wenn noch mounted und nicht bereits via pop beendet.
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

      final body = <String, dynamic>{
        'menge': _menge,
        'ort': _ortController.text,
        'fach': _fachController.text,
        'beschreibung': _beschreibungController.text,
        'aktualisiertAm': now.toIso8601String(),
        'updated_at': now.millisecondsSinceEpoch,
      };

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
        unawaited(CachedNetworkImage.evictFromCache(_remoteBildUrl!));
        _logger.d('Alter Bild-Cache invalidiert: $_remoteBildUrl');
      }

      if (!mounted) return;

      final gespeicherterArtikel = widget.artikel.copyWith(
        menge: _menge,
        ort: _ortController.text,
        fach: _fachController.text,
        beschreibung: _beschreibungController.text,
        aktualisiertAm: now,
        remoteBildPfad: neuerBildPfad,
        remotePath: recordId,
      );

      setState(() {
        _isEditing = false;
        _hasChanged = false;
        _pendingBytes = null;
      });

      Navigator.pop(context, gespeicherterArtikel);
    } catch (e, st) {
      _logger.e(
        'Speichern (Web) fehlgeschlagen:',
        error: e,
        stackTrace: st,
      );
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

    _logger.i('Speichern (Mobile) gestartet');

    final hasNewImage =
        _bildPfad != null && _bildPfad != widget.artikel.bildPfad;

    _logger.d('Neues Bild vorhanden: $hasNewImage – Pfad: $_bildPfad');

    final artikelMitAenderungen = widget.artikel.copyWith(
      menge: _menge,
      ort: _ortController.text,
      fach: _fachController.text,
      beschreibung: _beschreibungController.text,
      bildPfad: _bildPfad ?? widget.artikel.bildPfad,
      aktualisiertAm: DateTime.now().toUtc(),
    );

    try {
      await _db.updateArtikel(artikelMitAenderungen);
      _logger.i(
        'Artikel in DB gespeichert: ${artikelMitAenderungen.name}',
      );

      if (hasNewImage) {
        _logger.d('Starte PocketBase Bild-Upload im Hintergrund...');
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

      _logger.i('Speichern abgeschlossen – kehre zurück');
      Navigator.pop(context, artikelMitAenderungen);
    } catch (e, st) {
      _logger.e(
        'Speichern (Mobile) fehlgeschlagen',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
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
          http.MultipartFile.fromBytes(
            'bild',
            bytes,
            filename: filename,
          ),
        ],
      );

      await _db.markSynced(uuid, recordId);
      _logger.i('Bild zu PocketBase hochgeladen: $filename');
    } catch (e, st) {
      _logger.e(
        'PocketBase Bild-Upload fehlgeschlagen:',
        error: e,
        stackTrace: st,
      );
    }
  }

  // ==================== LÖSCHEN ====================

  // M-004: _loeschen() setzt _isDeleting und zeigt AppLoadingOverlay.
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

    // M-004: Loading-State setzen
    setState(() => _isDeleting = true);

    try {
      // M-012: Anhänge zuerst löschen
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
      Navigator.pop(context, null);
    } catch (e, st) {
      _logger.e('Löschen fehlgeschlagen:', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Löschen fehlgeschlagen: $e')),
        );
      }
    } finally {
      // M-004: Loading-State zurücksetzen
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // ==================== PDF ====================

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
      _logger.i(
        'PDF-Export gestartet für Artikel: ${widget.artikel.name}',
      );

      final pdfService = PdfService();

      final aktuellerArtikel = widget.artikel.copyWith(
        menge: _menge,
        ort: _ortController.text,
        fach: _fachController.text,
        beschreibung: _beschreibungController.text,
        bildPfad: _bildPfad ?? widget.artikel.bildPfad,
        aktualisiertAm: DateTime.now().toUtc(),
      );

      final pdfFile =
          await pdfService.generateArtikelDetailPdf(aktuellerArtikel);

      if (pdfFile != null) {
        _logger.i('Artikel-PDF erstellt: $pdfFile');

        if (!mounted) return;

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
                      duration: Duration(seconds: 3),
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
            SnackBar(
              content: Text('Fehler beim PDF-Export: $e'),
              duration: const Duration(seconds: 4),
            ),
          );
      }
    }
  }

  // ==================== MENGEN-STEUERUNG ====================

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

  // ==================== VOLLBILD ====================

  /// M-011: Vollbild-Overlay mit InteractiveViewer.
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
            title: Text(widget.artikel.name),
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

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final artikel = widget.artikel;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // M-004: Interaktion während Loading sperren
    final bool isBlocked = _isSaving || _isDeleting;

    return PopScope(
      canPop: !(_isEditing && _hasChanged),
      onPopInvokedWithResult: (didPop, _) async {
        if (!mounted) return;
        if (didPop) return;

        final nav = Navigator.of(context);

        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Änderungen verwerfen?'),
            content: const Text(
              'Ungespeicherte Änderungen gehen verloren.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Weiter bearbeiten'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Verwerfen'),
              ),
            ],
          ),
        );

        if (discard != true) return;
        nav.pop();
      },

      // M-004: Stack für AppLoadingOverlay
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: Text(widget.artikel.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  // M-004: während Loading deaktiviert
                  onPressed: isBlocked ? null : _generateArtikelDetailPdf,
                  tooltip: 'Artikel als PDF exportieren',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  // M-004: während Loading oder Bearbeitung deaktiviert
                  onPressed: (_isEditing || isBlocked) ? null : _loeschen,
                  tooltip: _isEditing
                      ? 'Erst speichern oder Bearbeitung abbrechen'
                      : 'Artikel löschen',
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConfig.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
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
                  const SizedBox(height: AppConfig.spacingMedium),

                  TextField(
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
                  const SizedBox(height: AppConfig.spacingXLarge - 4), // 20

                  Row(
                    children: [
                      Text('Menge: $_menge'),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed:
                            (_isEditing && !isBlocked)
                                ? _mengeErhoehen
                                : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed:
                            (_isEditing && !isBlocked)
                                ? _mengeVerringern
                                : null,
                      ),
                      Text(
                        'Art.-Nr.: ${artikel.artikelnummer ?? "-"}',
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConfig.spacingXLarge - 4), // 20

                  TextField(
                    controller: _beschreibungController,
                    enabled: _isEditing && !isBlocked,
                    decoration: InputDecoration(
                      labelText: 'Beschreibung',
                      filled: true,
                      fillColor: _isEditing
                          ? colorScheme.surface
                          : colorScheme.surfaceContainerLow,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppConfig.spacingXLarge - 4), // 20

                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed:
                            (_isEditing && !isBlocked)
                                ? _pickImageFile
                                : null,
                        icon: const Icon(Icons.image),
                        label: const Text('Bild wählen'),
                      ),
                      if (ImagePickerService.isCameraAvailable) ...[
                        const SizedBox(width: AppConfig.spacingMedium),
                        FilledButton.tonalIcon(
                          onPressed:
                              (_isEditing && !isBlocked)
                                  ? _pickImageCamera
                                  : null,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Kamera'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppConfig.spacingXLarge - 4), // 20

                  // M-012: Anhänge-Sektion
                  AnhaengeSektion(
                    artikelUuid: widget.artikel.uuid,
                    anhangCount: _anhangCount,
                    onCountChanged: (count) =>
                        setState(() => _anhangCount = count),
                  ),
                  const SizedBox(height: AppConfig.spacingXLarge - 4), // 20

                  // M-011: Zentrales Bild-Widget mit Vollbild-Tap
                  if (_isLoadingRemoteBild)
                    Container(
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
                    )
                  else
                    ArtikelDetailBild(
                      artikel: artikel,
                      pendingBytes: _pendingBytes,
                      remoteBildUrl: _remoteBildUrl,
                      onTap: _zeigeBildVollbild,
                    ),

                  const SizedBox(height: AppConfig.spacingXLarge - 4), // 20

                  // M-004: AppLoadingButton ersetzt ElevatedButton
                  AppLoadingButton(
                    isLoading: _isSaving,
                    onPressed: !_isEditing
                        ? _enableEdit
                        : (_hasChanged ? _speichern : null),
                    label: !_isEditing
                        ? 'Ändern'
                        : (_hasChanged
                            ? 'Speichern'
                            : 'Speichern (inaktiv)'),
                    loadingLabel: 'Speichern...',
                    icon: !_isEditing ? Icons.edit : Icons.save,
                  ),
                ],
              ),
            ),
          ),

          // M-004: Overlay beim Speichern
          if (_isSaving)
            const AppLoadingOverlay(message: 'Speichern...'),

          // M-004: Overlay beim Löschen
          if (_isDeleting)
            const AppLoadingOverlay(message: 'Löschen...'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// M-012: AnhaengeSektion
// ---------------------------------------------------------------------------

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
  Widget build(BuildContext context) {
    return Row(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.attach_file),
          label: Text(
            anhangCount == 0 ? 'Anhänge' : 'Anhänge ($anhangCount)',
          ),
          onPressed: () => zeigeAnhaengeSheet(context),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// M-012: AnhaengeSheet
// ---------------------------------------------------------------------------

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
          // Handle + Header
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

          // Liste
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