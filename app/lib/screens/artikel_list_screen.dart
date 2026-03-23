// lib/screens/artikel_list_screen.dart
//
// M-011: _buildArtikelBild() und _buildPocketBaseBild() ersetzt durch
//        ArtikelListBild-Widget aus artikel_bild_widget.dart.
//        Alle anderen Methoden unverändert.

import 'dart:async';



import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../models/artikel_model.dart';
import '../services/app_log_service.dart';
import '../services/artikel_db_service.dart';
import '../services/artikel_export_service.dart';
import '../services/artikel_import_service.dart';
import '../services/nextcloud_connection_service.dart';
import '../services/pocketbase_service.dart';
import '../services/scan_service.dart';
import '../widgets/article_icons.dart';
// M-011: Neues zentrales Bild-Widget
import '../widgets/artikel_bild_widget.dart';

import 'artikel_detail_screen.dart'; // ✅ NEU – für _openDetailScreen
import 'artikel_erfassen_screen.dart';
import 'nextcloud_settings_screen.dart';
import 'settings_screen.dart';

import 'list_screen_mobile_actions.dart'
    if (dart.library.html) 'list_screen_web_actions.dart'
    as mobile_actions;

class ArtikelListScreen extends StatefulWidget {
  const ArtikelListScreen({super.key});

  @override
  State<ArtikelListScreen> createState() => _ArtikelListScreenState();
}

class _ArtikelListScreenState extends State<ArtikelListScreen> {
  final Logger _logger = AppLogService.logger;

  List<Artikel> _artikelListe = [];
  String _suchbegriff = '';
  String _filterOrt = '';
  bool _isLoading = true;
  bool? _pbConnected;

  late final ArtikelDbService _db;
  late final PocketBaseService _pbService;

  NextcloudConnectionService? _nextcloudService;

  // ==================== LIFECYCLE ====================

  @override
  void initState() {
    super.initState();

    _db = ArtikelDbService();
    _pbService = PocketBaseService();

    _ladeArtikel();

    if (kIsWeb) {
      _pbConnected = true;
    } else {
      _checkPocketBaseConnection();

      try {
        _nextcloudService = NextcloudConnectionService();
        _nextcloudService!.startPeriodicCheck();
      } catch (e, st) {
        _logger.e('Nextcloud-Init fehlgeschlagen:', error: e, stackTrace: st);
      }
    }
  }

  @override
  void dispose() {
    _nextcloudService?.dispose();
    super.dispose();
  }

  // ==================== DATEN LADEN ====================

  Future<void> _ladeArtikel() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (kIsWeb) {
        final records = await _pbService.client
            .collection('artikel')
            .getFullList(sort: '-created')
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () =>
                  throw TimeoutException('PocketBase antwortet nicht'),
            );

