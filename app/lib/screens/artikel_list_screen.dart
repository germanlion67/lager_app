// lib/screens/artikel_list_screen.dart
//
//   P-007 — _gefilterteArtikel() gecacht (P-007.1). setState() aus _onSuchbegriffChanged()
//            entfernt (P-007.2). _aktualisiereFilter() ohne eigenes setState() (P-007.3).
//            Scroll-Guard früher im _onScroll()-Pfad (P-007.5).
//            _buildArtikelTile() + _buildInfoChip() als _ArtikelTile / _ArtikelInfoChip
//            StatelessWidgets extrahiert (P-007.4).
//   B-008 — _buildArtikelTile(): Card-Layout mit allen Feldern wiederhergestellt.
//            Artikelnummer (nullable int), Beschreibung, Ort, Fach, Menge als Chips.
//   B-009 — Ort-Dropdown aus AppBar entfernt, in Body mit echten Daten implementiert.
//            _aktualisiereFilter(): distinct, alphabetisch, aus _artikelListe.
//   B-010 — _showSnackBar(): Zentrale Hilfsmethode. Feedback bei Sync-Start/-Erfolg/-Fehler.
//   B-012 — Sync-Label: overflow + maxLines. titleSpacing + Padding gegen AppBar-Overflow.
//   B-018 — _fuehreSucheAus(): Artikelnummer in lokaler Suche ergänzt (int-Vergleich).
//            Web-Filter um artikelnummer-Feld erweitert (numerisch + textuell).
//   O-017 — catch (e) → catch (e, st) in _ladeArtikel() und _ladeNaechsteSeite().
//   P-007 — _gefilterteArtikel() gecacht (P-007.1). setState() aus _onSuchbegriffChanged()
//            entfernt (P-007.2). _aktualisiereFilter() ohne eigenes setState() (P-007.3).
//            Scroll-Guard früher im _onScroll()-Pfad (P-007.5).
//   F-011.3 — Desktop: 2-Spalten-Grid statt ListView.
//   F-011.5 — Desktop: NavigationRail links (Artikel / Sync / Einstellungen).

import 'dart:async';

import 'package:flutter/foundation.dart';
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
import '../services/nextcloud_service_interface.dart';
import '../services/sync_status_provider.dart';
import '../services/sync_orchestrator.dart' show SyncStatus;

import '../widgets/artikel_bild_widget.dart';

import 'artikel_detail_screen.dart';
import 'artikel_erfassen_screen.dart';
import 'settings_screen.dart';
import 'settings_state.dart';
import '../core/responsive.dart';

import 'list_screen_mobile_actions.dart'
    if (dart.library.html) 'list_screen_web_actions.dart'
    as mobile_actions;

class ArtikelListScreen extends StatefulWidget {
  const ArtikelListScreen({
    super.key,
    this.nextcloudService,
    this.initialArtikel,
    this.syncStatusProvider,
    this.onLogout,
    this.onSyncIntervalChanged,
  });

  final NextcloudServiceInterface? nextcloudService;
  final List<Artikel>? initialArtikel;
  final SyncStatusProvider? syncStatusProvider;
  final VoidCallback? onLogout;
  final void Function(int seconds)? onSyncIntervalChanged;

  @override
  State<ArtikelListScreen> createState() => _ArtikelListScreenState();
}

class _ArtikelListScreenState extends State<ArtikelListScreen> {
  final Logger _logger = AppLogService.logger;

  List<Artikel> _artikelListe = [];
  String _suchbegriff = '';
  String _filterOrt = '';
  String _filterKategorie = '';
  bool _isLoading = true;
  bool? _pbConnected;

  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;

  Timer? _debounceTimer;
  List<Artikel> _suchErgebnisse = [];
  bool _isSuche = false;

  late final ArtikelDbService _db;
  late final PocketBaseService _pbService;

  NextcloudServiceInterface? _nextcloudService;

  StreamSubscription<SyncStatus>? _syncSubscription;
  bool _isSyncRunning = false;

  // B-009: Verfügbare Orte für den Filter — dynamisch aus _artikelListe
  List<String> _verfuegbareOrte = [];
  List<String> _verfuegbareKategorien = [];

  // P-007.1: Cache für _gefilterteArtikel()
  List<Artikel> _gefilterteArtikelCache = [];
  String _letzterFilterOrt = '';
  String _letzterFilterKategorie = '';
  List<Artikel>? _letzteFilterBasis;

