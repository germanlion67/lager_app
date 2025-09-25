//lib/screen/artikel_detail_screen.dart

//Anzeige aller relevanten Felder
//Mengenverwaltung (erhöhen/verringern)
//Bearbeitung der Beschreibung
//Löschen des Artikels
//Speichern der Änderungen in SQLite


import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/artikel_model.dart';
import '../services/artikel_db_service.dart';
import '../services/image_picker.dart';

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
  String? _bildDateiname;

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
    _bildDateiname = widget.artikel.bildPfad.isNotEmpty ? widget.artikel.bildPfad.split('/').last : null;
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
    final picked = await ImagePickerService.pickImageFile();
    if (picked.pfad == null && picked.bytes == null) return;
    setState(() {
      _bildPfad = picked.pfad;
      _bildBytes = picked.bytes;
      _bildDateiname = picked.dateiname;
      _hasChanged = true;
    });
  }

  Future<void> _pickImageCamera() async {
    final picked = await ImagePickerService.pickImageCamera();
    if (picked.pfad == null && picked.bytes == null) return;
    setState(() {
      _bildPfad = picked.pfad;
      _bildBytes = picked.bytes;
      _bildDateiname = picked.dateiname;
      _hasChanged = true;
    });
  }

  Future<void> _speichern() async {
    final aktualisierterArtikel = Artikel(
      id: widget.artikel.id,
      name: widget.artikel.name,
      menge: _menge,
      ort: _ortController.text,
      fach: _fachController.text,
      beschreibung: _beschreibungController.text,
      bildPfad: _bildPfad ?? '',
      remoteBildPfad: widget.artikel.remoteBildPfad,
      erstelltAm: widget.artikel.erstelltAm,
      aktualisiertAm: DateTime.now(),
    );

    await ArtikelDbService().updateArtikel(aktualisierterArtikel);
    if (!mounted) return;
    setState(() {
      _isEditing = false;
      _hasChanged = false;
      // Nach dem Speichern: BildBytes zurücksetzen, damit das neue Bild aus Pfad geladen wird
      _bildBytes = null;
    });
    Navigator.pop(context, aktualisierterArtikel); // 👉 Artikel zurückgeben
  }

  Future<void> _loeschen() async {
    if (widget.artikel.id != null) {
      await ArtikelDbService().deleteArtikel(widget.artikel.id!);
      if (!mounted) return;
      Navigator.pop(context, null); // 👉 null zurückgeben, um Löschung anzuzeigen
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
                  label: const Text('Bilddatei wählen'),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: _isEditing ? _pickImageCamera : null,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Kamera'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _bildDateiname ?? 'Keine Datei ausgewählt',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (_bildBytes != null) ...[
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_bildBytes!, fit: BoxFit.cover),
                ),
              ),
            ] else if (_bildPfad != null && File(_bildPfad!).existsSync()) ...[
              const SizedBox(height: 12),
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
