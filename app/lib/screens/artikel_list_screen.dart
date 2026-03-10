// lib/screens/artikel_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/artikel_model.dart';
import '../services/artikel_db_service.dart';
import '../services/pocketbase_service.dart';
import '../services/artikel_import_service.dart';
import '../services/artikel_export_service.dart';
import '../services/app_log_service.dart';
import '../widgets/article_icons.dart';
import 'artikel_erfassen_screen.dart';
import 'artikel_detail_screen.dart';
import 'settings_screen.dart';

// Conditional imports
import 'list_screen_io.dart'
    if (dart.library.html) 'list_screen_stub.dart' as platform;

// PDF nur auf Mobile/Desktop
import '../services/pdf_service.dart';

// Scanner nur auf Mobile/Desktop
import '../services/scan_service.dart';

// Nextcloud nur als optionales Backup
import '../services/nextcloud_connection_service.dart';

class ArtikelListScreen extends StatefulWidget {
  const ArtikelListScreen({super.key});

  @override
  State<ArtikelListScreen> createState() => _ArtikelListScreenState();
}

class _ArtikelListScreenState extends State<ArtikelListScreen> {
  List<Artikel> _artikelListe = [];
  String _suchbegriff = '';
  String _filterOrt = '';
  bool _isLoading = true;
  bool _hasCamera = false;

  // PocketBase Verbindungsstatus
  bool? _pbConnected;

  // Nextcloud (optional, nur Mobile)
  NextcloudConnectionService? _nextcloudService;

  @override
  void initState() {
    super.initState();
    _ladeArtikel();
    _checkPocketBaseConnection();

    if (!kIsWeb) {
      _checkCameraAvailability();
      _nextcloudService = NextcloudConnectionService();
      _nextcloudService!.startPeriodicCheck();
    }
  }

  @override
  void dispose() {
    _nextcloudService?.dispose();
    super.dispose();
  }

  // ==================== DATEN LADEN ====================

  Future<void> _ladeArtikel() async {
    setState(() => _isLoading = true);
    try {
      if (kIsWeb) {
        // Web: Direkt von PocketBase
        final pb = PocketBaseService().client;
        final records = await pb.collection('artikel').getFullList(sort: '-created');
        _artikelListe = records.map((r) => Artikel.fromMap({
          ...r.data,
          'id': r.id,
        })).toList();
      } else {
        // Mobile: Aus lokaler DB
        _artikelListe = await ArtikelDbService().getAlleArtikel();
      }
    } catch (e) {
      debugPrint('[ArtikelList] Fehler beim Laden: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==================== VERBINDUNG ====================

  Future<void> _checkPocketBaseConnection() async {
    final ok = await PocketBaseService().checkHealth();
    if (mounted) setState(() => _pbConnected = ok);
  }

  Future<void> _checkCameraAvailability() async {
    if (kIsWeb) return;
    try {
      final hasCamera = await platform.checkCamera();
      if (mounted) setState(() => _hasCamera = hasCamera);
    } catch (_) {
      if (mounted) setState(() => _hasCamera = false);
    }
  }

  // ==================== FILTER ====================

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

  // ==================== AKTIONEN ====================

  Future<void> _neuenArtikelErfassen() async {
    final result = await Navigator.of(context).push<Artikel>(
      MaterialPageRoute(builder: (_) => const ArtikelErfassenScreen()),
    );
    if (!mounted) return;
    if (result is Artikel) {
      await _ladeArtikel(); // Komplett neu laden (sicherer als manuelles Hinzufügen)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Artikel hinzugefügt: ${result.name}')),
      );
    }
  }

  // ==================== VERBINDUNGS-ICON ====================

  Widget _buildConnectionStatusIcon() {
    // PocketBase Status
    Widget pbIcon;
    String pbTooltip;

    switch (_pbConnected) {
      case true:
        pbIcon = Icon(Icons.dns, color: Colors.green[600], size: 20);
        pbTooltip = 'PocketBase: Online';
        break;
      case false:
        pbIcon = Icon(Icons.dns, color: Colors.red[600], size: 20);
        pbTooltip = 'PocketBase: Offline';
        break;
      default:
        pbIcon = Icon(Icons.dns, color: Colors.grey[600], size: 20);
        pbTooltip = 'PocketBase: Prüfe...';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PocketBase Status
        GestureDetector(
          onTap: _checkPocketBaseConnection,
          child: Tooltip(message: pbTooltip, child: pbIcon),
        ),

        // Nextcloud Status (nur Mobile, optional)
        if (!kIsWeb && _nextcloudService != null) ...[
          const SizedBox(width: 6),
          _buildNextcloudIcon(),
        ],
      ],
    );
  }

  Widget _buildNextcloudIcon() {
    return ValueListenableBuilder<NextcloudConnectionStatus>(
      valueListenable: _nextcloudService!.connectionStatus,
      builder: (context, status, _) {
        IconData iconData;
        Color color;
        String tooltip;

        switch (status) {
          case NextcloudConnectionStatus.online:
            iconData = Icons.cloud_done;
            color = Colors.green[600]!;
            tooltip = 'Nextcloud: Online';
            break;
          case NextcloudConnectionStatus.offline:
            iconData = Icons.cloud_off;
            color = Colors.red[600]!;
            tooltip = 'Nextcloud: Offline';
            break;
          case NextcloudConnectionStatus.unknown:
            iconData = Icons.cloud_queue;
            color = Colors.grey[600]!;
            tooltip = 'Nextcloud: Unbekannt';
            break;
        }

        return GestureDetector(
          onTap: () => _nextcloudService!.checkConnectionNow(),
          child: Tooltip(
            message: tooltip,
            child: Icon(iconData, color: color, size: 20),
          ),
        );
      },
    );
  }

  // ==================== BILD-WIDGET ====================

  Widget _buildArtikelBild(Artikel artikel) {
    // Web: Bild von PocketBase laden
    if (kIsWeb) {
      return _buildPocketBaseBild(artikel);
    }

    // Mobile: Lokales Bild
    if (artikel.bildPfad.isNotEmpty && platform.fileExists(artikel.bildPfad)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: platform.buildFileImage(
          artikel.bildPfad,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
        ),
      );
    }

    return _buildBildPlaceholder();
  }