  @override
  void initState() {
    super.initState();
    _db = ArtikelDbService();
    _pbService = PocketBaseService();
    _scrollController.addListener(_onScroll);

    if (widget.initialArtikel != null) {
      _artikelListe = List<Artikel>.from(widget.initialArtikel!);
      _isLoading = false;
      _aktualisiereFilterOhneSetState();
    } else {
      _ladeArtikel();
    }

    if (!kIsWeb) {
      _checkPocketBaseConnection();
      try {
        _nextcloudService =
            widget.nextcloudService ?? NextcloudConnectionService();
        _nextcloudService!.startPeriodicCheck();
      } catch (e, st) {
        _logger.e('Nextcloud-Init fehlgeschlagen:', error: e, stackTrace: st);
      }
    } else {
      _pbConnected = true;
    }

    _isSyncRunning = widget.syncStatusProvider?.isSyncing ?? false;
    _syncSubscription =
        widget.syncStatusProvider?.syncStatus.listen((status) {
      if (!mounted) return;
      setState(() {
        _isSyncRunning = (status == SyncStatus.running);
      });

      if (status == SyncStatus.success) {
        _ladeArtikel();
        _showSnackBar('✅ Synchronisierung abgeschlossen');
      } else if (status == SyncStatus.error) {
        _showSnackBar('❌ Synchronisierung fehlgeschlagen', isError: true);
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _nextcloudService?.dispose();
    super.dispose();
  }

  // ── P-007.3: Filter ohne eigenes setState() ───────────────────────────────
  void _aktualisiereFilterOhneSetState() {
    _verfuegbareOrte = _artikelListe
        .map((a) => a.ort.trim())
        .where((o) => o.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    _verfuegbareKategorien = _artikelListe
        .map((a) => (a.kategorie ?? '').trim())
        .where((k) => k.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  // ── B-010: Zentrale Snackbar-Hilfsmethode ────────────────────────────────
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : null,
      ),
    );
  }

  Future<void> _ladeArtikel() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _currentOffset = 0;
      _hasMore = true;
      _artikelListe = [];
      _suchErgebnisse = [];
      _isSuche = false;
    });

    try {
      if (kIsWeb) {
        final records = await _pbService.client
            .collection('artikel')
            .getFullList(sort: '-created');
        _artikelListe =
            records.map((r) => Artikel.fromPocketBase(r.data, r.id)).toList();
        _hasMore = false;
      } else {
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
      _showSnackBar('❌ Fehler beim Laden der Artikel', isError: true);
    } finally {
      if (mounted) {
        _aktualisiereFilterOhneSetState();
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleManualSync() async {
    if (_isSyncRunning) return;
    _showSnackBar('🔄 Synchronisierung gestartet…');
    await widget.syncStatusProvider?.runOnce();
  }

  // P-007.5: Guard früher — vor dem Pixel-Vergleich
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _ladeNaechsteSeite();
    }
  }

  Future<void> _ladeNaechsteSeite() async {
    if (_isLoadingMore || !_hasMore || _suchbegriff.isNotEmpty) return;
    setState(() => _isLoadingMore = true);
    try {
      final seite = await _db.getAlleArtikel(
        limit: AppConfig.paginationPageSize,
        offset: _currentOffset,
      );
      setState(() {
        _artikelListe.addAll(seite);
        _currentOffset += seite.length;
        _hasMore = seite.length >= AppConfig.paginationPageSize;
        _aktualisiereFilterOhneSetState();
      });
    } catch (e, st) {
      _logger.e('Fehler beim Nachladen:', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // P-007.2: setState() entfernt — _suchbegriff wird erst in _fuehreSucheAus()
  //          gesetzt.
  void _onSuchbegriffChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 500),
      () => _fuehreSucheAus(value),
    );
  }

  Future<void> _fuehreSucheAus(String query) async {
    if (!mounted) return;

    if (query.isEmpty) {
      setState(() {
        _suchbegriff = '';
        _isSuche = false;
        _suchErgebnisse = [];
      });
      await _ladeArtikel();
      return;
    }

    setState(() {
      _suchbegriff = query;
      _isSuche = true;
    });

    List<Artikel> results;
    if (kIsWeb) {
      final pb = _pbService.client;
      final trimmed = query.trim();
      final isNumeric = int.tryParse(trimmed) != null;

      final filterString = isNumeric
          ? 'artikelnummer = ${int.parse(trimmed)} && deleted = false'
          : '(name ~ "$trimmed" || beschreibung ~ "$trimmed" || '
            'artikelnummer ~ "$trimmed") && deleted = false';

      final records = await pb.collection('artikel').getFullList(
        filter: filterString,
        sort: '-created',
      );
      results =
          records.map((r) => Artikel.fromPocketBase(r.data, r.id)).toList();
    } else {
      results = await _db.searchArtikel(query);
    }

    if (!mounted) return;
    setState(() {
      _suchErgebnisse = results;
      _isSuche = false;
      _hasMore = false;
    });
  }

  Future<void> _checkPocketBaseConnection() async {
    final ok = await _pbService.checkHealth();
    if (mounted) setState(() => _pbConnected = ok);
  }

  // P-007.1: Gecachte Filterberechnung.
  List<Artikel> _gefilterteArtikel() {
    final basis =
        _suchbegriff.isNotEmpty ? _suchErgebnisse : _artikelListe;

    if (identical(basis, _letzteFilterBasis) &&
        _filterOrt == _letzterFilterOrt &&
        _filterKategorie == _letzterFilterKategorie) {
      return _gefilterteArtikelCache;
    }

    _letzteFilterBasis = basis;
    _letzterFilterOrt = _filterOrt;
    _letzterFilterKategorie = _filterKategorie;

    _gefilterteArtikelCache = basis.where((a) {
      if (_filterOrt.isNotEmpty && a.ort.trim() != _filterOrt) {
        return false;
      }
      if (_filterKategorie.isNotEmpty &&
          (a.kategorie ?? '').trim() != _filterKategorie) {
        return false;
      }
      return true;
    }).toList();

    return _gefilterteArtikelCache;
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  // ── F-011.5: NavigationRail für Desktop ──────────────────────────────────
  Widget _buildNavigationRail(ColorScheme colorScheme) {
    return NavigationRail(
      selectedIndex: 0, // Artikelliste ist immer aktiv in diesem Screen
      labelType: NavigationRailLabelType.all,
      leading: const SizedBox(height: AppConfig.spacingSmall),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: Text('Artikel'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.sync_outlined),
          selectedIcon: Icon(Icons.sync),
          label: Text('Sync'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Einstellungen'),
        ),
      ],
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            // Bereits auf Artikelliste — nichts tun
            break;
          case 1:
            _handleManualSync();
          case 2:
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(
                  onLogout: widget.onLogout,
                  onSyncIntervalChanged: widget.onSyncIntervalChanged,
                ),
              ),
            );
        }
      },
    );
  }

  // ── F-011.5: Body-Inhalt als eigene Methode ───────────────────────────────
  // Wird in Mobile direkt und in Desktop als Expanded-Kind der Row verwendet.
  Widget _buildBodyContent(
    List<Artikel> gefiltert,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Column(
      children: [
        // ── Suchleiste + Scanner ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConfig.spacingSmall,
            AppConfig.spacingSmall,
            AppConfig.spacingSmall,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('articleSearchField'),
                  decoration: const InputDecoration(
                    labelText: 'Suche…',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: _onSuchbegriffChanged,
                ),
              ),
              const SizedBox(width: AppConfig.spacingSmall),
              IconButton.filled(
                key: const Key('qrScannerButton'),
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () => ScanService.scanArtikel(
                  context,
                  _artikelListe,
                  _ladeArtikel,
                  setState,
                  _db,
                ),
              ),
            ],
          ),
        ),

        // ── Ort- und Kategorie-Filter ──────────────────────────────────────
        if (_verfuegbareOrte.isNotEmpty || _verfuegbareKategorien.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConfig.spacingSmall,
              AppConfig.spacingXSmall,
              AppConfig.spacingSmall,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Ort-Filter
                if (_verfuegbareOrte.isNotEmpty)
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 18),
                        const SizedBox(width: AppConfig.spacingXSmall),
                        Expanded(
                          child: DropdownButton<String>(
                            key: const Key('locationFilterDropdown'),
                            value: _filterOrt.isEmpty ? null : _filterOrt,
                            hint: const Text('Alle Orte'),
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            isDense: true,
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Alle Orte'),
                              ),
                              ..._verfuegbareOrte.map(
                                (ort) => DropdownMenuItem<String>(
                                  value: ort,
                                  child: Text(
                                    ort,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _filterOrt = v ?? ''),
                          ),
                        ),
                        if (_filterOrt.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            tooltip: 'Ort-Filter zurücksetzen',
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                setState(() => _filterOrt = ''),
                          ),
                      ],
                    ),
                  ),

                if (_verfuegbareOrte.isNotEmpty &&
                    _verfuegbareKategorien.isNotEmpty)
                  const SizedBox(width: AppConfig.spacingSmall),

                // Kategorie-Filter
                if (_verfuegbareKategorien.isNotEmpty)
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.category_outlined, size: 18),
                        const SizedBox(width: AppConfig.spacingXSmall),
                        Expanded(
                          child: DropdownButton<String>(
                            key: const Key('categoryFilterDropdown'),
                            value: _filterKategorie.isEmpty
                                ? null
                                : _filterKategorie,
                            hint: const Text('Alle Kategorien'),
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            isDense: true,
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Alle Kategorien'),
                              ),
                              ..._verfuegbareKategorien.map(
                                (kat) => DropdownMenuItem<String>(
                                  value: kat,
                                  child: Text(
                                    kat,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _filterKategorie = v ?? ''),
                          ),
                        ),
                        if (_filterKategorie.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            tooltip: 'Kategorie-Filter zurücksetzen',
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                setState(() => _filterKategorie = ''),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

        const SizedBox(height: AppConfig.spacingXSmall),

        // ── Artikelliste / Grid ────────────────────────────────────────────
        Expanded(
          child: _isLoading || _isSuche
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _handleManualSync,
                  child: gefiltert.isEmpty
                      ? const SingleChildScrollView(
                          physics: AlwaysScrollableScrollPhysics(),
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 100),
                              child: Text('Keine Artikel gefunden.'),
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final isDesktop =
                                Responsive.fromConstraints(constraints) ==
                                    ScreenSize.desktop;

                            // F-011.3: Desktop → 2-Spalten-Grid
                            if (isDesktop) {
                              return GridView.builder(
                                controller: _scrollController,
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(
                                  AppConfig.spacingSmall,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: AppConfig.spacingSmall,
                                  mainAxisSpacing: AppConfig.spacingXSmall,
                                  childAspectRatio: 3.2,
                                ),
                                itemCount: gefiltert.length +
                                    (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == gefiltert.length) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  return _ArtikelTile(
                                    artikel: gefiltert[index],
                                    onTap: () => Navigator.push<Artikel?>(
                                      context,
                                      MaterialPageRoute<Artikel?>(
                                        builder: (_) => ArtikelDetailScreen(
                                          artikel: gefiltert[index],
                                        ),
                                      ),
                                    ).then((_) => _ladeArtikel()),
                                  );
                                },
                              );
                            }

                            // Mobile/Tablet → ListView
                            return ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: gefiltert.length +
                                  (_isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == gefiltert.length) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                return _ArtikelTile(
                                  artikel: gefiltert[index],
                                  onTap: () => Navigator.push<Artikel?>(
                                    context,
                                    MaterialPageRoute<Artikel?>(
                                      builder: (_) => ArtikelDetailScreen(
                                        artikel: gefiltert[index],
                                      ),
                                    ),
                                  ).then((_) => _ladeArtikel()),
                                );
                              },
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final gefiltert = _gefilterteArtikel();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: AppConfig.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Artikelliste'),
                  const SizedBox(width: 8),
                  _buildConnectionStatusIcon(),
                ],
              ),
              ValueListenableBuilder<bool>(
                valueListenable: showLastSyncNotifier,
                builder: (context, showSync, _) {
                  if (!showSync ||
                      widget.syncStatusProvider?.lastSyncTime == null) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    'Letzter Sync: '
                    '${_formatTime(widget.syncStatusProvider!.lastSyncTime!)}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            key: const Key('addArticleButton'),
            icon: const Icon(Icons.add),
            tooltip: 'Neuen Artikel erfassen',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ArtikelErfassenScreen(),
              ),
            ).then((_) => _ladeArtikel()),
          ),
          _isSyncRunning
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  key: const Key('refreshButton'),
                  icon: const Icon(Icons.sync),
                  tooltip: 'Aktualisieren',
                  onPressed: _handleManualSync,
                ),
          PopupMenuButton<_MenuAction>(
            key: const Key('menuButton'),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => _buildMenuItems(),
          ),
        ],
      ),

      // F-011.5: LayoutBuilder → Desktop mit NavigationRail, Mobile ohne
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop =
              Responsive.fromConstraints(constraints) == ScreenSize.desktop;

          final bodyContent =
              _buildBodyContent(gefiltert, colorScheme, textTheme);

          if (!isDesktop) return bodyContent;

          // Desktop: NavigationRail links + VerticalDivider + Content rechts
          return Row(
            children: [
              _buildNavigationRail(colorScheme),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: bodyContent),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatusIcon() {
    return Icon(
      Icons.dns,
      color: _pbConnected == true ? Colors.green : Colors.red,
      size: 16,
    );
  }

  List<PopupMenuEntry<_MenuAction>> _buildMenuItems() {
    return [
      const PopupMenuItem(
        value: _MenuAction.importExport,
        child: Text('Import/Export'),
      ),
      const PopupMenuItem(
        value: _MenuAction.pdfReports,
        child: Text('PDF Berichte'),
      ),
      const PopupMenuItem(
        value: _MenuAction.resetDb,
        child: Text('DB Reset'),
      ),
      const PopupMenuItem(
        value: _MenuAction.showLog,
        child: Text('Logs'),
      ),
      const PopupMenuItem(
        value: _MenuAction.settings,
        child: Text('Einstellungen'),
      ),
    ];
  }

  Future<void> _handleMenuAction(_MenuAction action) async {
    switch (action) {
      case _MenuAction.importExport:
        await _importExportDialog();
      case _MenuAction.pdfReports:
        await _showPdfReportsDialog();
      case _MenuAction.resetDb:
        await _handleResetDb();
      case _MenuAction.showLog:
        await AppLogService.showLogDialog(context);
      case _MenuAction.settings:
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SettingsScreen(
              onLogout: widget.onLogout,
              onSyncIntervalChanged: widget.onSyncIntervalChanged,
            ),
          ),
        );
    }
  }

  Future<void> _importExportDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Import/Export'),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                ArtikelImportService.importArtikel(context, _ladeArtikel),
            child: const Text('Importieren'),
          ),
          SimpleDialogOption(
            onPressed: () =>
                ArtikelExportService().showExportDialog(context),
            child: const Text('Exportieren'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPdfReportsDialog() async {
    await mobile_actions.generateArtikelListePdf(context, _artikelListe);
  }

  Future<void> _handleResetDb() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nein'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ja'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.resetDatabase();
      await _ladeArtikel();
    }
  }
}

