//lib/screen/artikel_detail_screen.dart

//Anzeige aller relevanten Felder
//Mengenverwaltung (erhöhen/verringern)
//Bearbeitung der Beschreibung
//Löschen des Artikels
//Speichern der Änderungen in SQLite


import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/artikel_model.dart';
import '../services/artikel_db_service.dart';
import '../services/pdf_service.dart';
import '../services/app_log_service.dart';
import '../services/image_picker.dart';
import '../services/nextcloud_credentials.dart';
import '../services/nextcloud_webdav_client.dart';
import '_dokumente_button.dart';

class ArtikelDetailScreen extends StatefulWidget {
  final Artikel artikel;

  const ArtikelDetailScreen({super.key, required this.artikel});

  @override
  // ignore: library_private_types_in_public_api
  _ArtikelDetailScreenState createState() => _ArtikelDetailScreenState();
}

class _ArtikelDetailScreenState extends State<ArtikelDetailScreen> {
  late TextEditingController _beschreibungController;
  late TextEditingController _ortController;
  late TextEditingController _fachController;
  late int _menge;
  bool _isEditing = false;   // steuert ob Felder aktiv sind
  bool _hasChanged = false;  // ob Änderungen gemacht wurden

  String? _bildPfad;
  Uint8List? _bildBytes;

  @override
  void initState() {
    super.initState();
    _beschreibungController = TextEditingController(text: widget.artikel.beschreibung)
      ..addListener(_onChanged);
    _ortController = TextEditingController(text: widget.artikel.ort)
      ..addListener(_onChanged);
    _fachController = TextEditingController(text: widget.artikel.fach)
      ..addListener(_onChanged);
    _menge = widget.artikel.menge;
    _bildPfad = widget.artikel.bildPfad.isNotEmpty ? widget.artikel.bildPfad : null;
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

  Future<void> _pickImageFile() async {
    final picked = await ImagePickerService.pickImageFile(context);
    if (picked.pfad == null && picked.bytes == null) return;
    setState(() {
      _bildPfad = picked.pfad;
      _bildBytes = picked.bytes;
      _hasChanged = true;
    });
  }

  Future<void> _pickImageCamera() async {
    final picked = await ImagePickerService.pickImageCamera(context);
    if (picked.pfad == null && picked.bytes == null) return;
    setState(() {
      _bildPfad = picked.pfad;
      _bildBytes = picked.bytes;
      _hasChanged = true;
    });
  }

  Future<String?> _persistSelectedImage({
    required int artikelId,
    required String artikelName,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'images'));
    await imagesDir.create(recursive: true);

    final nameSlug = _slug(artikelName.isEmpty ? 'artikel' : artikelName);
    final fileName = '${artikelId}_$nameSlug.jpg';
    final targetPath = p.join(imagesDir.path, fileName);

    if (_bildBytes != null) {
      final file = File(targetPath);
      await file.writeAsBytes(_bildBytes!);
      return targetPath;
    }

    if (_bildPfad != null) {
      final sourceFile = File(_bildPfad!);
      if (await sourceFile.exists()) {
        await sourceFile.copy(targetPath);
        return targetPath;
      }
    }

    return null;
  }

