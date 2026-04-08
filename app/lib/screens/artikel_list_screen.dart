// lib/screens/artikel_list_screen.dart
//
// O-004 Batch 3: Alle hardcodierten Farben durch colorScheme ersetzt,
// alle Magic-Number-Abstände/Radien durch AppConfig-Tokens.
//
// M-011: _buildArtikelBild() und _buildPocketBaseBild() ersetzt durch
//        ArtikelListBild-Widget aus artikel_bild_widget.dart.

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../config/app_config.dart';
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

import 'artikel_detail_screen.dart';
import 'artikel_erfassen_screen.dart';
import 'nextcloud_settings_screen.dart';
import 'settings_screen.dart';

import 'list_screen_mobile_actions.dart'
    if (dart.library.html) 'list_screen_web_actions.dart'
    as mobile_actions;

import '../widgets/app_loading_overlay.dart';

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

    // M-005: Pagination
    final ScrollController _scrollController = ScrollController();
    bool _isLoadingMore = false;
    bool _hasMore = true;
    int _currentOffset = 0;

    // P-002: Debounce
    Timer? _debounceTimer;
    List<Artikel> _suchErgebnisse = [];
    bool _isSuche = false;

  late final ArtikelDbService _db;
  late final PocketBaseService _pbService;

  NextcloudConnectionService? _nextcloudService;

  // ==================== LIFECYCLE ====================

  @override
    void initState() {
      super.initState();

      _db = ArtikelDbService();
      _pbService = PocketBaseService();

      // M-005: Scroll-Listener für Pagination
      _scrollController.addListener(_onScroll);

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
      _debounceTimer?.cancel();
      _scrollController.dispose();
      _nextcloudService?.dispose();
      super.dispose();
    }

  // ==================== DATEN LADEN ====================

  Future<void> _ladeArtikel() async {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _currentOffset = 0;
        _hasMore = true;
        _artikelListe = [];
      });

      try {
        if (kIsWeb) {
          // Web: PocketBase liefert alles auf einmal — Pagination nicht nötig
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
          _hasMore = false; // Web lädt alles auf einmal
        } else {
          // M-005: Erste Seite laden
          final seite = await _db.getAlleArtikel(
            limit: AppConfig.paginationPageSize,
            offset: 0,
          );
          _artikelListe = seite;
          _currentOffset = seite.length;
          _hasMore = seite.length >= AppConfig.paginationPageSize;
        }
      } catch (e, st) {
        _logger.e('Fehler beim Laden:', error: e, stackTrace: st);
        if (mounted) {
          final colorScheme = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Laden: $e'),
              backgroundColor: colorScheme.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }

// M-005: Nächste Seite laden
  Future<void> _ladeNaechsteSeite() async {
    if (_isLoadingMore || !_hasMore || _suchbegriff.isNotEmpty) return;
    if (!mounted) return;

    setState(() => _isLoadingMore = true);

    try {
      final seite = await _db.getAlleArtikel(
        limit: AppConfig.paginationPageSize,
        offset: _currentOffset,
      );

      if (!mounted) return;
      setState(() {
        _artikelListe.addAll(seite);
        _currentOffset += seite.length;
        _hasMore = seite.length >= AppConfig.paginationPageSize;
      });
      _logger.d(
        'M-005: Seite geladen — ${seite.length} Artikel, '
        'Offset jetzt $_currentOffset, hasMore: $_hasMore',
      );
    } catch (e, st) {
      _logger.e('Fehler beim Nachladen:', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // M-005: Scroll-Listener
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final threshold =
        position.maxScrollExtent - AppConfig.paginationScrollThreshold;
    if (position.pixels >= threshold) {
      _ladeNaechsteSeite();
    }
  }

// P-002: Debounce-Handler für Sucheingabe
  void _onSuchbegriffChanged(String value) {
    _debounceTimer?.cancel();

    if (value.isEmpty) {
      // Suche beendet → zurück zur paginierten Liste
      setState(() {
        _suchbegriff = '';
        _isSuche = false;
        _suchErgebnisse = [];
      });
      return;
    }

    setState(() => _suchbegriff = value);

    _debounceTimer = Timer(AppConfig.searchDebounceDuration, () {
      _fuehreSucheAus(value);
    });
  }

  // P-002: DB-Suche ausführen (Mobile) oder clientseitig filtern (Web)
  Future<void> _fuehreSucheAus(String query) async {
    if (!mounted) return;
    setState(() => _isSuche = true);

    try {
      if (kIsWeb) {
        // Web: clientseitig über die bereits geladene Liste filtern
        final lower = query.toLowerCase();
        setState(() {
          _suchErgebnisse = _artikelListe.where((a) {
            return a.name.toLowerCase().contains(lower) ||
                a.beschreibung.toLowerCase().contains(lower);
          }).toList();
        });
      } else {
        // Mobile/Desktop: DB-Suche via searchArtikel()
        final ergebnisse = await _db.searchArtikel(
          query,
          limit: AppConfig.searchResultLimit,
        );
        if (!mounted) return;
        setState(() => _suchErgebnisse = ergebnisse);
      }
      _logger.d(
        'P-002: Suche "$query" → ${_suchErgebnisse.length} Treffer',
      );
    } catch (e, st) {
      _logger.e('P-002: Fehler bei Suche "$query":', error: e, stackTrace: st);
      if (mounted) setState(() => _suchErgebnisse = []);
    } finally {
      if (mounted) setState(() => _isSuche = false);
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
      // P-002: Bei aktiver Suche → _suchErgebnisse nutzen (DB-Suche)
      // Sonst → paginierte _artikelListe clientseitig nach Ort filtern
      final basis = _suchbegriff.isNotEmpty ? _suchErgebnisse : _artikelListe;

      if (_filterOrt.isEmpty) return basis;

      return basis
          .where((a) => a.ort.trim() == _filterOrt.trim())
          .toList();
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
    final colorScheme = Theme.of(context).colorScheme;

    final Color pbColor;
    final String pbTooltip;

    switch (_pbConnected) {
      case true:
        pbColor = colorScheme.tertiary;
        pbTooltip = 'PocketBase: Online';
      case false:
        pbColor = colorScheme.error;
        pbTooltip = 'PocketBase: Offline';
      default:
        pbColor = colorScheme.onSurfaceVariant;
        pbTooltip = 'PocketBase: Prüfe...';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _checkPocketBaseConnection,
          child: Tooltip(
            message: pbTooltip,
            child: Icon(Icons.dns, color: pbColor, size: AppConfig.iconSizeMedium),
          ),
        ),
        if (!kIsWeb && _nextcloudService != null) ...[
          const SizedBox(width: AppConfig.spacingSmall - 2), // 6
          _buildNextcloudIcon(),
        ],
      ],
    );
  }

  Widget _buildNextcloudIcon() {
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<NextcloudConnectionStatus>(
      valueListenable: _nextcloudService!.connectionStatus,
      builder: (context, status, _) {
        final IconData iconData;
        final Color color;
        final String tooltip;

        switch (status) {
          case NextcloudConnectionStatus.online:
            iconData = Icons.cloud_done;
            color = colorScheme.tertiary;
            tooltip = 'Nextcloud: Online';
          case NextcloudConnectionStatus.offline:
            iconData = Icons.cloud_off;
            color = colorScheme.error;
            tooltip = 'Nextcloud: Offline';
          case NextcloudConnectionStatus.unknown:
            iconData = Icons.cloud_queue;
            color = colorScheme.onSurfaceVariant;
            tooltip = 'Nextcloud: Unbekannt';
        }

        return GestureDetector(
          onTap: () => _nextcloudService!.checkConnectionNow(),
          child: Tooltip(
            message: tooltip,
            child: Icon(iconData, color: color, size: AppConfig.iconSizeMedium),
          ),
        );
      },
    );
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final gefiltert = _gefilterteArtikel();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Artikelliste'),
            const SizedBox(width: AppConfig.spacingMedium),
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
            padding: const EdgeInsets.all(AppConfig.spacingSmall),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Suche nach Name oder Beschreibung',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              // P-002: Debounce statt direktem setState
              onChanged: _onSuchbegriffChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConfig.spacingSmall,
            ),
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
                ? const ArtikelSkeletonList(count: 8)
                // P-002: Skeleton auch während DB-Suche
                : _isSuche
                    ? const ArtikelSkeletonList(count: 4)
                    : gefiltert.isEmpty
                        ? Center(
                            child: Text(
                              _suchbegriff.isNotEmpty
                                  ? 'Keine Artikel für "$_suchbegriff" gefunden'
                                  : 'Keine Artikel gefunden',
                              style: textTheme.titleSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _ladeArtikel,
                            child: ListView.builder(
                              controller: _scrollController,
                              // M-005: Footer nur wenn keine Suche aktiv
                              itemCount: gefiltert.length +
                                  (_hasMore && _suchbegriff.isEmpty ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == gefiltert.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: AppConfig.spacingLarge,
                                    ),
                                    child: Center(
                                      child: SizedBox(
                                        width:
                                            AppConfig.progressIndicatorSizeSmall,
                                        height:
                                            AppConfig.progressIndicatorSizeSmall,
                                        child: CircularProgressIndicator(
                                          strokeWidth:
                                              AppConfig.strokeWidthMedium,
                                        ),
                                      ),
                                    ),
                                  );
                                }
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
          FloatingActionButton(
            heroTag: 'scan',
            onPressed: () async {
              await ScanService.scanArtikel(
                context,
                _artikelListe,
                _ladeArtikel,
                setState,
                _db,
              );
            },
            tooltip: ScanService.hasCameraScanner
                ? 'Artikel scannen'
                : 'Artikel per UUID suchen',
            child: Icon(
              ScanService.hasCameraScanner
                  ? Icons.qr_code_scanner
                  : Icons.search,
            ),
          ),
          const SizedBox(width: AppConfig.spacingMedium),
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      // M-011: Zentrales Bild-Widget statt inline Image.network / Image.file
      leading: ArtikelListBild(artikel: artikel),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              artikel.name,
              style: textTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            artikel.menge.toString(),
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // M-007: Artikelnummer anzeigen
          if (artikel.artikelnummer != null)
            Text(
              'Art.-Nr.: ${artikel.artikelnummer}',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          Text(
            artikel.beschreibung,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${artikel.ort.trim()} • ${artikel.fach.trim()}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      isThreeLine: true,
      onTap: () => _openDetailScreen(artikel),
    );
  }

  // ==================== DETAIL SCREEN ====================

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

    final colorScheme = Theme.of(context).colorScheme;

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
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
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
    final colorScheme = Theme.of(context).colorScheme;

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
        PopupMenuItem(
          value: _MenuAction.pdfReports,
          child: ListTile(
            leading: Icon(Icons.picture_as_pdf, color: colorScheme.error),
            title: const Text('PDF-Berichte'),
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
    final colorScheme = Theme.of(context).colorScheme;

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
              child: Row(
                children: [
                  Icon(Icons.file_upload, color: colorScheme.primary),
                  const SizedBox(width: AppConfig.spacingSmall),
                  const Expanded(
                    child: Text('Artikel importieren (JSON/CSV)'),
                  ),
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
              child: Row(
                children: [
                  Icon(Icons.file_download, color: colorScheme.tertiary),
                  const SizedBox(width: AppConfig.spacingSmall),
                  const Expanded(
                    child: Text('Artikel exportieren (JSON/CSV)'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPdfReportsDialog() async {
    final colorScheme = Theme.of(context).colorScheme;

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
              child: Row(
                children: [
                  Icon(Icons.list_alt, color: colorScheme.error),
                  const SizedBox(width: AppConfig.spacingSmall),
                  const Expanded(
                    child: Text('Komplette Artikelliste als PDF'),
                  ),
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
              child: Row(
                children: [
                  Icon(Icons.filter_list, color: colorScheme.secondary),
                  const SizedBox(width: AppConfig.spacingSmall),
                  const Expanded(
                    child: Text('Gefilterte Artikelliste als PDF'),
                  ),
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
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: AppConfig.spacingSmall),
                  const Expanded(
                    child: Text('Einzelner Artikel als Detail-PDF'),
                  ),
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