        _artikelListe = records.map((r) {
          final created = r.data['created'] as String? ?? '';
          final updated = r.data['updated'] as String? ?? '';
          return Artikel.fromPocketBase(
            r.data,
            r.id,
            created: created,
            updated: updated,
          );
        }).toList();
      } else {
        _artikelListe = await _db.getAlleArtikel();
      }
    } catch (e, st) {
      _logger.e('Fehler beim Laden:', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==================== VERBINDUNG ====================

  Future<void> _checkPocketBaseConnection() async {
    try {
      final ok = await _pbService
          .checkHealth()
          .timeout(const Duration(seconds: 10));
      if (mounted) setState(() => _pbConnected = ok);
    } catch (_) {
      if (mounted) setState(() => _pbConnected = false);
    }
  }

  // ==================== FILTER ====================

  List<Artikel> _gefilterteArtikel() {
    return _artikelListe.where((artikel) {
      final suchLower = _suchbegriff.toLowerCase();
      final passtName = artikel.name.toLowerCase().contains(suchLower);
      final passtBeschreibung =
          artikel.beschreibung.toLowerCase().contains(suchLower);
      final passtOrt =
          _filterOrt.isEmpty || artikel.ort.trim() == _filterOrt.trim();

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
      await _ladeArtikel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Artikel hinzugefügt: ${result.name}')),
      );
    }
  }

  // ==================== VERBINDUNGS-ICON ====================

  Widget _buildConnectionStatusIcon() {
    Widget pbIcon;
    String pbTooltip;

    switch (_pbConnected) {
      case true:
        pbIcon = Icon(Icons.dns, color: Colors.green[600], size: 20);
        pbTooltip = 'PocketBase: Online';
      case false:
        pbIcon = Icon(Icons.dns, color: Colors.red[600], size: 20);
        pbTooltip = 'PocketBase: Offline';
      default:
        pbIcon = Icon(Icons.dns, color: Colors.grey[600], size: 20);
        pbTooltip = 'PocketBase: Prüfe...';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _checkPocketBaseConnection,
          child: Tooltip(message: pbTooltip, child: pbIcon),
        ),
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
        final IconData iconData;
        final Color color;
        final String tooltip;

        switch (status) {
          case NextcloudConnectionStatus.online:
            iconData = Icons.cloud_done;
            color = Colors.green[600]!;
            tooltip = 'Nextcloud: Online';
          case NextcloudConnectionStatus.offline:
            iconData = Icons.cloud_off;
            color = Colors.red[600]!;
            tooltip = 'Nextcloud: Offline';
          case NextcloudConnectionStatus.unknown:
            iconData = Icons.cloud_queue;
            color = Colors.grey[600]!;
            tooltip = 'Nextcloud: Unbekannt';
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
                    .map((a) => a.ort.trim())
                    .where((ort) => ort.isNotEmpty)
                    .toSet()
                    .map(
                      (ort) => DropdownMenuItem<String>(
                        value: ort,
                        child: Text(ort),
                      ),
                    ),
              ],
              onChanged: (value) => setState(() => _filterOrt = value ?? ''),
            ),
          ),
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
                            return _buildArtikelTile(gefiltert[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (ScanService.isAvailable) ...[
            FloatingActionButton(
              heroTag: 'scan',
              onPressed: () async {
                await ScanService.scanArtikel(
                  context,
                  _artikelListe,
                  _ladeArtikel,
                  setState,
                );
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
      // M-011: Zentrales Bild-Widget statt inline Image.network / Image.file
      leading: ArtikelListBild(artikel: artikel),
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
            artikel.menge.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
            '${artikel.ort.trim()} • ${artikel.fach.trim()}',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      isThreeLine: true,
      onTap: () => _openDetailScreen(artikel), // ← ausgelagert für Übersicht
    );
  }

  // ==================== DETAIL SCREEN ====================  ← NEU

  Future<void> _openDetailScreen(Artikel artikel) async {
    _logger.d('Detail-Screen öffnen: ${artikel.name} (uuid: ${artikel.uuid})');

    final result = await Navigator.of(context).push<Artikel?>(
      MaterialPageRoute(
        builder: (_) => ArtikelDetailScreen(artikel: artikel),
      ),
    );

    if (!mounted) return;

    if (result == null) {
      _logger.i('Artikel gelöscht oder kein Rückgabewert → neu laden');
      await _ladeArtikel();
      return;
    }

    _logger.i('Artikel zurückgekehrt: ${result.name} – gezielt aktualisieren');

    _clearImageCache(result);

    setState(() {
      final index = _artikelListe.indexWhere((a) => a.uuid == result.uuid);
      if (index != -1) {
        _artikelListe[index] = result;
        _logger.d('Artikel in Liste ersetzt – Index $index: ${result.name}');
      } else {
        _logger.w('Artikel uuid nicht in Liste gefunden → Fallback: neu laden');
        _ladeArtikel();
      }
    });
  }

  void _clearImageCache(Artikel result) {
    final alterArtikel = _artikelListe.firstWhere(
      (a) => a.uuid == result.uuid,
      orElse: () => result,
    );

    final bildHatSichGeaendert = alterArtikel.bildPfad != result.bildPfad;

    if (!bildHatSichGeaendert) {
      _logger.t('Bildpfad unverändert – kein Cache-Clear nötig');
      return;
    }

    _logger.d('Bildpfad geändert → Image-Cache leeren');
    _logger.t('Alt: ${alterArtikel.bildPfad}');
    _logger.t('Neu: ${result.bildPfad}');

    imageCache.clear();
    imageCache.clearLiveImages();
    _logger.d('Image-Cache geleert');
  }


  // ==================== MENÜ ====================

  Future<void> _handleMenuAction(_MenuAction action) async {
    switch (action) {
      case _MenuAction.importExport:
        await _importExportDialog();

      case _MenuAction.pdfReports:
        if (kIsWeb) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF-Export ist im Web nicht verfügbar'),
            ),
          );
        } else {
          await _showPdfReportsDialog();
        }

      case _MenuAction.zipBackup:
        if (kIsWeb) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ZIP-Backup ist im Web nicht verfügbar'),
            ),
          );
        } else {
          await mobile_actions.showZipBackupDialog(context, _ladeArtikel);
        }

      case _MenuAction.resetDb:
        await _handleResetDb();

      case _MenuAction.showLog:
        await AppLogService.showLogDialog(context);

      case _MenuAction.nextcloudSettings:
        if (!kIsWeb && _nextcloudService != null) {
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => NextcloudSettingsScreen(
                connectionService: _nextcloudService!,
              ),
            ),
          );
        }

      case _MenuAction.settings:
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
        );
        if (!mounted) return;
        unawaited(_checkPocketBaseConnection());
    }
  }

  Future<void> _handleResetDb() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datenbank-Reset ist im Web nicht verfügbar'),
        ),
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
      await _db.resetDatabase(startId: 1000);
      if (!mounted) return;
      await _ladeArtikel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lokale Datenbank wurde zurückgesetzt'),
        ),
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
      if (!kIsWeb) ...[
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
      ],
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
    ];
  }

  // ==================== DIALOGE ====================

  Future<void> _importExportDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('Artikel Import/Export'),
          children: [
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                if (!mounted) return;
                await ArtikelImportService.importArtikel(
                  context,
                  _ladeArtikel,
                );
                if (!mounted) return;
              },
              child: const Row(
                children: [
                  Icon(Icons.file_upload, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(child: Text('Artikel importieren (JSON/CSV)')),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                if (!mounted) return;
                await ArtikelExportService().showExportDialog(context);
                if (!mounted) return;
              },
              child: const Row(
                children: [
                  Icon(Icons.file_download, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(child: Text('Artikel exportieren (JSON/CSV)')),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPdfReportsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('PDF-Berichte'),
          children: [
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                if (!mounted) return;
                await mobile_actions.generateArtikelListePdf(
                  context,
                  _artikelListe,
                );
                if (!mounted) return;
              },
              child: const Row(
                children: [
                  Icon(Icons.list_alt, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(child: Text('Komplette Artikelliste als PDF')),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                if (!mounted) return;
                await mobile_actions.generateFilteredArtikelListePdf(
                  context,
                  _gefilterteArtikel(),
                );
                if (!mounted) return;
              },
              child: const Row(
                children: [
                  Icon(Icons.filter_list, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(child: Text('Gefilterte Artikelliste als PDF')),
                ],
              ),
            ),
            const Divider(),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                if (!mounted) return;
                await mobile_actions.generateFilteredArtikelListePdf(
                  context,
                  _gefilterteArtikel(),
                );
                if (!mounted) return;
              },
              child: const Row(
                children: [
                  Icon(Icons.description_outlined, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(child: Text('Einzelner Artikel als Detail-PDF')),
                ],
              ),
            ),
          ],
        );
      },
    );
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