// /lib/screens/artikel_list_screen.dart

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


// ⬇️ Neu: Nextcloud Settings + Logout
import '../services/nextcloud_credentials.dart';
import 'nextcloud_settings_screen.dart';

class ArtikelListScreen extends StatefulWidget {
  const ArtikelListScreen({super.key});

  @override
  State<ArtikelListScreen> createState() => _ArtikelListScreenState();
}

class _ArtikelListScreenState extends State<ArtikelListScreen> {
  List<Artikel> _artikelListe = [];
  String _suchbegriff = '';
  String _filterOrt = '';

  @override
  void initState() {
    super.initState();
    _ladeArtikel();
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
    if (result != null) {
      setState(() => _artikelListe.add(result));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Artikel hinzugefügt: ${result.name}')),
      );
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
            child: DropdownButton<String>(
              value: _filterOrt.isEmpty ? null : _filterOrt,
              hint: const Text('Ort filtern'),
              isExpanded: true,
              items: _artikelListe
                  .map((a) => a.ort)
                  .toSet()
                  .map((ort) => DropdownMenuItem<String>(
                        value: ort,
                        child: Text(ort),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _filterOrt = value ?? ''),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: gefiltert.length,
              itemBuilder: (context, index) {
                final artikel = gefiltert[index];
                return ListTile(
                  title: Text(artikel.name),
                  subtitle: Text('${artikel.beschreibung} • ${artikel.ort}'),
                  trailing: Text('Menge: ${artikel.menge}'),
                  
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ArtikelDetailScreen(artikel: artikel),
                      ),
                    );
                    await _ladeArtikel(); // Liste nach Rückkehr aktualisieren
                  },

                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _neuenArtikelErfassen,
        icon: const AddArticleIcon(),
        label: const Text('Neuer Artikel'),
      ),
    );
  }
}

enum _MenuAction { erfassen, settings, logout }
