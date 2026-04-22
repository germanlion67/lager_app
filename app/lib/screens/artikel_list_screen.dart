// lib/screens/artikel_list_screen.dart

//   B-008 — _buildArtikelTile(): Card-Layout mit allen Feldern wiederhergestellt.
//            Artikelnummer (nullable int), Beschreibung, Ort, Fach, Menge als Chips.
//   B-009 — Ort-Dropdown aus AppBar entfernt, in Body mit echten Daten implementiert.
//            _aktualisiereVerfuegbareOrte(): distinct, alphabetisch, aus _artikelListe.
//   B-010 — _showSnackBar(): Zentrale Hilfsmethode. Feedback bei Sync-Start/-Erfolg/-Fehler.
//   B-012 — Sync-Label: overflow + maxLines. titleSpacing + Padding gegen AppBar-Overflow.

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

import 'list_screen_mobile_actions.dart'
    if (dart.library.html) 'list_screen_web_actions.dart'
    as mobile_actions;

class ArtikelListScreen extends StatefulWidget {
  const ArtikelListScreen({
    super.key,
    this.nextcloudService,
    this.initialArtikel,
    this.syncStatusProvider,
  });

  final NextcloudServiceInterface? nextcloudService;
  final List<Artikel>? initialArtikel;
  final SyncStatusProvider? syncStatusProvider;

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

  @override
  void initState() {
    super.initState();
    _db = ArtikelDbService();
    _pbService = PocketBaseService();
    _scrollController.addListener(_onScroll);

    if (widget.initialArtikel != null) {
      _artikelListe = List<Artikel>.from(widget.initialArtikel!);
      _isLoading = false;
      // B-009: Orte aus initialArtikel ableiten
      _aktualisiereVerfuegbareOrte();
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

      // B-010: Snackbar-Feedback bei Sync-Ergebnis
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

  // ── B-009: Orte aus der geladenen Liste ableiten ─────────────────────────
  // Distinct, nicht-leere Werte, alphabetisch sortiert.
  void _aktualisiereVerfuegbareOrte() {
    final orte = _artikelListe
        .map((a) => a.ort.trim())
        .where((o) => o.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    setState(() => _verfuegbareOrte = orte);
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
      // B-009: Orte nach jedem Laden aktualisieren
      _aktualisiereVerfuegbareOrte();
    } catch (e) {
      _logger.e('Fehler beim Laden: $e');
      _showSnackBar('❌ Fehler beim Laden der Artikel', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleManualSync() async {
    if (_isSyncRunning) return;
    // B-010: Feedback beim Start des manuellen Syncs
    _showSnackBar('🔄 Synchronisierung gestartet…');
    await widget.syncStatusProvider?.runOnce();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
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
      });
      // B-009: Orte nach Nachladen aktualisieren
      _aktualisiereVerfuegbareOrte();
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  void _onSuchbegriffChanged(String value) {
    _debounceTimer?.cancel();
    setState(() => _suchbegriff = value);
    _debounceTimer = Timer(
      const Duration(milliseconds: 500),
      () => _fuehreSucheAus(value),
    );
  }

  Future<void> _fuehreSucheAus(String query) async {
    if (!mounted) return;
    if (query.isEmpty) {
      setState(() {
        _isSuche = false;
        _suchErgebnisse = [];
      });
      return;
    }
    setState(() => _isSuche = true);
    final results = await _db.searchArtikel(query);
    if (!mounted) return;
    setState(() {
      _suchErgebnisse = results;
      _isSuche = false;
    });
  }

  Future<void> _checkPocketBaseConnection() async {
    final ok = await _pbService.checkHealth();
    if (mounted) setState(() => _pbConnected = ok);
  }

  List<Artikel> _gefilterteArtikel() {
    final basis = _suchbegriff.isNotEmpty ? _suchErgebnisse : _artikelListe;
    if (_filterOrt.isEmpty) return basis;
    return basis.where((a) => a.ort.trim() == _filterOrt.trim()).toList();
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final gefiltert = _gefilterteArtikel();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        // B-012: Flexible title verhindert Overflow auf schmalen Displays
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
              // B-012 + F-007: overflow sichert Darstellung auf S20,
              // ValueListenableBuilder reagiert sofort auf Toggle in Einstellungen
              ValueListenableBuilder<bool>(
                valueListenable: showLastSyncNotifier,
                builder: (context, showSync, _) {
                  if (!showSync || widget.syncStatusProvider?.lastSyncTime == null) {
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
          // B-009: Dropdown aus actions ENTFERNT — jetzt im Body (siehe unten)
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
      body: Column(
        children: [
          // ── Suchleiste + Scanner ─────────────────────────────────────────
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

          // ── B-009: Ort-Filter — im Body, mit echten Daten ───────────────
          if (_verfuegbareOrte.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConfig.spacingSmall,
                AppConfig.spacingXSmall,
                AppConfig.spacingSmall,
                0,
              ),
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
                        // Erster Eintrag: "Alle Orte" → setzt Filter zurück
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Alle Orte'),
                        ),
                        // Echte Orte aus der Artikelliste, alphabetisch
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
                      onChanged: (String? newValue) {
                        setState(() => _filterOrt = newValue ?? '');
                      },
                    ),
                  ),
                  // Aktiver Filter → Reset-Button anzeigen
                  if (_filterOrt.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Filter zurücksetzen',
                      onPressed: () => setState(() => _filterOrt = ''),
                    ),
                ],
              ),
            ),

          const SizedBox(height: AppConfig.spacingXSmall),

          // ── Artikelliste ─────────────────────────────────────────────────
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
                        : ListView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount:
                                gefiltert.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == gefiltert.length) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              return _buildArtikelTile(gefiltert[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── B-008: Vollständiges Card-Layout wiederhergestellt ───────────────────
  Widget _buildArtikelTile(Artikel artikel) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacingSmall,
        vertical: AppConfig.spacingXSmall,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConfig.cardBorderRadiusSmall),
        onTap: () => Navigator.push<Artikel?>(
          context,
          MaterialPageRoute<Artikel?>(
            builder: (_) => ArtikelDetailScreen(artikel: artikel),
          ),
        ).then((_) => _ladeArtikel()),
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
                        if (artikel.artikelnummer != null)
                          Text(
                            '#${artikel.artikelnummer}',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (artikel.artikelnummer != null)
                          const SizedBox(width: AppConfig.spacingXSmall),
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

                    // Zeile 3: Ort, Fach, Menge — als Chips
                    Wrap(
                      spacing: AppConfig.spacingXSmall,
                      runSpacing: 2,
                      children: [
                        if (artikel.ort.isNotEmpty)
                          _buildInfoChip(
                            icon: Icons.place_outlined,
                            label: artikel.ort,
                            colorScheme: colorScheme,
                            textTheme: textTheme,
                          ),
                        if (artikel.fach.isNotEmpty)
                          _buildInfoChip(
                            icon: Icons.grid_view_outlined,
                            label: artikel.fach,
                            colorScheme: colorScheme,
                            textTheme: textTheme,
                          ),
                        _buildInfoChip(
                          icon: Icons.inventory_2_outlined,
                          label: '${artikel.menge} Stk',
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Pfeil-Icon
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

  // ── Hilfs-Widget: Info-Chip für Ort / Fach / Menge ───────────────────────
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
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
            builder: (_) => const SettingsScreen(),
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

enum _MenuAction { importExport, pdfReports, resetDb, showLog, settings }