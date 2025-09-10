//lib/screens/artikel_list_screen.dart

// Diese Seite bietet:
// Suche nach Name und Beschreibung
// Filter nach Ort
// Liste mit Artikelname, Beschreibung, Ort und Menge
// Nur ein Button (Floating Action Button) – navigiert zur Erfassung.
// Nach Navigator.push wird bei Erfolg die Liste neu geladen.

import 'package:flutter/material.dart';

import '../models/artikel_model.dart';
import '../services/artikel_db_service.dart';
import '../widgets/article_icons.dart';
import 'artikel_erfassen_screen.dart';
import 'artikel_detail_screen.dart';
import 'dart:io';
import 'package:flutter/services.dart';

// Nextcloud Settings + Logout
import '../services/nextcloud_credentials.dart';
import 'nextcloud_settings_screen.dart';

// Scanfunktion
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:camera/camera.dart';

// ⬇️ Neu: prüft auf Camera vorhanden


class ArtikelListScreen extends StatefulWidget {
  const ArtikelListScreen({super.key});

  @override
  State<ArtikelListScreen> createState() => _ArtikelListScreenState();
}

class _BarcodeScannerScreen extends StatelessWidget {
  const _BarcodeScannerScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Barcode scannen")),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            Navigator.of(context).pop(barcodes.first.rawValue);
          }
        },
      ),
    );
  }
}


class _ArtikelListScreenState extends State<ArtikelListScreen> {
  List<Artikel> _artikelListe = [];
  String _suchbegriff = '';
  String _filterOrt = '';
  bool _hasCamera = false; // 👈 Flag für Kamera

  @override
  void initState() {
    super.initState();
    _ladeArtikel();
    _checkCameraAvailability(); // <--- Hier wird die Kamera-Verfügbarkeit geprüft
  }

  Future<void> _checkCameraAvailability() async {
    try {
      final cameras = await availableCameras();
      setState(() {
        _hasCamera = cameras.isNotEmpty;
      });
    } catch (e) {
      setState(() {
        _hasCamera = false;
      });
    }
  }

  Future<void> _ladeArtikel() async {
    final artikel = await ArtikelDbService().getAlleArtikel();
    setState(() {
      _artikelListe = artikel;
    });
  }

  List<Artikel> _gefilterteArtikel() {
    return _artikelListe.where((artikel) {
      final passtName = artikel.name.toLowerCase().contains(_suchbegriff.toLowerCase());
      final passtBeschreibung = artikel.beschreibung.toLowerCase().contains(_suchbegriff.toLowerCase());
      final passtOrt = _filterOrt.isEmpty || artikel.ort == _filterOrt;
      return (passtName || passtBeschreibung) && passtOrt;
    }).toList();
  }


  
  Future<void> _neuenArtikelErfassen() async {
    final result = await Navigator.of(context).push<Artikel>(
      MaterialPageRoute(builder: (_) => const ArtikelErfassenScreen()),
    );
    if (!mounted) return; // 👈 neu
    if (result != null) {
      setState(() => _artikelListe.add(result));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Artikel hinzugefügt: ${result.name}')),
      );
    }
  }

  // --- Scanfunktion ---
  Future<void> _scanArtikel() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _BarcodeScannerScreen(),
      ),
    );

    if (code != null && code.isNotEmpty) {
      setState(() {
        _suchbegriff = code; // 🔍 Suchbegriff direkt setzen
      });
    }
  }



  // --- Menü/Actions ---

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NextcloudSettingsScreen()),
    );
  }

  Future<void> _logoutNextcloud() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout Nextcloud'),
        content: const Text(
          'Gespeicherte Nextcloud-Zugangsdaten werden gelöscht. Fortfahren?'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
        ],
      ),
    );
    if (!mounted) return; // 👈 neu

    if (confirm == true) {
      await NextcloudCredentialsStore().clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nextcloud-Login gelöscht')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gefiltert = _gefilterteArtikel();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Artikelliste'),
        actions: [
          // ⋮ Popup-Menü rechts in der AppBar
          PopupMenuButton<_MenuAction>(
            onSelected: (act) async {
              switch (act) {
                case _MenuAction.erfassen:
                  await _neuenArtikelErfassen();
                  break;
                case _MenuAction.settings:
                  await _openSettings();
                  break;
                case _MenuAction.logout:
                  await _logoutNextcloud();
                  break;
                case _MenuAction.exit:
                  if (Platform.isAndroid || Platform.isIOS) {
                    SystemNavigator.pop(); // Mobile
                  } else {
                    exit(0); // Desktop
                  }
                  break;
                }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _MenuAction.erfassen,
                child: ListTile(
                  leading: AddArticleIcon(),
                  title: Text('Artikel erfassen'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: _MenuAction.settings,
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Nextcloud-Einstellungen'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _MenuAction.logout,
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Logout Nextcloud'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _MenuAction.exit,
                child: ListTile(
                  leading: Icon(Icons.close),
                  title: Text('App beenden'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Suche nach Name oder Beschreibung',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _suchbegriff = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),

            child: 
              DropdownButton<String>(
                value: _filterOrt.isEmpty ? null : _filterOrt,
                hint: const Text('Ort filtern'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Alle Orte anzeigen'),
                  ),
                  ..._artikelListe
                      .map((a) => a.ort)
                      .where((ort) => ort.isNotEmpty)
                      .toSet()
                      .map((ort) => DropdownMenuItem<String>(
                            value: ort,
                            child: Text(ort),
                          ))
//                      .toList(),
                ],
                onChanged: (value) => setState(() => _filterOrt = value ?? ''),
              ),              
          ),

          Expanded(
            child: ListView.builder(
              itemCount: gefiltert.length,
              itemBuilder: (context, index) {
                final artikel = gefiltert[index];
                return ListTile(
                  leading: (artikel.bildPfad.isNotEmpty && File(artikel.bildPfad).existsSync())
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(artikel.bildPfad),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                  title: Text(artikel.name),
                  subtitle: Text('${artikel.beschreibung} • ${artikel.ort}'),
                  trailing: Text('Menge: ${artikel.menge}'),

                  onTap: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ArtikelDetailScreen(artikel: artikel),
                      ),
                    );

                    if (!mounted) return;

                    if (result is Artikel) {
                      // 👉 Artikel wurde gespeichert
                      setState(() {
                        final index = _artikelListe.indexWhere((a) => a.id == result.id);
                        if (index != -1) {
                          _artikelListe[index] = result;
                        }
                      });
                    } else if (result == 'deleted') {
                      // 👉 Artikel wurde gelöscht
                      setState(() {
                        _artikelListe.removeWhere((a) => a.id == artikel.id);
                      });
                    }
                  }


                );
              },
            ),
          ),

        ],
      ),

      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_hasCamera) // 👈 nur anzeigen wenn Kamera verfügbar
            FloatingActionButton(
              heroTag: 'scan',
              onPressed: _scanArtikel,
              tooltip: "Artikel scannen",
              child: const Icon(Icons.qr_code_scanner),
            ),
          if (_hasCamera) const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'new',
            onPressed: _neuenArtikelErfassen,
            icon: const AddArticleIcon(),
            label: const Text('Neuer Artikel'),
          ),
        ],
      ),


    );
  }
}

enum _MenuAction { erfassen, settings, logout, exit }