// ── P-007.4: _ArtikelTile als StatelessWidget extrahiert ─────────────────
class _ArtikelTile extends StatelessWidget {
  const _ArtikelTile({
    required this.artikel,
    required this.onTap,
  });

  final Artikel artikel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacingSmall,
        vertical: AppConfig.spacingXSmall,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConfig.cardBorderRadiusSmall),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppConfig.spacingSmall),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bild
              ArtikelListBild(artikel: artikel),
              const SizedBox(width: AppConfig.spacingMedium),

              // Textinfos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Zeile 1: Artikelnummer + Name
                    Row(
                      children: [
                        if (artikel.artikelnummer != null) ...[
                          Text(
                            '#${artikel.artikelnummer}',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: AppConfig.spacingXSmall),
                        ],
                        Expanded(
                          child: Text(
                            artikel.name,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),

                    // Zeile 2: Beschreibung
                    if (artikel.beschreibung.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        artikel.beschreibung,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],

                    const SizedBox(height: AppConfig.spacingXSmall),

                    // Zeile 3: Chips
                    Wrap(
                      spacing: AppConfig.spacingXSmall,
                      runSpacing: 2,
                      children: [
                        if (artikel.ort.isNotEmpty)
                          _ArtikelInfoChip(
                            icon: Icons.place_outlined,
                            label: artikel.ort,
                          ),
                        if (artikel.kategorie != null &&
                            artikel.kategorie!.isNotEmpty)
                          _ArtikelInfoChip(
                            icon: Icons.category_outlined,
                            label: artikel.kategorie!,
                          ),
                        if (artikel.fach.isNotEmpty)
                          _ArtikelInfoChip(
                            icon: Icons.grid_view_outlined,
                            label: artikel.fach,
                          ),
                        _ArtikelInfoChip(
                          icon: Icons.inventory_2_outlined,
                          label: '${artikel.menge} Stk',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Pfeil
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
                size: AppConfig.iconSizeMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _ArtikelInfoChip ──────────────────────────────────────────────────────
class _ArtikelInfoChip extends StatelessWidget {
  const _ArtikelInfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacingXSmall,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConfig.borderRadiusXSmall),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

enum _MenuAction { importExport, pdfReports, resetDb, showLog, settings }