import 'dart:io';
import 'package:flutter/material.dart';
import '../models/artikel_model.dart';
import '../services/artikel_db_service.dart';

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
              fontSize: highlight ? 22 : 16,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.black,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                fontSize: highlight ? 26 : 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class ArtikelDetailScreen extends StatefulWidget {
  final Artikel artikel;

  const ArtikelDetailScreen({super.key, required this.artikel});

  @override
  ArtikelDetailScreenState createState() => ArtikelDetailScreenState();
}

class ArtikelDetailScreenState extends State<ArtikelDetailScreen> {
  late TextEditingController _beschreibungController;
  late TextEditingController _ortController;
  late TextEditingController _fachController;
  late int _menge;
  bool _isEditing = false;   // steuert ob Felder aktiv sind
  bool _hasChanged = false;  // ob Änderungen gemacht wurden

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
    setState(() {
      _isEditing = false;
      _hasChanged = false;
    });
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
            !_isEditing
                ? Column(
                    children: [
                      InfoRow(label: "Ort", value: _ortController.text),
                      InfoRow(label: "Fach", value: _fachController.text),
                      InfoRow(label: "Menge", value: "$_menge", highlight: true),
                      InfoRow(label: "Art.-Nr.", value: "${artikel.id ?? '-'}"),
                    ],
                  )
                : Column(
                    children: [
                      TextField(
                        controller: _ortController,
                        enabled: _isEditing,
                        decoration: const InputDecoration(
                          labelText: 'Ort',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _fachController,
                        enabled: _isEditing,
                        decoration: const InputDecoration(
                          labelText: 'Fach',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Menge:',
                            style: TextStyle(fontSize: 20, color: Colors.black87),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$_menge',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          IconButton(icon: const Icon(Icons.add), onPressed: _mengeErhoehen),
                          IconButton(icon: const Icon(Icons.remove), onPressed: _mengeVerringern),
                        ],
                      ),
                      InfoRow(label: "Art.-Nr.", value: "${artikel.id ?? '-'}"),
                    ],
                  ),
            const SizedBox(height: 20),

            TextField(
              controller: _beschreibungController,
              enabled: _isEditing,
              decoration: const InputDecoration(labelText: 'Beschreibung'),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

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
