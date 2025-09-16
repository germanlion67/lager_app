//lib/screens/artikel_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/artikel_model.dart';
import '../services/artikel_db_service.dart';
import '../services/artikel_import_service.dart';
import '../services/artikel_export_service.dart';
import '../widgets/article_icons.dart';
import 'artikel_erfassen_screen.dart';
import 'artikel_detail_screen.dart';
import 'qr_scan_screen_mobile_scanner.dart';
import 'dart:io';

// Nextcloud Settings + Logout
import '../services/nextcloud_credentials.dart';
import '../services/nextcloud_connection_service.dart';
import 'nextcloud_settings_screen.dart';
// Kamera-Check
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';

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
                await _importArtikel();
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
                await _exportArtikelDialog();
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
          ],
        );
      },
    );
  }

  // Import-Logik (JSON/CSV FilePicker)
  Future<void> _importArtikel() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['json', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final ext = file.extension?.toLowerCase();
    final content = file.bytes != null
        ? String.fromCharCodes(file.bytes!)
        : await File(file.path!).readAsString();

    List<Artikel> artikelList = [];
    String importMsg = "";

    try {
      if (ext == 'json') {
        artikelList = await ArtikelImportService().importFromJson(content);
        importMsg = "Importierte Artikel aus JSON: ${artikelList.length}";
      } else if (ext == 'csv') {
        artikelList = await ArtikelImportService().importFromCsv(content);
        importMsg = "Importierte Artikel aus CSV: ${artikelList.length}";
      } else {
        importMsg = "Dateiformat nicht unterstützt.";
      }
      if (artikelList.isNotEmpty) {
        await ArtikelImportService().insertArtikelList(artikelList);
        await _ladeArtikel();
      }
    } catch (e) {
      importMsg = "Fehler beim Import: $e";
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(importMsg)),
    );
  }

  // Export-Logik (Dialog zum Speichern als Datei)
  Future<void> _exportArtikelDialog() async {
    String? exportType = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Exportformat wählen'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'json'),
            child: const Text('Export als JSON'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'csv'),
            child: const Text('Export als CSV'),
          ),
        ],
      ),
    );
    if (exportType == null) return;

    String? exportData;
    String fileName = 'artikel_export_${DateTime.now().toIso8601String().replaceAll(':','-')}.$exportType';
    if (exportType == 'json') {
      exportData = await ArtikelExportService().exportAllArtikelAsJson();
    } else if (exportType == 'csv') {
      exportData = await ArtikelExportService().exportAllArtikelAsCsv();
    }
    if (exportData == null || exportData.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Artikeldaten vorhanden.')),
      );
      return;
    }
    // Speichern als Datei (nur Desktop/Mobile, nicht im Web)
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dateiexport auf diesem System nicht unterstützt.')),
      );
      return;
    }
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Exportiere Artikeldaten',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [exportType],
    );
    if (result != null) {
      final file = File(result);
      await file.writeAsString(exportData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export erfolgreich: $fileName')),
      );
    }
  }

  // --- Scanfunktion ---
  Future<void> _scanArtikel() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QRScanScreen()),
    );
    if (!mounted) return;
    if (result is Artikel) {
      setState(() {
        final index = _artikelListe.indexWhere((a) => a.id == result.id);
        if (index != -1) {
          _artikelListe[index] = result;
        }
      });
    } else if (result == 'deleted') {
      setState(() {
        _artikelListe.removeWhere((a) => a.id == result.id);
      });
    } else {

      // Falls kein Ergebnis: Liste einfach neu laden
      await _ladeArtikel();
    }
  }


  // --- Menü/Actions ---
  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NextcloudSettingsScreen()),
    );
    // Restart monitoring after settings change
    await _connectionService.restartMonitoring();
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
    if (!mounted) return;
    if (confirm == true) {
      await NextcloudCredentialsStore().clear();
      // Stop monitoring when logged out
      _connectionService.stopPeriodicCheck();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nextcloud-Login gelöscht')),
      );
    }
  }

  Widget _buildConnectionStatusIcon() {
    return ValueListenableBuilder<NextcloudConnectionStatus>(
      valueListenable: _connectionService.connectionStatus,
      builder: (context, status, child) {
        switch (status) {
          case NextcloudConnectionStatus.online:
            return Tooltip(
              message: 'Nextcloud: Online',
              child: Icon(
                Icons.cloud_done,
                color: Colors.green[600],
                size: 20,
              ),
            );
          case NextcloudConnectionStatus.offline:
            return Tooltip(
              message: 'Nextcloud: Offline',
              child: Icon(
                Icons.cloud_off,
                color: Colors.red[600],
                size: 20,
              ),
            );
          case NextcloudConnectionStatus.unknown:
          default:
            return Tooltip(
              message: 'Nextcloud: Status unbekannt',
              child: Icon(
                Icons.cloud_queue,
                color: Colors.grey[600],
                size: 20,
              ),
            );
        }
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
          // ⋮ Popup-Menü rechts in der AppBar
          PopupMenuButton<_MenuAction>(
            onSelected: (act) async {
              switch (act) {
                case _MenuAction.erfassen:
                  await _neuenArtikelErfassen();
                  break;
                case _MenuAction.importExport:
                  await _importExportDialog();
                  break;
               case _MenuAction.settings:
                  await _openSettings();
                  break;
                case _MenuAction.logout:
                  await _logoutNextcloud();
                  break;
                case _MenuAction.resetDb:
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
                value: _MenuAction.importExport,
                child: ListTile(
                  leading: Icon(Icons.import_export),
                  title: Text('Artikel import/export'),
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
                value: _MenuAction.resetDb,
                child: ListTile(
                  leading: Icon(Icons.restart_alt),
                  title: Text('Datenbank zurücksetzen'),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "${artikel.ort} • ${artikel.fach}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontStyle: FontStyle.italic, // ⬅️ Kursiv!
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
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

enum _MenuAction { erfassen, importExport, settings, logout, resetDb, exit }
