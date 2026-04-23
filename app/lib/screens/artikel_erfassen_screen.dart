// lib/screens/artikel_erfassen_screen.dart
//
// v0.7.8: Punkt 3 — textCapitalization: sentences für Name, Beschreibung, Ort, Fach
//         Punkt 4 — FocusNode für Menge: Vorauswahl beim Fokus
//         Punkt 6 — Bild-Buttons als IconButton statt FilledButton.tonalIcon

import 'dart:async' show unawaited;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/artikel_model.dart';
import '../services/pocketbase_service.dart';
import '../services/artikel_db_service.dart';
import '../services/app_log_service.dart';
import '../services/image_picker.dart';
import '../utils/image_processing_utils.dart';


import 'artikel_erfassen_io.dart'
    if (dart.library.html) 'artikel_erfassen_stub.dart' as platform;

class ArtikelErfassenScreen extends StatefulWidget {
  const ArtikelErfassenScreen({
    super.key,
    this.initialArtikelnummer,
  });

  final int? initialArtikelnummer;

  @override
  State<ArtikelErfassenScreen> createState() => _ArtikelErfassenScreenState();
}

class _ArtikelErfassenScreenState extends State<ArtikelErfassenScreen> {
  final _logger = AppLogService.logger;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _beschreibungCtrl = TextEditingController();
  final _ortCtrl = TextEditingController();
  final _fachCtrl = TextEditingController();
  final _mengeCtrl = TextEditingController(text: '0');
  final _artikelnummerCtrl = TextEditingController();

  // v0.7.8 Punkt 4: FocusNode für Menge-Feld
  final FocusNode _mengeFocus = FocusNode();

  String? _bildPfad;
  Uint8List? _bildBytes;
  String? _bildDateiname;

  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  bool _isInitializing = true;  // verhindert Dirty-State durch Initialwerte

  int? _suggestedArtikelnummer;

  late final ArtikelDbService _db;
  late final PocketBaseService _pbService;

  // ==================== INIT & DISPOSE ====================

  @override
  void initState() {
    super.initState();
    _db = ArtikelDbService();
    _pbService = PocketBaseService();

    _nameCtrl.addListener(_markDirty);
    _beschreibungCtrl.addListener(_markDirty);
    _ortCtrl.addListener(_markDirty);
    _fachCtrl.addListener(_markDirty);
    _mengeCtrl.addListener(_markDirty);
    _artikelnummerCtrl.addListener(_markDirty);

    // v0.7.8 Punkt 4: Beim Fokus den gesamten Inhalt des Menge-Felds markieren
    _mengeFocus.addListener(() {
      if (_mengeFocus.hasFocus) {
        _mengeCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _mengeCtrl.text.length,
        );
      }
    });

