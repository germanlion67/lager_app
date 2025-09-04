//lib/screen/artikel_detail_screen.dart

//Anzeige aller relevanten Felder
//Mengenverwaltung (erhöhen/verringern)
//Bearbeitung der Beschreibung
//Löschen des Artikels
//Speichern der Änderungen in SQLite



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
  late int _menge;

  @override
  void initState() {
    super.initState();
    _beschreibungController = TextEditingController(text: widget.artikel.beschreibung);
    _menge = widget.artikel.menge;
  }

  Future<void> _speichern() async {
    final aktualisierterArtikel = Artikel(
      id: widget.artikel.id,
      name: widget.artikel.name,
      menge: _menge,
      ort: widget.artikel.ort,
      fach: widget.artikel.fach,
      beschreibung: _beschreibungController.text,
      bildPfad: widget.artikel.bildPfad,
      remoteBildPfad:widget.artikel.remoteBildPfad,
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
        title: Text(widget.artikel.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _loeschen,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ort: ${widget.artikel.ort} • Fach: ${widget.artikel.fach}'),
            if (widget.artikel.remoteBildPfad != null && widget.artikel.remoteBildPfad!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Remote-Bildpfad: ${widget.artikel.remoteBildPfad}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Menge: $_menge'),
                IconButton(icon: const Icon(Icons.add), onPressed: _mengeErhoehen),
                IconButton(icon: const Icon(Icons.remove), onPressed: _mengeVerringern),
              ],
            ),
            TextField(
              controller: _beschreibungController,
              decoration: const InputDecoration(labelText: 'Beschreibung'),
              maxLines: 3,
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