  Widget _buildPocketBaseBild(Artikel artikel) {
    try {
      final pb = PocketBaseService().client;
      // PocketBase Record-ID aus den Daten holen
      final recordId = artikel.toMap()['id']?.toString();
      final bildField = artikel.toMap()['bild']?.toString();

      if (recordId != null && bildField != null && bildField.isNotEmpty) {
        // PocketBase File-URL generieren – benötigt RecordModel
        final url = '${PocketBaseService().url}/api/files/artikel/$recordId/$bildField';
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            url,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildBildPlaceholder(),
          ),
        );
      }
    } catch (_) {}

    return _buildBildPlaceholder();
  }

  Widget _buildBildPlaceholder() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }

  // ==================== UI ====================

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
          // Refresh-Button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
            onPressed: _ladeArtikel,
          ),
          PopupMenuButton<_MenuAction>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => _buildMenuItems(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Suchleiste
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

          // Ort-Filter
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
                        )),
              ],
              onChanged: (value) => setState(() => _filterOrt = value ?? ''),
            ),
          ),

          // Artikelliste
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : gefiltert.isEmpty
                    ? const Center(
                        child: Text(
                          'Keine Artikel gefunden',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _ladeArtikel,
                        child: ListView.builder(
                          itemCount: gefiltert.length,
                          itemBuilder: (context, index) {
                            final artikel = gefiltert[index];
                            return _buildArtikelTile(artikel);
                          },
                        ),
                      ),
          ),
        ],
      ),

      // FABs
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Scanner nur auf Mobile mit Kamera
          if (!kIsWeb && _hasCamera) ...[
            FloatingActionButton(
              heroTag: 'scan',
              onPressed: () async {
                await ScanService.scanArtikel(
                    context, _artikelListe, _ladeArtikel, setState);
              },
              tooltip: 'Artikel scannen',
              child: const Icon(Icons.qr_code_scanner),
            ),
            const SizedBox(width: 12),
          ],
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

  // ==================== ARTIKEL TILE ====================

  Widget _buildArtikelTile(Artikel artikel) {
    return ListTile(
      leading: _buildArtikelBild(artikel),
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
            '${artikel.menge}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(artikel.beschreibung, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(
            '${artikel.ort} • ${artikel.fach}',
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
        final result = await Navigator.of(context).push<Artikel>(
          MaterialPageRoute(
            builder: (_) => ArtikelDetailScreen(artikel: artikel),
          ),
        );

        if (!mounted) return;
        // Immer neu laden – einfacher und sicherer
        await _ladeArtikel();
      },
    );
  }

  // ==================== MENÜ ====================

  Future<void> _handleMenuAction(_MenuAction action) async {
    switch (action) {
      case _MenuAction.importExport:
        await _importExportDialog();
        break;
      case _MenuAction.pdfReports:
        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF-Export ist im Web noch nicht verfügbar')),
          );
        } else {
          await _showPdfReportsDialog();
        }
        break;
      case _MenuAction.zipBackup:
        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ZIP-Backup ist im Web nicht verfügbar')),
          );
        } else {
          await _showZipBackupDialog();
        }
        break;
      case _MenuAction.resetDb:
        await _handleResetDb();
        break;
      case _MenuAction.showLog:
        await AppLogService.showLogDialog(context);
        break;
      case _MenuAction.nextcloudSettings:
        if (!kIsWeb && _nextcloudService != null) {
          await NextcloudConnectionService.showSettingsScreen(
              context, _nextcloudService!);
        }
        break;
      case _MenuAction.settings:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        // Nach Einstellungen: PB-Verbindung neu prüfen
        _checkPocketBaseConnection();
        break;
    }
  }

  Future<void> _handleResetDb() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datenbank-Reset ist im Web nicht verfügbar')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Datenbank zurücksetzen'),
        content: const Text(
          'Alle lokalen Artikel werden gelöscht.\n'
          'Daten in PocketBase bleiben erhalten.\nFortfahren?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ArtikelDbService().resetDatabase(startId: 1000);
      if (!mounted) return;
      await _ladeArtikel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokale Datenbank wurde zurückgesetzt')),
      );
    }
  }

  List<PopupMenuEntry<_MenuAction>> _buildMenuItems() {
    return [
      const PopupMenuItem(
        value: _MenuAction.importExport,
        child: ListTile(
          leading: Icon(Icons.import_export),
          title: Text('Artikel import/export'),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ),
      // PDF & ZIP nur auf Mobile anzeigen
      if (!kIsWeb) ...[
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
      ],
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
      // Nextcloud nur auf Mobile
      if (!kIsWeb)
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
    ];
  }

  // ==================== DIALOGE ====================

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
                await ArtikelImportService.importArtikel(context, _ladeArtikel);
              },
              child: const Row(children: [
                Icon(Icons.file_upload, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(child: Text('Artikel importieren (JSON/CSV)')),
              ]),
            ),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                await ArtikelExportService().showExportDialog(context);
              },
              child: const Row(children: [
                Icon(Icons.file_download, color: Colors.green),
                SizedBox(width: 8),
                Expanded(child: Text('Artikel exportieren (JSON/CSV)')),
              ]),
            ),
          ],
        );
      },
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
                if (zipPath != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ZIP-Backup lokal gespeichert')),
                  );
                }
              },
              child: const Row(children: [
                Icon(Icons.archive, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(child: Text('ZIP-Backup lokal exportieren')),
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
                Expanded(child: Text('ZIP-Backup zu Nextcloud exportieren')),
              ]),
            ),
            const Divider(),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                final (success, errors) =
                    await ArtikelImportService.importBackupFromZipService(
                        reloadArtikel: _ladeArtikel);
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
                Expanded(child: Text('ZIP-Backup lokal importieren')),
              ]),
            ),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                await ArtikelImportService.importZipBackupAuto(context, _ladeArtikel);
              },
              child: const Row(children: [
                Icon(Icons.cloud_download, color: Colors.purple),
                SizedBox(width: 8),
                Expanded(child: Text('ZIP-Backup von Nextcloud importieren')),
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
                Expanded(child: Text('Komplette Artikelliste als PDF')),
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
                Expanded(child: Text('Gefilterte Artikelliste als PDF')),
              ]),
            ),
          ],
        );
      },
    );
  }

  // ==================== PDF (nur Mobile) ====================

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
        await AppLogService().log('PDF erstellt: ${pdfFile.path}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF erstellt!\nPfad: ${pdfFile.path}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Öffnen',
              onPressed: () async {
                final success = await PdfService.openPdf(pdfFile.path);
                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PDF konnte nicht geöffnet werden')),
                  );
                }
              },
            ),
          ),
        );
      }
    } catch (e, stack) {
      await AppLogService().logError('PDF-Export Fehler: $e', stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _generateFilteredArtikelListePdf() async {
    try {
      final gefiltert = _gefilterteArtikel(); // Bestehende Methode wiederverwenden!

      if (gefiltert.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine gefilterten Artikel vorhanden.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final pdfFile = await PdfService().generateArtikelListePdf(gefiltert);

      if (pdfFile != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF erstellt! (${gefiltert.length} Artikel)'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Öffnen',
              onPressed: () async {
                await PdfService.openPdf(pdfFile.path);
              },
            ),
          ),
        );
      }
    } catch (e, stack) {
      await AppLogService().logError('PDF-Export Fehler: $e', stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
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
