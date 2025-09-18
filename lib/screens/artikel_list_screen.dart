//lib/screens/artikel_list_screen.dart

import 'package:flutter/material.dart';
// Füge hinzu:
import 'package:flutter/services.dart';

import '../models/artikel_model.dart';
import '../services/artikel_db_service.dart';
import '../services/artikel_import_service.dart';
import '../services/artikel_export_service.dart';
import '../services/nextcloud_sync_service.dart';
import '../services/scan_service.dart';
import '../widgets/article_icons.dart';
import 'artikel_erfassen_screen.dart';
import 'artikel_detail_screen.dart';
import 'dart:io';

// Nextcloud Settings + Logout
import '../services/nextcloud_credentials.dart';
import '../services/nextcloud_connection_service.dart';

// Kamera-Check
import 'package:camera/camera.dart';

class ArtikelListScreen extends StatefulWidget {
  const ArtikelListScreen({super.key});

  @override
  State<ArtikelListScreen> createState() => _ArtikelListScreenState();
}

class _ArtikelListScreenState extends State<ArtikelListScreen> {
  List<Artikel> _artikelListe = [];
  String _suchbegriff = '';
  String _filterOrt = '';
  bool _hasCamera = false;
  final NextcloudConnectionService _connectionService = NextcloudConnectionService();

  @override
  void initState() {
    super.initState();
    _ladeArtikel();
    _checkCameraAvailability();
    _initializeNextcloudMonitoring();
  }

  Future<void> _initializeNextcloudMonitoring() async {
    // Start Nextcloud connection monitoring if credentials are available
    await _connectionService.startPeriodicCheck();
  }

  @override
  void dispose() {
    _connectionService.dispose();
    super.dispose();
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
    if (result is Artikel) {
      setState(() => _artikelListe.add(result));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Artikel hinzugefügt: ${result.name}')),
      );
    }
  }

    // Import/Export-Funktion als Dialog
  Future<void> _importExportDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('Artikel Import/Export'),
          children: [
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                // Ausgelagert:
                await ArtikelImportService.importArtikel(context, _ladeArtikel);
              },
              child: Row(
                children: const [
                  Icon(Icons.file_upload, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Artikel importieren (JSON/CSV)',
                      overflow: TextOverflow.ellipsis,
                    )
                  )
                ]
              )
            ),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                await ArtikelExportService.showExportDialog(context);
              },
              child: Row(
                children: const [
                  Icon(Icons.file_download, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Artikel exportieren (JSON/CSV)',
                      overflow: TextOverflow.ellipsis,
                    )
                  )
                ]
              ),
            ),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                await NextcloudSyncService.showResyncDialog(context);
              },
              child: Row(
                children: const [
                  Icon(Icons.sync, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nextcloud Nachsynchronisation',
                      overflow: TextOverflow.ellipsis,
                    )
                  )
                ]
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Menü/Actions ---


  Widget _buildConnectionStatusIcon() {
    return ValueListenableBuilder<NextcloudConnectionStatus>(
      valueListenable: _connectionService.connectionStatus,
      builder: (context, status, child) {
        Widget icon;
        String tooltipMessage;
        
        switch (status) {
          case NextcloudConnectionStatus.online:
            icon = Icon(
              Icons.cloud_done,
              color: Colors.green[600],
              size: 20,
            );
            tooltipMessage = 'Nextcloud: Online';
            break;
          case NextcloudConnectionStatus.offline:
            icon = Icon(
              Icons.cloud_off,
              color: Colors.red[600],
              size: 20,
            );
            tooltipMessage = 'Nextcloud: Offline';
            break;
          case NextcloudConnectionStatus.unknown:
          default:
            icon = Icon(
              Icons.cloud_queue,
              color: Colors.grey[600],
              size: 20,
            );
            tooltipMessage = 'Nextcloud: Status unbekannt';
            break;
        }
        
        return GestureDetector(
          onTap: () {
            // Optional: Manual refresh on tap (for debugging)
            _connectionService.checkConnectionNow();
          },
          child: Tooltip(
            message: tooltipMessage,
            child: icon,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final gefiltert = _gefilterteArtikel();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Artikelliste'),
            const SizedBox(width: 12),
            _buildConnectionStatusIcon(),
          ],
        ),
        actions: [
          PopupMenuButton<_MenuAction>(
            onSelected: (act) async {
              switch (act) {
                case _MenuAction.importExport:
                  await _importExportDialog();
                  break;
                case _MenuAction.settings:
                  // Öffne Untermenü für Einstellungen
                  await showMenu(
                    context: context,
                    position: RelativeRect.fromLTRB(1000, 80, 0, 0), // Position ggf. anpassen
                    items: [
                      PopupMenuItem(
                        value: 'resetDb',
                        child: ListTile(
                          leading: const Icon(Icons.restart_alt),
                          title: const Text('Datenbank zurücksetzen'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'showLog',
                        child: ListTile(
                          leading: const Icon(Icons.article),
                          title: const Text('App-Log anzeigen/löschen'),
                        ),
                      ),
                    ],
                  ).then((selected) async {
                    if (selected == 'resetDb') {
                      final messenger = ScaffoldMessenger.of(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Datenbank zurücksetzen'),
                          content: const Text(
                              'Alle Artikel werden gelöscht und die IDs neu ab 1000 vergeben.\nFortfahren?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Abbrechen')),
                            FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Zurücksetzen')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ArtikelDbService().resetDatabase(startId: 1000);
                        if (!mounted) return;
                        await _ladeArtikel();
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Datenbank wurde zurückgesetzt')),
                        );
                      }
                    } else if (selected == 'showLog') {
                      await AppLogService.showLogDialog(context);
                    }
                  });
                  break;
                case _MenuAction.nextcloudSettings:
                  await NextcloudConnectionService.showSettingsScreen(context, _connectionService);
                  break;
                case _MenuAction.logout:
                  await NextcloudCredentialsStore.showLogoutDialog(context, _connectionService);
                  break;
                case _MenuAction.exit:
                  if (Platform.isAndroid || Platform.isIOS) {
                    SystemNavigator.pop();
                  } else {
                    exit(0);
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _MenuAction.importExport,
                child: ListTile(
                  leading: Icon(Icons.import_export),
                  title: Text('Artikel import/export'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _MenuAction.settings,
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Einstellungen'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _MenuAction.nextcloudSettings,
                child: ListTile(
                  leading: Icon(Icons.cloud),
                  title: Text('Nextcloud-Einstellungen'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
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
                  // NEU:
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          artikel.name,
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "${artikel.menge}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artikel.beschreibung,
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
              onPressed: () async {
                await ScanService.scanArtikel(context, _artikelListe, _ladeArtikel, setState);
              },
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

enum _MenuAction { importExport, settings, nextcloudSettings, logout, exit }
