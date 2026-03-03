//lib/screens/artikel_list_screen.dart

import 'package:flutter/material.dart';
import '../models/artikel_model.dart';
import '../services/artikel_db_service.dart';
import '../services/artikel_import_service.dart';
import '../services/artikel_export_service.dart';
import '../services/pdf_service.dart';
import '../services/app_log_service.dart';
import '../services/scan_service.dart';
import '../widgets/article_icons.dart';
import 'artikel_erfassen_screen.dart';
import 'artikel_detail_screen.dart';
import 'settings_screen.dart';
import 'dart:io';

// Nextcloud Settings + Logout
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
  final NextcloudConnectionService _connectionService =
      NextcloudConnectionService();

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
      final passtName =
          artikel.name.toLowerCase().contains(_suchbegriff.toLowerCase());
      final passtBeschreibung = artikel.beschreibung
          .toLowerCase()
          .contains(_suchbegriff.toLowerCase());
      final passtOrt = _filterOrt.isEmpty || artikel.ort == _filterOrt;
      return (passtName || passtBeschreibung) && passtOrt;
    }).toList();
  }

  Future<void> _neuenArtikelErfassen() async {
    final result = await Navigator.of(context).push<Artikel>(
      MaterialPageRoute(builder: (_) => const ArtikelErfassenScreen()),
    );
    if (!mounted) return;
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
                  await ArtikelImportService.importArtikel(
                      context, _ladeArtikel);
                },
                child: const Row(children: [
                  Icon(Icons.file_upload, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                    'Artikel importieren (JSON/CSV)',
                    overflow: TextOverflow.ellipsis,
                  ))
                ])),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                await ArtikelExportService().showExportDialog(context);
              },
              child: const Row(children: [
                Icon(Icons.file_download, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                  'Artikel exportieren (JSON/CSV)',
                  overflow: TextOverflow.ellipsis,
                ))
              ]),
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
//          default:
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



  // --- Menü/Ansicht ---
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
                case _MenuAction.pdfReports:
                  await _showPdfReportsDialog();
                  break;
                case _MenuAction.zipBackup:
                  await _showZipBackupDialog();
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
                      const SnackBar(
                          content: Text('Datenbank wurde zurückgesetzt')),
                    );
                  }
                  break;
                case _MenuAction.showLog:
                  await AppLogService.showLogDialog(context);
                  break;
                case _MenuAction.nextcloudSettings:
                  await NextcloudConnectionService.showSettingsScreen(
                      context, _connectionService);
                  break;
                case _MenuAction.settings:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
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
              const PopupMenuItem(
                value: _MenuAction.pdfReports,
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text('PDF-Berichte'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: _MenuAction.zipBackup,
                child: ListTile(
                  leading: Icon(Icons.archive_outlined),
                  title: Text('ZIP-Backup Export/Import'),
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
              const PopupMenuItem(
                value: _MenuAction.showLog,
                child: ListTile(
                  leading: Icon(Icons.article),
                  title: Text('Log-Ansicht'),
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
                value: _MenuAction.settings,
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Einstellungen'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),

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
                  leading: (artikel.bildPfad.isNotEmpty &&
                          File(artikel.bildPfad).existsSync())
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
                          child: const Icon(Icons.image_not_supported,
                              color: Colors.grey),
                        ),
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
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () async {
                    // Navigation zur Artikel-Detail-Seite
                    final result = await Navigator.of(context).push<Artikel>(
                      MaterialPageRoute(
                        builder: (_) => ArtikelDetailScreen(artikel: artikel),
                      ),
                    );

                    // Falls der Artikel geändert wurde, Liste aktualisieren
                    if (result == null && mounted) {
                      await _ladeArtikel(); // Liste neu laden
                    }
                    // Falls der Artikel geändert wurde, Liste aktualisieren
                    else if (result is Artikel && mounted) {
                      setState(() {
                        final index =
                            _artikelListe.indexWhere((a) => a.id == result.id);
                        if (index != -1) {
                          _artikelListe[index] =
                              result; // Aktualisierten Artikel in der Liste ersetzen
                        }
                      });
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_hasCamera)
            FloatingActionButton(
              heroTag: 'scan',
              onPressed: () async {
                await ScanService.scanArtikel(
                    context, _artikelListe, _ladeArtikel, setState);
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

  Future<void> _showZipBackupDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('ZIP-Backup Export/Import'),
          children: [
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                final zipPath = await ArtikelExportService().backupToZipFile(context);
                if (zipPath != null) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ZIP-Backup lokal gespeichert')),
                  );
                }
              },
              child: const Row(children: [
                Icon(Icons.archive, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(child: Text('ZIP-Backup lokal exportieren'))
              ]),
            ),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                final zipPath = await ArtikelExportService().backupToZipFile(context);
                if (zipPath != null) {
                  await ArtikelExportService().backupZipToNextcloud(zipPath);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ZIP-Backup zu Nextcloud exportiert')),
                  );
                }
              },
              child: const Row(children: [
                Icon(Icons.cloud_upload, color: Colors.green),
                SizedBox(width: 8),
                Expanded(child: Text('ZIP-Backup zu Nextcloud exportieren'))
              ]),
            ),
            const Divider(),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                final (success, errors) = await ArtikelImportService.importBackupFromZipService(reloadArtikel: _ladeArtikel);
                if (!mounted) return;
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ZIP-Backup erfolgreich importiert!')),
                  );
                } else {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Fehler beim ZIP-Import'),
                      content: SingleChildScrollView(child: Text(errors.join('\n'))),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: const Row(children: [
                Icon(Icons.archive, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(child: Text('ZIP-Backup lokal importieren'))
              ]),
            ),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                // Beispiel: Remote ZIP-Pfad abfragen (hier statisch, in echt per Dialog)
                await ArtikelImportService.importZipBackupAuto(context, _ladeArtikel);
              },
              child: const Row(children: [
                Icon(Icons.cloud_download, color: Colors.purple),
                SizedBox(width: 8),
                Expanded(child: Text('ZIP-Backup von Nextcloud importieren'))
              ]),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPdfReportsDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('PDF-Berichte'),
          children: [
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                await _generateArtikelListePdf();
              },
              child: const Row(children: [
                Icon(Icons.list_alt, color: Colors.red),
                SizedBox(width: 8),
                Expanded(child: Text('Komplette Artikelliste als PDF'))
              ]),
            ),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                await _generateFilteredArtikelListePdf();
              },
              child: const Row(children: [
                Icon(Icons.filter_list, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(child: Text('Gefilterte Artikelliste als PDF'))
              ]),
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateArtikelListePdf() async {
    try {
      await AppLogService().log('PDF-Export gestartet: Komplette Artikelliste');
      final pdfService = PdfService();
      final alleArtikel = await ArtikelDbService().getAlleArtikel();
      
      if (alleArtikel.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Artikel für PDF-Export vorhanden.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final pdfFile = await pdfService.generateArtikelListePdf(alleArtikel);
      
      if (pdfFile != null) {
        await AppLogService().log('PDF erfolgreich erstellt: ${pdfFile.path}');
        
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
        await AppLogService().log('PDF-Export abgebrochen: Benutzer hat Dialog geschlossen');
      }
    } catch (e, stack) {
      await AppLogService().logError('Fehler beim PDF-Export: $e', stack);
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

  Future<void> _generateFilteredArtikelListePdf() async {
    try {
      await AppLogService().log('PDF-Export gestartet: Gefilterte Artikelliste');
      final pdfService = PdfService();
      
      // Verwende die bereits gefilterte Liste aus der UI
      final gefiltert = _artikelListe.where((artikel) {
        final nameMatch = artikel.name.toLowerCase().contains(_suchbegriff.toLowerCase());
        final descMatch = artikel.beschreibung.toLowerCase().contains(_suchbegriff.toLowerCase());
        final ortMatch = _filterOrt.isEmpty || artikel.ort == _filterOrt;
        return (nameMatch || descMatch) && ortMatch;
      }).toList();
      
      if (gefiltert.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine gefilterten Artikel für PDF-Export vorhanden.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final pdfFile = await pdfService.generateArtikelListePdf(gefiltert);
      
      if (pdfFile != null) {
        await AppLogService().log('Gefilterte PDF erfolgreich erstellt: ${pdfFile.path} (${gefiltert.length} Artikel)');
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF erfolgreich erstellt!\n${gefiltert.length} Artikel exportiert\nPfad: ${pdfFile.path}'),
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
        await AppLogService().log('Gefilterter PDF-Export abgebrochen: Benutzer hat Dialog geschlossen');
      }
    } catch (e, stack) {
      await AppLogService().logError('Fehler beim gefilterten PDF-Export: $e', stack);
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
}

enum _MenuAction {
  importExport,
  pdfReports,
  zipBackup,
  resetDb,
  showLog,
  nextcloudSettings,
  settings,
}
