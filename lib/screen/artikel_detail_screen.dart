//lib/screen/artikel_detail_screen.dart

//Anzeige aller relevanten Felder
//Mengenverwaltung (erhöhen/verringern)
//Bearbeitung der Beschreibung
//Löschen des Artikels
//Speichern der Änderungen in SQLite



import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/artikel_model.dart';
import '../services/artikel_db_service.dart';

class ArtikelDetailScreen extends StatefulWidget {
  final Artikel artikel;

  const ArtikelDetailScreen({super.key, required this.artikel});

  @override
  _ArtikelDetailScreenState createState() => _ArtikelDetailScreenState();
}

class _ArtikelDetailScreenState extends State<ArtikelDetailScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _ortController;
  late TextEditingController _fachController;
  late TextEditingController _beschreibungController;
  late int _menge;
  String? _bildPfad;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.artikel.name);
    _ortController = TextEditingController(text: widget.artikel.ort);
    _fachController = TextEditingController(text: widget.artikel.fach);
    _beschreibungController = TextEditingController(text: widget.artikel.beschreibung);
    _menge = widget.artikel.menge;
    _bildPfad = widget.artikel.bildPfad;
  }

  Future<void> _bildAendern() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _bildPfad = pickedFile.path;
      });
    }
  }

  Future<void> _speichern() async {
    if (!_formKey.currentState!.validate()) return;

    final aktualisierterArtikel = Artikel(
      id: widget.artikel.id,
      name: _nameController.text,
      menge: _menge,
      ort: _ortController.text,
      fach: _fachController.text,
      beschreibung: _beschreibungController.text,
      bildPfad: _bildPfad,
      remoteBildPfad: widget.artikel.remoteBildPfad,
      erstelltAm: widget.artikel.erstelltAm,
      aktualisiertAm: DateTime.now(),
    );

    await ArtikelDbService().updateArtikel(aktualisierterArtikel);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _loeschen() async {
    if (widget.artikel.id != null) {
      await ArtikelDbService().deleteArtikel(widget.artikel.id!);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  void _mengeErhoehen() {
    setState(() {
      _menge++;
    });
  }

  void _mengeVerringern() {
    setState(() {
      if (_menge > 0) _menge--;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Artikel bearbeiten'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _loeschen,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.isEmpty ? 'Name darf nicht leer sein' : null,
                ),
                TextFormField(
                  controller: _ortController,
                  decoration: const InputDecoration(labelText: 'Ort'),
                  validator: (value) => value == null || value.isEmpty ? 'Ort darf nicht leer sein' : null,
                ),
                TextFormField(
                  controller: _fachController,
                  decoration: const InputDecoration(labelText: 'Fach'),
                  validator: (value) => value == null || value.isEmpty ? 'Fach darf nicht leer sein' : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('Menge: $_menge'),
                    IconButton(icon: const Icon(Icons.add), onPressed: _mengeErhoehen),
                    IconButton(icon: const Icon(Icons.remove), onPressed: _mengeVerringern),
                  ],
                ),
                TextFormField(
                  controller: _beschreibungController,
                  decoration: const InputDecoration(labelText: 'Beschreibung'),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                if (_bildPfad != null)
                  Image.file(File(_bildPfad!), height: 150),
                TextButton.icon(
                  icon: const Icon(Icons.image),
                  label: const Text('Bild ändern'),
                  onPressed: _bildAendern,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _speichern,
                  child: const Text('Speichern'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
