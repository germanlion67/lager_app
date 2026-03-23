// lib/screens/artikel_detail_screen.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart'; // ← NEU
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../models/artikel_model.dart';
import '../services/app_log_service.dart';
import '../services/artikel_db_service.dart';
import '../services/image_picker.dart';
import '../services/pocketbase_service.dart';
// M-011: Zentrales Bild-Widget
import '../widgets/artikel_bild_widget.dart';

import 'detail_screen_io.dart'
    if (dart.library.html) 'detail_screen_stub.dart' as platform;
import '../services/pdf_service_stub.dart'
    if (dart.library.io) '../services/pdf_service.dart';
import '_dokumente_button_stub.dart'
    if (dart.library.io) '_dokumente_button.dart';

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

  // M-011: pendingBytes für neu gewähltes (noch nicht gespeichertes) Bild
  Uint8List? _pendingBytes;
  String? _bildPfad;
  String? _remoteBildUrl;

  late final ArtikelDbService _db;
  late final PocketBaseService _pbService;

  bool _isLoadingRemoteBild = false;

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
    final picked = await ImagePickerService.pickImageFile(context);
    if (!picked.hasImage) return;
    setState(() {
      _pendingBytes = picked.bytes;
      _bildPfad = picked.pfad;
      _hasChanged = true;
    });
  }

  Future<void> _pickImageCamera() async {
    if (!ImagePickerService.isCameraAvailable) return;
    final picked = await ImagePickerService.pickImageCamera(context);
    if (!picked.hasImage) return;
    setState(() {
      _pendingBytes = picked.bytes;
      _bildPfad = picked.pfad;
      _hasChanged = true;
    });
  }

  // ==================== SPEICHERN ====================

  Future<void> _speichern() async {
    if (kIsWeb) {
      await _speichernWeb();
    } else {
      await _speichernMobile();
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
        files.add(http.MultipartFile.fromBytes(
          'bild',
          _pendingBytes!,
          filename: 'bild_${widget.artikel.uuid}.jpg',
        ),);
      }

      await _pbService.client
          .collection('artikel')
          .update(recordId, body: body, files: files);

      if (!mounted) return;

      final gespeicherterArtikel = widget.artikel.copyWith(
        menge: _menge,
        ort: _ortController.text,
        fach: _fachController.text,
        beschreibung: _beschreibungController.text,
        aktualisiertAm: now,
      );

      setState(() {
        _isEditing = false;
        _hasChanged = false;
        _pendingBytes = null;
      });

      Navigator.pop(context, gespeicherterArtikel);
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

    final hasNewImage = _pendingBytes != null ||
        (_bildPfad != null && _bildPfad != widget.artikel.bildPfad);

    String? localImagePath =
        widget.artikel.bildPfad.isNotEmpty ? widget.artikel.bildPfad : null;

    if (hasNewImage) {
      // M-011: onThumbnailSaved-Callback → thumbnailPfad in DB setzen
      localImagePath = await platform.persistSelectedImage(
        bildBytes: _pendingBytes,
        bildPfad: _bildPfad,
        artikelId: artikelId,
        artikelName: widget.artikel.name,
        onThumbnailSaved: (thumbPath) async {
          await _db.setThumbnailPfadByUuid(widget.artikel.uuid, thumbPath);
          _logger.d('Thumbnail gespeichert und in DB eingetragen: $thumbPath');
        },
      );

      if (localImagePath == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bild konnte nicht gespeichert werden'),
          ),
        );
        return;
      }
    }

    final artikelMitAenderungen = widget.artikel.copyWith(
      menge: _menge,
      ort: _ortController.text,
      fach: _fachController.text,
      beschreibung: _beschreibungController.text,
      bildPfad: localImagePath ?? '',
      aktualisiertAm: DateTime.now().toUtc(),
    );

    try {
      await _db.updateArtikel(artikelMitAenderungen);

      if (hasNewImage) {
        unawaited(
          _uploadImageToPocketBase(
            uuid: widget.artikel.uuid,
            localImagePath: localImagePath,
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

      Navigator.pop(context, artikelMitAenderungen);
    } catch (e, st) {
      _logger.e('Speichern (Mobile) fehlgeschlagen:', error: e, stackTrace: st);
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
          http.MultipartFile.fromBytes('bild', bytes, filename: filename),
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

  Future<void> _loeschen() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Artikel löschen?'),
        content:
            Text('Möchtest du "${widget.artikel.name}" wirklich löschen?'),
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

    if (confirm != true) return;
    if (!mounted) return;

    try {
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
      _logger.i('PDF-Export gestartet für Artikel: ${widget.artikel.name}');

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
    // Kein Bild vorhanden → nichts tun
    final hasPending = _pendingBytes != null;
    final hasRemote = kIsWeb && _remoteBildUrl != null;
    final hasLocal = !kIsWeb && _bildPfad != null;

    if (!hasPending && !hasRemote && !hasLocal) return;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogCtx) => GestureDetector(
        onTap: () => Navigator.pop(dialogCtx),
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              widget.artikel.name,
              style: const TextStyle(color: Colors.white),
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
    if (_pendingBytes != null) {
      return Image.memory(_pendingBytes!, fit: BoxFit.contain);
    }
    if (kIsWeb && _remoteBildUrl != null) {
      return CachedNetworkImage(
        imageUrl: _remoteBildUrl!,
        fit: BoxFit.contain,
        placeholder: (_, __) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (_, __, ___) =>
            const Icon(Icons.image_not_supported, color: Colors.white, size: 64),
      );
    }
    if (!kIsWeb && _bildPfad != null) {
      return platform.buildFileImage(_bildPfad!, fit: BoxFit.contain);
    }
    return const Icon(Icons.image_not_supported, color: Colors.white, size: 64);
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final artikel = widget.artikel;

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
            content: const Text('Ungespeicherte Änderungen gehen verloren.'),
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
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.artikel.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _generateArtikelDetailPdf,
              tooltip: 'Artikel als PDF exportieren',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _isEditing ? null : _loeschen,
              tooltip: _isEditing
                  ? 'Erst speichern oder Bearbeitung abbrechen'
                  : 'Artikel löschen',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _ortController,
                enabled: _isEditing,
                decoration: InputDecoration(
                  labelText: 'Ort',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: _isEditing ? Colors.white : Colors.grey[100],
                  labelStyle: const TextStyle(color: Colors.black),
                ),
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _fachController,
                enabled: _isEditing,
                decoration: InputDecoration(
                  labelText: 'Fach',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: _isEditing ? Colors.white : Colors.grey[100],
                  labelStyle: const TextStyle(color: Colors.black),
                ),
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Text('Menge: $_menge'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _isEditing ? _mengeErhoehen : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _isEditing ? _mengeVerringern : null,
                  ),
                  Text(
                    'Art.-Nr.: ${artikel.id ?? "-"}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _beschreibungController,
                enabled: _isEditing,
                decoration: InputDecoration(
                  labelText: 'Beschreibung',
                  filled: true,
                  fillColor: _isEditing ? Colors.white : Colors.grey[100],
                  labelStyle: const TextStyle(color: Colors.black),
                ),
                style: const TextStyle(color: Colors.black),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _isEditing ? _pickImageFile : null,
                    icon: const Icon(Icons.image),
                    label: const Text('Bild wählen'),
                  ),
                  if (ImagePickerService.isCameraAvailable) ...[
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: _isEditing ? _pickImageCamera : null,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Kamera'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              DokumenteButton(artikelId: artikel.id),
              const SizedBox(height: 20),

              // M-011: Zentrales Bild-Widget mit Vollbild-Tap
              if (_isLoadingRemoteBild)
                Container(
                  height: 200,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
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

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: !_isEditing
                    ? _enableEdit
                    : (_hasChanged ? _speichern : null),
                child: Text(
                  !_isEditing
                      ? 'Ändern'
                      : (_hasChanged ? 'Speichern' : 'Speichern (inaktiv)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}