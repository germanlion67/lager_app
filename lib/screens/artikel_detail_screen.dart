//lib/screen/artikel_detail_screen.dart

//Anzeige aller relevanten Felder
//Mengenverwaltung (erhöhen/verringern)
//Bearbeitung der Beschreibung
//Löschen des Artikels
//Speichern der Änderungen in SQLite


import 'dart:io';
import 'package:flutter/material.dart';
import '../models/artikel_model.dart';
import '../services/artikel_db_service.dart';

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

  @override
  void initState() {
    super.initState();
    _beschreibungController = TextEditingController(text: widget.artikel.beschreibung);
    _ortController = TextEditingController(text: widget.artikel.ort);
    _fachController = TextEditingController(text: widget.artikel.fach);
    _menge = widget.artikel.menge;
  }

  @override
  void dispose() {
    _beschreibungController.dispose();
    _ortController.dispose();
    _fachController.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    final aktualisierterArtikel = Artikel(
      id: widget.artikel.id,
      name: widget.artikel.name,
      menge: _menge,
      ort: _ortController.text,
      fach: _fachController.text,
      beschreibung: _beschreibungController.text,
      bildPfad: widget.artikel.bildPfad,
      remoteBildPfad:widget.artikel.remoteBildPfad,
      erstelltAm: widget.artikel.erstelltAm,
      aktualisiertAm: DateTime.now(),
    );

    await ArtikelDbService().updateArtikel(aktualisierterArtikel);
    if (!mounted) return;
    Navigator.pop(context, aktualisierterArtikel); // 👉 Artikel zurückgeben
  }

  Future<void> _loeschen() async {
    if (widget.artikel.id != null) {
      await ArtikelDbService().deleteArtikel(widget.artikel.id!);
      if (!mounted) return;
      Navigator.pop(context, 'deleted'); // 👉 spezielles Signal für Löschen
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
              decoration: const InputDecoration(
                labelText: 'Ort',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Fach bearbeiten
            TextField(
              controller: _fachController,
              decoration: const InputDecoration(
                labelText: 'Fach',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Mengensteuerung
            Row(
              children: [
                Text('Menge: $_menge'),
                IconButton(icon: const Icon(Icons.add), onPressed: _mengeErhoehen),
                IconButton(icon: const Icon(Icons.remove), onPressed: _mengeVerringern),
              ],
            ),
            const SizedBox(height: 20),

            // Beschreibung bearbeiten            
            TextField(
              controller: _beschreibungController,
              decoration: const InputDecoration(labelText: 'Beschreibung'),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

             // Artikelbild
            if (artikel.bildPfad.isNotEmpty && File(artikel.bildPfad).existsSync())
              GestureDetector(
                onTap: () => _zeigeBildVollbild(artikel.bildPfad),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(artikel.bildPfad),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
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

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _speichern,
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }
}