  Future<String?> _uploadImageToNextcloud({
    required String localPath,
    required int artikelId,
    required String artikelName,
  }) async {
    final creds = await NextcloudCredentialsStore().read();
    final dbService = ArtikelDbService();

    if (creds == null) {
      await dbService.updateRemoteBildPfad(artikelId, '');
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hinweis: Nextcloud nicht konfiguriert – Bild nicht hochgeladen'),
        ),
      );
      return null;
    }

    final client = NextcloudWebDavClient(
      NextcloudConfig(
        serverBase: creds.server,
        username: creds.user,
        appPassword: creds.appPw,
        baseRemoteFolder: creds.baseFolder,
      ),
    );

    final remotePath = (widget.artikel.remoteBildPfad?.isNotEmpty ?? false)
        ? widget.artikel.remoteBildPfad!
        : _buildRemotePath(
            baseFolder: client.config.baseRemoteFolder,
            artikelId: artikelId,
            artikelName: artikelName,
          );

    try {
      await client.uploadFileNew(
        localPath: localPath,
        remoteRelativePath: remotePath,
      );

      await dbService.updateRemoteBildPfad(artikelId, remotePath);

      if (!mounted) return remotePath;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bild erfolgreich zu Nextcloud hochgeladen')),
      );
      return remotePath;
    } on WebDavException catch (e) {
      await dbService.updateRemoteBildPfad(artikelId, '');
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload fehlgeschlagen: ${e.message}')),
      );
      return null;
    } catch (e) {
      await dbService.updateRemoteBildPfad(artikelId, '');
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload-Fehler: $e')),
      );
      return null;
    }
  }

  String _buildRemotePath({
    required String baseFolder,
    required int artikelId,
    required String artikelName,
  }) {
    final nameSlug = _slug(artikelName.isEmpty ? 'artikel' : artikelName);
    final fileName = '$artikelId-$nameSlug.jpg';
    return p.posix.join(baseFolder, fileName);
  }

  String _slug(String input) {
    final lower = input.toLowerCase();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return replaced.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Future<void> _speichern() async {
    final artikelId = widget.artikel.id;
    if (artikelId == null) return;

    final hasNewImage =
        _bildBytes != null || (_bildPfad != null && _bildPfad != widget.artikel.bildPfad);

    String? localImagePath =
        widget.artikel.bildPfad.isNotEmpty ? widget.artikel.bildPfad : null;

    if (hasNewImage) {
      localImagePath = await _persistSelectedImage(
        artikelId: artikelId,
        artikelName: widget.artikel.name,
      );

      if (localImagePath == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bild konnte nicht gespeichert werden')),
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
      aktualisiertAm: DateTime.now(),
    );

    try {
      await ArtikelDbService().updateArtikel(artikelMitAenderungen);

      String? remotePfad = widget.artikel.remoteBildPfad;
      if (hasNewImage) {
        if (localImagePath != null) {
          remotePfad = await _uploadImageToNextcloud(
                localPath: localImagePath,
                artikelId: artikelId,
                artikelName: artikelMitAenderungen.name,
              ) ?? '';
        } else {
          remotePfad = '';
          await ArtikelDbService().updateRemoteBildPfad(artikelId, remotePfad);
        }
      }

      final gespeicherterArtikel = artikelMitAenderungen.copyWith(remoteBildPfad: remotePfad);

      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _hasChanged = false;
        _bildBytes = null;
        _bildPfad = gespeicherterArtikel.bildPfad.isNotEmpty
            ? gespeicherterArtikel.bildPfad
            : null;
      });

      Navigator.pop(context, gespeicherterArtikel);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
    }
  }

  Future<void> _loeschen() async {
    if (widget.artikel.id != null) {
      await ArtikelDbService().deleteArtikel(widget.artikel.id!);
      if (!mounted) return;
      Navigator.pop(context, null); // 👉 null zurückgeben, um Löschung anzuzeigen
    }
  }

  Future<void> _generateArtikelDetailPdf() async {
    try {
      await AppLogService().log('PDF-Export gestartet für Artikel: ${widget.artikel.name}');
      final pdfService = PdfService();
      
      // Erstelle ein aktuelles Artikel-Objekt mit den möglichen Änderungen
      final aktuellerArtikel = Artikel(
        id: widget.artikel.id,
        name: widget.artikel.name,
        menge: _menge,
        ort: _ortController.text,
        fach: _fachController.text,
        beschreibung: _beschreibungController.text,
        bildPfad: _bildPfad ?? widget.artikel.bildPfad,
        erstelltAm: widget.artikel.erstelltAm,
        aktualisiertAm: DateTime.now(),
        remoteBildPfad: widget.artikel.remoteBildPfad,
      );

      final pdfFile = await pdfService.generateArtikelDetailPdf(aktuellerArtikel);
      
      if (pdfFile != null) {
        await AppLogService().log('Artikel-PDF erfolgreich erstellt: ${pdfFile.path}');
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF erfolgreich erstellt!\nPfad: ${pdfFile.path}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Öffnen',
              onPressed: () async {
                final success = await PdfService.openPdf(pdfFile.path);
                if (!success) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PDF konnte nicht geöffnet werden'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
          ),
        );
      } else {
        await AppLogService().log('Artikel-PDF-Export abgebrochen: Benutzer hat Dialog geschlossen');
      }
    } catch (e, stack) {
      await AppLogService().logError('Fehler beim Artikel-PDF-Export: $e', stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim PDF-Export: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _mengeErhoehen() {
    if (_isEditing) {
      setState(() {
        _menge++;
        _hasChanged = true;
      });
    }
  }

  void _mengeVerringern() {
    if (_isEditing) {
      setState(() {
        if (_menge > 0) _menge--;
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

  void _zeigeBildVollbild(String bildPfad) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: InteractiveViewer(
            child: Image.file(File(bildPfad), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final artikel = widget.artikel;

    return Scaffold(
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
            onPressed: _loeschen,
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ort bearbeiten
            TextField(
              controller: _ortController,
              enabled: _isEditing,
              decoration: InputDecoration(
                labelText: 'Ort',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: _isEditing ? Colors.white : Colors.grey[100],
                labelStyle: const TextStyle(color: Colors.black), // Label immer schwarz
              ),
              style: const TextStyle(color: Colors.black), // Text immer schwarz
            ),
            const SizedBox(height: 12),

            // Fach bearbeiten
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

            // Mengensteuerung
            Row(
              children: [
                Text('Menge: $_menge'),
                IconButton(icon: const Icon(Icons.add), onPressed: _mengeErhoehen),
                IconButton(icon: const Icon(Icons.remove), onPressed: _mengeVerringern),
                Text(
                 'Art.-Nr.: ${artikel.id ?? "-"}',
                 style: const TextStyle(fontSize: 12),
                )
              ],
            ),
            const SizedBox(height: 20),

            // Beschreibung bearbeiten            
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

            // Bild ändern/hinzufügen
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _isEditing ? _pickImageFile : null,
                  icon: const Icon(Icons.image),
                  label: const Text('Bild wählen'),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: _isEditing ? _pickImageCamera : null,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Kamera'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Zusätzliche Dokumente Button
            DokumenteButton(artikelId: artikel.id),
            const SizedBox(height: 20),
            if (_bildBytes != null) ...[
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_bildBytes!, fit: BoxFit.cover),
                ),
              ),
            ] else if (_bildPfad != null && File(_bildPfad!).existsSync()) ...[
              GestureDetector(
                onTap: () => _zeigeBildVollbild(_bildPfad!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_bildPfad!),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ] else ...[
              Container(
                height: 200,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image_not_supported,
                    size: 48, color: Colors.grey),
              ),
            ],

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: !_isEditing
                  ? _enableEdit
                  : (_hasChanged ? _speichern : null),
              child: Text(!_isEditing
                  ? 'Ändern'
                  : (_hasChanged ? 'Speichern' : 'Speichern (inaktiv)')),
            ),
          ],
        ),
      ),
    );
  }
}