    if (widget.initialArtikelnummer != null) {
      _suggestedArtikelnummer = widget.initialArtikelnummer;
      _artikelnummerCtrl.text = widget.initialArtikelnummer.toString();
      _hasUnsavedChanges = false;
      _isInitializing = false;
    } else {
      _initArtikelnummer();
    }
  }

  Future<void> _initArtikelnummer() async {
    final next = await _getNextArtikelnummer();
    if (!mounted) return;

    setState(() {
      _suggestedArtikelnummer = next;
      _artikelnummerCtrl.text = next.toString();
      _hasUnsavedChanges = false;
      _isInitializing = false;
    });
  }

  void _markDirty() {
    if (_isInitializing) return;
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _beschreibungCtrl.dispose();
    _ortCtrl.dispose();
    _fachCtrl.dispose();
    _mengeCtrl.dispose();
    _artikelnummerCtrl.dispose();
    // v0.7.8 Punkt 4: FocusNode disposen
    _mengeFocus.dispose();
    super.dispose();
  }

  // ==================== HILFSFUNKTIONEN ====================

  bool _isExternalPath(String pfad) {
    return !pfad.contains('/images/');
  }

  void _resetBildState() {
    setState(() {
      _bildPfad = null;
      _bildBytes = null;
      _bildDateiname = null;
    });
  }

  Future<int> _getNextArtikelnummer() async {
    const int startNummer = 1000;
    int maxNummer = startNummer - 1;

    if (!kIsWeb) {
      try {
        final localMax = await _db.getMaxArtikelnummer();
        if (localMax != null && localMax > maxNummer) {
          maxNummer = localMax;
        }
      } catch (e, st) {
        _logger.w(
          'Lokale Max-Artikelnummer konnte nicht gelesen werden',
          error: e,
          stackTrace: st,
        );
      }
    }

    if (_pbService.hasClient) {
      try {
        final result = await _pbService.client
            .collection('artikel')
            .getList(
              page: 1,
              perPage: 1,
              sort: '-artikelnummer',
              fields: 'artikelnummer',
            );
        if (result.items.isNotEmpty) {
          final remoteMax =
              result.items.first.data['artikelnummer'] as int? ?? 0;
          if (remoteMax > maxNummer) maxNummer = remoteMax;
        }
      } catch (e, st) {
        _logger.w(
          'PocketBase Max-Artikelnummer konnte nicht gelesen werden',
          error: e,
          stackTrace: st,
        );
      }
    }

    return maxNummer + 1;
  }

  // ==================== VALIDIERUNG ====================

  Future<bool> _isDuplicateKombination({
    required String name,
    required String ort,
    required String fach,
  }) async {
    if (!kIsWeb) {
      try {
        final exists = await _db.existsKombination(
          name: name,
          ort: ort,
          fach: fach,
        );
        if (exists) return true;
      } catch (e, st) {
        _logger.w(
          'Duplikat-Check (lokal) fehlgeschlagen',
          error: e,
          stackTrace: st,
        );
      }
    }

    if (_pbService.hasClient) {
      try {
        final filter =
            'name = "$name" && ort = "$ort" && fach = "$fach" && deleted = false';
        final result = await _pbService.client
            .collection('artikel')
            .getList(page: 1, perPage: 1, filter: filter);
        if (result.items.isNotEmpty) return true;
      } catch (e, st) {
        _logger.w(
          'Duplikat-Check (PocketBase) fehlgeschlagen',
          error: e,
          stackTrace: st,
        );
      }
    }

    return false;
  }

  Future<bool> _isArtikelnummerTaken(int nummer) async {
    if (nummer == _suggestedArtikelnummer) return false;

    if (!kIsWeb) {
      try {
        final exists = await _db.existsArtikelnummer(nummer);
        if (exists) return true;
      } catch (e, st) {
        _logger.w(
          'Artikelnummer-Check (lokal) fehlgeschlagen',
          error: e,
          stackTrace: st,
        );
      }
    }

    if (_pbService.hasClient) {
      try {
        final result = await _pbService.client
            .collection('artikel')
            .getList(
              page: 1,
              perPage: 1,
              filter: 'artikelnummer = $nummer && deleted = false',
            );
        if (result.items.isNotEmpty) return true;
      } catch (e, st) {
        _logger.w(
          'Artikelnummer-Check (PocketBase) fehlgeschlagen',
          error: e,
          stackTrace: st,
        );
      }
    }

    return false;
  }

  // ==================== BILD AUSWAHL ====================

  Future<void> _pickImageFile() async {
    final picked = await ImagePickerService.pickImageFile(context);
    if (!mounted) return;
    if (!picked.hasImage) return;
    setState(() {
      _bildPfad = picked.pfad;
      _bildBytes = picked.bytes;
      _bildDateiname = picked.dateiname;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _pickImageCamera() async {
    if (!ImagePickerService.isCameraAvailable) return;
    final picked = await ImagePickerService.pickImageCamera(context);
    if (!mounted) return;
    if (!picked.hasImage) return;
    setState(() {
      _bildPfad = picked.pfad;
      _bildBytes = picked.bytes;
      _bildDateiname = picked.dateiname;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _cropImage() async {
    if (_bildBytes == null) return;
    final cropResult = await ImagePickerService.openCropDialog(
      context,
      _bildBytes,
    );
    if (!mounted) return;
    if (cropResult == null) return;

    final Uint8List? processedBytes;
    try {
      processedBytes = await ImageProcessingUtils.ensureTargetFormat(
        cropResult.bytes,
        crop: cropResult.cropped,
      );
    } catch (e, st) {
      _logger.e(
        '_cropImage: Bildverarbeitung fehlgeschlagen',
        error: e,
        stackTrace: st,
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _bildBytes = processedBytes ?? cropResult.bytes;
    });
  }

  // ==================== ABBRECHEN ====================

  Future<void> _handleCancel() async {
    if (!_hasUnsavedChanges) {
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Änderungen verwerfen?'),
        content: const Text(
          'Du hast bereits Daten eingegeben, die noch nicht gespeichert sind. '
          'Möchtest du das Formular wirklich verlassen und alle Eingaben verlieren?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Weiter bearbeiten'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Verwerfen'),
          ),
        ],
      ),
    );

    if (discard == true && mounted) Navigator.pop(context);
  }

  // ==================== SPEICHERN ====================

  Future<void> _save() async {
    _logger.d('_save() gestartet.');

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameCtrl.text.trim();
      final ort = _ortCtrl.text.trim();
      final fach = _fachCtrl.text.trim();
      final menge = int.tryParse(_mengeCtrl.text.trim()) ?? 0;
      final artikelnummer =
          int.tryParse(_artikelnummerCtrl.text.trim()) ??
          _suggestedArtikelnummer ??
          await _getNextArtikelnummer();

      final isDuplicate = await _isDuplicateKombination(
        name: name,
        ort: ort,
        fach: fach,
      );
      if (isDuplicate) {
        if (mounted) {
          _formKey.currentState?.validate();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Ein Artikel mit diesem Namen, Ort und Fach existiert bereits.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final isNrTaken = await _isArtikelnummerTaken(artikelnummer);
      if (isNrTaken) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Artikelnummer $artikelnummer ist bereits vergeben.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final artikel = Artikel(
        name: name,
        artikelnummer: artikelnummer,
        beschreibung: _beschreibungCtrl.text.trim(),
        ort: ort,
        fach: fach,
        menge: menge,
        bildPfad: '',
        remoteBildPfad: '',
        erstelltAm: DateTime.now(),
        aktualisiertAm: DateTime.now(),
      );

      _logger.d('Artikel-Objekt erstellt. kIsWeb: $kIsWeb');

      if (kIsWeb) {
        await _saveWeb(artikel);
      } else {
        await _saveMobile(artikel);
      }
    } catch (e, st) {
      _logger.e('Fehler beim Speichern:', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
      _logger.d('_isSaving auf false gesetzt. _save() beendet.');
    }
  }

  Future<void> _saveWeb(Artikel artikel) async {
    _logger.d('_saveWeb() gestartet.');
    final pb = _pbService.client;
    final body = artikel.toPocketBaseMap();

    if (_pbService.isAuthenticated && _pbService.currentUserId != null) {
      body['owner'] = _pbService.currentUserId;
    }

    final List<http.MultipartFile> files = [];
    if (_bildBytes != null && _bildDateiname != null) {
      files.add(
        http.MultipartFile.fromBytes(
          'bild',
          _bildBytes!,
          filename: _bildDateiname,
        ),
      );
    }

    final record = await pb.collection('artikel').create(
      body: body,
      files: files,
    );

    if (mounted) {
      setState(() => _hasUnsavedChanges = false);
      Navigator.of(context).pop(
        artikel.copyWith(
          remotePath: record.id,
          remoteBildPfad: record.data['bild'] as String? ?? '',
        ),
      );
    }
  }

  Future<void> _saveMobile(Artikel artikel) async {
    final artikelId = await _db.insertArtikel(artikel);

    final String? quellPfad =
        _bildPfad != null && _isExternalPath(_bildPfad!) ? _bildPfad : null;

    String? localImagePath;
    if (_bildBytes != null || quellPfad != null) {
      localImagePath = await platform.copyImageToLocalDirectory(
        bildBytes: _bildBytes,
        bildPfad: quellPfad,
        artikelId: artikelId,
        artikelName: _nameCtrl.text.trim(),
      );

      if (localImagePath != null) {
        await _db.updateBildPfad(artikelId, localImagePath);
      }
    }

    if (localImagePath != null || _bildBytes != null) {
      unawaited(
        _uploadImageToPocketBase(
          artikel: artikel,
          bildBytes: _bildBytes,
          bildDateiname: _bildDateiname,
          localImagePath: localImagePath,
        ),
      );
    }

    _resetBildState();

    if (mounted) {
      setState(() => _hasUnsavedChanges = false);
      Navigator.of(context).pop(
        artikel.copyWith(
          id: artikelId,
          bildPfad: localImagePath ?? '',
          uuid: artikel.uuid,
        ),
      );
    }
  }

  Future<void> _uploadImageToPocketBase({
    required Artikel artikel,
    Uint8List? bildBytes,
    String? bildDateiname,
    String? localImagePath,
  }) async {
    try {
      final pb = _pbService.client;
      final filter = 'uuid = "${artikel.uuid}"';
      final list = await pb.collection('artikel').getList(filter: filter);
      if (list.items.isEmpty) return;

      final recordId = list.items.first.id;

      final Uint8List bytes;
      final String filename;

      if (bildBytes != null) {
        bytes = bildBytes;
        filename = bildDateiname ?? 'bild.jpg';
      } else if (localImagePath != null) {
        bytes = await platform.readFileBytes(localImagePath);
        filename = platform.getBasename(localImagePath);
      } else {
        return;
      }

      await pb.collection('artikel').update(
        recordId,
        files: [
          http.MultipartFile.fromBytes('bild', bytes, filename: filename),
        ],
      );

      await _db.markSynced(artikel.uuid, recordId);
      _logger.i('Bild zu PocketBase hochgeladen: $filename');
    } catch (e, st) {
      _logger.e(
        'PocketBase Bild-Upload fehlgeschlagen:',
        error: e,
        stackTrace: st,
      );
    }
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleCancel();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Neuen Artikel erfassen')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppConfig.spacingLarge),
              children: [
                // ── Name ──────────────────────────────────────
                // v0.7.8 Punkt 3: textCapitalization ergänzt
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                    helperText: 'Pflichtfeld',
                  ),
                  maxLength: AppConfig.inputMaxLengthName,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Bitte einen Namen eingeben';
                    }
                    if (v.trim().length < 2) {
                      return 'Name muss mindestens 2 Zeichen lang sein';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppConfig.spacingMedium),

                // ── Beschreibung ───────────────────────────────
                // v0.7.8 Punkt 3: textCapitalization ergänzt
                TextFormField(
                  controller: _beschreibungCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Beschreibung',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  maxLength: AppConfig.inputMaxLengthBeschreibung,
                ),
                const SizedBox(height: AppConfig.spacingMedium),

                // ── Ort ───────────────────────────────────────
                // v0.7.8 Punkt 3: textCapitalization ergänzt
                TextFormField(
                  controller: _ortCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Ort *',
                    border: OutlineInputBorder(),
                    helperText: 'Pflichtfeld',
                  ),
                  maxLength: AppConfig.inputMaxLengthOrt,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Bitte einen Ort eingeben';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppConfig.spacingMedium),

                // ── Fach ──────────────────────────────────────
                // v0.7.8 Punkt 3: textCapitalization ergänzt
                TextFormField(
                  controller: _fachCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Fach *',
                    border: OutlineInputBorder(),
                    helperText: 'Pflichtfeld',
                  ),
                  maxLength: AppConfig.inputMaxLengthFach,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Bitte ein Fach eingeben';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppConfig.spacingMedium),

                // ── Menge ─────────────────────────────────────
                // v0.7.8 Punkt 4: focusNode ergänzt
                TextFormField(
                  controller: _mengeCtrl,
                  focusNode: _mengeFocus,
                  decoration: const InputDecoration(
                    labelText: 'Menge',
                    border: OutlineInputBorder(),
                    helperText: 'Nur positive Ganzzahlen (≥ 0)',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Bitte eine Menge eingeben';
                    }
                    final n = int.tryParse(v.trim());
                    if (n == null) return 'Bitte eine gültige Zahl eingeben';
                    if (n < 0) return 'Menge darf nicht negativ sein';
                    if (n > AppConfig.inputMaxMenge) {
                      return 'Menge darf maximal ${AppConfig.inputMaxMenge} betragen';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConfig.spacingMedium),

                // ── Artikelnummer ─────────────────────────────
                // Keine textCapitalization — numerisches Feld
                TextFormField(
                  controller: _artikelnummerCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Artikelnummer',
                    border: OutlineInputBorder(),
                    helperText: 'Automatisch vergeben — kann geändert werden',
                    prefixIcon: Icon(Icons.tag),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Bitte eine Artikelnummer eingeben';
                    }
                    final n = int.tryParse(v.trim());
                    if (n == null) {
                      return 'Bitte eine gültige Zahl eingeben';
                    }
                    if (n < 1000) {
                      return 'Artikelnummer muss mindestens 1000 sein';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConfig.spacingMedium),

                // ── Bild-Auswahl ──────────────────────────────
                // v0.7.8 Punkt 6: IconButton statt FilledButton.tonalIcon
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image),
                      tooltip: 'Bilddatei wählen',
                      onPressed: _pickImageFile,
                    ),
                    if (ImagePickerService.isCameraAvailable)
                      IconButton(
                        icon: const Icon(Icons.camera_alt),
                        tooltip: 'Kamera',
                        onPressed: _pickImageCamera,
                      ),
                    const SizedBox(width: AppConfig.spacingSmall),
                    Expanded(
                      child: Text(
                        _bildDateiname ?? 'Keine Datei ausgewählt',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),

                if (_bildBytes != null) ...[
                  const SizedBox(height: AppConfig.spacingMedium),
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppConfig.borderRadiusMedium,
                      ),
                      child: Image.memory(_bildBytes!, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: AppConfig.spacingSmall),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _cropImage,
                      icon: const Icon(Icons.crop),
                      label: const Text('Zuschneiden'),
                    ),
                  ),
                ],

                const SizedBox(height: AppConfig.spacingLarge),

                // ── Buttons ───────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : _handleCancel,
                        child: const Text('Abbrechen'),
                      ),
                    ),
                    const SizedBox(width: AppConfig.spacingMedium),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: AppConfig.iconSizeSmall,
                                height: AppConfig.iconSizeSmall,
                                child: CircularProgressIndicator(
                                  strokeWidth: AppConfig.strokeWidthMedium,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Speichern'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}