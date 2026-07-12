// lib/screens/artikel_list_screen.dart
//
// F-011.7: Master-Detail-Layout für Desktop.
//          Liste links, Detail rechts (inline) ab breakpointTablet.
//          Mobile: weiterhin Navigator.push() zum ArtikelDetailScreen.

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
import '../services/pocketbase_service.dart';
import '../services/scan_service.dart';
import '../services/sync_status_provider.dart';
import '../services/sync_orchestrator.dart' show SyncStatus;

import '../widgets/artikel_bild_widget.dart';
import '../widgets/artikel_detail_content.dart';

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
    this.initialArtikel,
    this.syncStatusProvider,
    this.onLogout,
    this.onSyncIntervalChanged,
  });

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


  StreamSubscription<SyncStatus>? _syncSubscription;
  bool _isSyncRunning = false;

  List<String> _verfuegbareOrte = [];
  List<String> _verfuegbareKategorien = [];

  // P-007.1: Cache für _gefilterteArtikel()
  List<Artikel> _gefilterteArtikelCache = [];
  String _letzterFilterOrt = '';
  String _letzterFilterKategorie = '';
  List<Artikel>? _letzteFilterBasis;

  // F-011.7 / F-011.9: Panel-Steuerung für Master-Detail (Desktop)
  _PanelMode _panelMode = _PanelMode.none;
  Artikel? _selectedArtikel; // nur relevant wenn _panelMode == detail
  
  // F-011.7: GlobalKey für Detail-Content im Master-Detail-Panel
  GlobalKey<ArtikelDetailContentState> _detailContentKey = GlobalKey();

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
    super.dispose();
  }

  // ── Filter ────────────────────────────────────────────────────────────────

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

        // F-011.7 / F-011.9: Ausgewählten Artikel nach Reload aktualisieren.
        // Erfassen-Panel bleibt offen — wird nicht zurückgesetzt.
        if (_panelMode == _PanelMode.detail && _selectedArtikel != null) {
          final stillExists = _artikelListe.any(
            (a) => a.uuid == _selectedArtikel!.uuid,
          );
          if (!stillExists) {
            _panelMode = _PanelMode.none;
            _selectedArtikel = null;
          } else {
            _selectedArtikel = _artikelListe.firstWhere(
              (a) => a.uuid == _selectedArtikel!.uuid,
            );
          }
        }
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleManualSync() async {
    if (_isSyncRunning) return;
    _showSnackBar('🔄 Synchronisierung gestartet…');
    await widget.syncStatusProvider?.runOnce();
  }

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

  // ── F-011.7: Artikel auswählen (Desktop) oder navigieren (Mobile) ────────

  void _onArtikelTap(Artikel artikel, bool isDesktop) {
    if (isDesktop) {
      // F-011.9: Erfassen-Panel schließen wenn Artikel angetippt wird
      setState(() {
        _panelMode = _PanelMode.detail;
        _selectedArtikel = artikel;
        _detailContentKey = GlobalKey(); // ← NEU: frischer Key pro Artikel
      });
    } else {
      Navigator.push<Artikel?>(
        context,
        MaterialPageRoute<Artikel?>(
          builder: (_) => ArtikelDetailScreen(artikel: artikel),
        ),
      ).then((_) => _ladeArtikel());
    }
  }

  // ── F-011.7: Callbacks für embedded Detail-Content ────────────────────────

  void _onDetailSaved(Artikel gespeicherterArtikel) {
    _ladeArtikel();
    _showSnackBar('✅ Artikel gespeichert');
  }

  void _onDetailDeleted() {
    setState(() {
      _panelMode = _PanelMode.none;
      _selectedArtikel = null;
    });
    _ladeArtikel();
    _showSnackBar('🗑️ Artikel gelöscht');
  }

  // F-012.2: Callback damit _DetailPanelHeader sich rebuildet
  // wenn sich der ArtikelDetailContent-State ändert (Edit-Modus, etc.)
  void _onDetailStateChanged() {
    if (mounted) setState(() {});
  }

  // ── NavigationRail ────────────────────────────────────────────────────────

  Widget _buildNavigationRail(ColorScheme colorScheme) {
    // F-012.5: selectedIndex spiegelt aktiven Panel-Modus wider
    
    return NavigationRail(
      selectedIndex: _panelMode == _PanelMode.settings ? 1 : 0,
      labelType: NavigationRailLabelType.all,
      leading: const SizedBox(height: AppConfig.spacingSmall),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: Text('Artikel'),
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
            // F-012.5: Settings-Panel schließen → zurück zur Artikelliste
            if (_panelMode == _PanelMode.settings) {
              setState(() {
                _panelMode = _PanelMode.none;
                });
            }
          case 1:
            // F-012.5: Desktop → Settings als Panel; Mobile → Navigator.push
            // (NavigationRail wird nur auf Desktop gerendert, kein kIsWeb-Guard
            //  nötig — Mobile sieht diese Rail nie)
            setState(() {
              _panelMode = _PanelMode.settings;
              _selectedArtikel = null;
            });
           
        }
      },
    );
  }

  // ── Artikelliste (Suchfeld + Filter + Liste/Grid) ─────────────────────────

  Widget _buildListContent(
    List<Artikel> gefiltert,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isDesktop,
  ) {
    return Column(
      children: [
        // Suchleiste + Scanner
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

        // Ort- und Kategorie-Filter
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
                if (_verfuegbareOrte.isNotEmpty)
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 18),
                        const SizedBox(width: AppConfig.spacingXSmall),
                        Expanded(
                          child: DropdownButton<String>(
                            key: const Key('locationFilterDropdown'),
                            value:
                                _filterOrt.isEmpty ? null : _filterOrt,
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

        // Artikelliste
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
                          itemCount: gefiltert.length +
                              (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == gefiltert.length) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final artikel = gefiltert[index];
                            return _ArtikelTile(
                              artikel: artikel,
                              isSelected: isDesktop &&
                                  _selectedArtikel?.uuid == artikel.uuid,
                              onTap: () =>
                                  _onArtikelTap(artikel, isDesktop),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  // ── F-011.7: Detail-Panel für Desktop ─────────────────────────────────────

  Widget _buildDetailPanel(ColorScheme colorScheme) {
      // F-012.5: Settings-Panel (Desktop-Web)
      if (_panelMode == _PanelMode.settings) {
        return _buildSettingsPanel(colorScheme);
      }

    // F-011.9: Erfassen-Panel
    if (_panelMode == _PanelMode.erfassen) {
      return _buildErfassenPanel(colorScheme);
    }

    // F-011.7: Detail-Panel (unverändert, nur _selectedArtikel-Check angepasst)
    if (_panelMode != _PanelMode.detail || _selectedArtikel == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(
                alpha: AppConfig.opacityMedium,
              ),
            ),
            const SizedBox(height: AppConfig.spacingMedium),
            Text(
              'Artikel auswählen',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppConfig.spacingSmall),
            Text(
              'Wähle einen Artikel aus der Liste,\num Details anzuzeigen.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(
                      alpha: AppConfig.opacityMedium,
                    ),
                  ),
            ),
            const SizedBox(height: AppConfig.spacingLarge),
            // F-011.9: Hinweis auf ➕-Button
            FilledButton.tonal(
              onPressed: () => setState(() {
                _panelMode = _PanelMode.erfassen;
                _selectedArtikel = null;
              }),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: AppConfig.iconSizeSmall),
                  SizedBox(width: AppConfig.spacingXSmall),
                  Text('Neuen Artikel erfassen'),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Detail-Panel (F-011.7 — unverändert)
    return Column(
      children: [
        _DetailPanelHeader(
          key: ValueKey(_selectedArtikel!.uuid), // ← NEU
          contentKey: _detailContentKey,
          artikel: _selectedArtikel!,
          colorScheme: colorScheme,
          onClose: () => setState(() {
            _panelMode = _PanelMode.none;
            _selectedArtikel = null;
          }),
        ),
        const Divider(height: 1),
        Expanded(
          child: ArtikelDetailContent(
            key: _detailContentKey,
            artikel: _selectedArtikel!,
            embedded: true,
            onSaved: _onDetailSaved,
            onDeleted: _onDetailDeleted,
            onStateChanged: _onDetailStateChanged,  // ← NEU
          ),
        ),
      ],
    );
  }

  // F-011.9: Erfassen-Formular als Seitenpanel (nur Desktop)
  Widget _buildErfassenPanel(ColorScheme colorScheme) {
    return Column(
      children: [
        // Panel-Header (konsistent mit Detail-Panel)
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConfig.spacingMedium,
            vertical: AppConfig.spacingSmall,
          ),
          color: colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              const Icon(Icons.add_circle_outline, size: AppConfig.iconSizeMedium),
              const SizedBox(width: AppConfig.spacingSmall),
              Expanded(
                child: Text(
                  'Neuen Artikel erfassen',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Schließen',
                onPressed: () => setState(() {
                  _panelMode = _PanelMode.none;
                }),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // F-011.9: ArtikelErfassenScreen eingebettet als scrollbarer Inhalt
        Expanded(
          child: ArtikelErfassenScreen(
            embedded: true,
            onSaved: () {
              setState(() => _panelMode = _PanelMode.none);
              _ladeArtikel();
              _showSnackBar('✅ Artikel gespeichert');
            },
            onCancelled: () => setState(() => _panelMode = _PanelMode.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsPanel(ColorScheme colorScheme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConfig.spacingMedium,
            vertical: AppConfig.spacingSmall,
          ),
          color: colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              const Icon(Icons.settings_outlined,
                  size: AppConfig.iconSizeMedium,),
              const SizedBox(width: AppConfig.spacingSmall),
              Expanded(
                child: Text(
                  'Einstellungen',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Schließen',
                onPressed: () => setState(() {
                  _panelMode = _PanelMode.none;
                }),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SettingsScreen(
            embedded: true, // ← kein Scaffold, kein AppBar
            onLogout: widget.onLogout,
            onSyncIntervalChanged: widget.onSyncIntervalChanged,
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
              if (!kIsWeb)
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
            onPressed: () {
              // F-011.9: Desktop → Erfassen-Panel; Mobile → Navigator.push
              final isDesktop = Responsive.of(context) == ScreenSize.desktop;
              if (isDesktop) {
                setState(() {
                  _panelMode = _PanelMode.erfassen;
                  _selectedArtikel = null; // Detail-Auswahl aufheben
                });
              } else {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ArtikelErfassenScreen(),
                  ),
                ).then((_) => _ladeArtikel());
              }
            },
          ),
          if (!kIsWeb)
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

      // F-011.7: LayoutBuilder → Desktop mit Master-Detail, Mobile ohne
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenSize = Responsive.fromConstraints(constraints);
          final isDesktop = screenSize == ScreenSize.desktop;

          final listContent = _buildListContent(
            gefiltert,
            colorScheme,
            textTheme,
            isDesktop,
          );

          if (!isDesktop) return listContent;

          // Desktop: NavigationRail + Liste + Detail
          return Row(
            children: [
              _buildNavigationRail(colorScheme),
              const VerticalDivider(thickness: 1, width: 1),
              // Master (Liste)
              Expanded(
                flex: AppConfig.masterListFlex.toInt(),
                child: listContent,
              ),
              const VerticalDivider(thickness: 1, width: 1),
              // Detail
              Expanded(
                flex: AppConfig.masterDetailFlex.toInt(),
                child: _buildDetailPanel(colorScheme),
              ),
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
      // F-012.5: Desktop → Settings als Panel im Content-Bereich
      //          Mobile  → Navigator.push (unverändert)
      final isDesktop = Responsive.of(context) == ScreenSize.desktop;
      if (isDesktop) {
        setState(() {
          _panelMode = _PanelMode.settings;
          _selectedArtikel = null;
        });
      } else {
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
      setState(() {
        _panelMode = _PanelMode.none;  // ← war: _selectedArtikel = null
        _selectedArtikel = null;
      });
      await _ladeArtikel();
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// F-011.7: Detail-Panel Header (Titel + Actions + Close)
// F-012.2 / F-012.4: StatefulWidget mit addPostFrameCallback —
// stellt sicher dass contentKey.currentState beim ersten Frame
// verfügbar ist, bevor Actions gerendert werden.
// ══════════════════════════════════════════════════════════════════════════════

class _DetailPanelHeader extends StatefulWidget {
  const _DetailPanelHeader({
    super.key, // ← NEU
    required this.contentKey,
    required this.artikel,
    required this.colorScheme,
    required this.onClose,
  });

  final GlobalKey<ArtikelDetailContentState> contentKey;
  final Artikel artikel;
  final ColorScheme colorScheme;
  final VoidCallback onClose;

  @override
  State<_DetailPanelHeader> createState() => _DetailPanelHeaderState();
}

class _DetailPanelHeaderState extends State<_DetailPanelHeader> {
  @override
  void initState() {
    super.initState();
    // F-012.2 / F-012.4: Nach dem ersten Frame neu bauen —
    // zu diesem Zeitpunkt ist contentKey.currentState garantiert verfügbar,
    // da ArtikelDetailContent bereits in den Tree eingehängt wurde.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _DetailPanelHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Neuer Artikel ausgewählt → nach Frame neu bauen
    if (oldWidget.artikel.uuid != widget.artikel.uuid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _handleClose(BuildContext context) async {
    final contentState = widget.contentKey.currentState;
    if (contentState?.hasUnsavedChanges == true) {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ungespeicherte Änderungen'),
          content: const Text(
            'Der Bearbeitungsmodus wird ohne Speichern beendet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'verwerfen'),
              child: const Text('Verwerfen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'speichern'),
              child: const Text('Speichern'),
            ),
          ],
        ),
      );
      if (!context.mounted) return;
      if (result == 'speichern') {
        await contentState?.speichern();
        if (!context.mounted) return;
      } else if (result == null) {
        return; // Dialog abgebrochen (außerhalb tippen)
      }
      // result == 'verwerfen' → weiter zu onClose
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final contentState = widget.contentKey.currentState;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacingMedium,
        vertical: AppConfig.spacingSmall,
      ),
      color: widget.colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Expanded(
            child: Text(
              contentState?.titleText ?? widget.artikel.name,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (contentState != null)
            ...contentState.buildActions(widget.colorScheme),
          const SizedBox(width: AppConfig.spacingSmall),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Detail schließen',
            onPressed: () => _handleClose(context),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ArtikelTile
// ══════════════════════════════════════════════════════════════════════════════

class _ArtikelTile extends StatelessWidget {
  const _ArtikelTile({
    required this.artikel,
    required this.onTap,
    this.isSelected = false,
  });

  final Artikel artikel;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacingSmall,
        vertical: AppConfig.spacingXSmall,
      ),
      // F-011.7: Visuelles Feedback für ausgewählten Artikel
      color: isSelected ? colorScheme.primaryContainer : null,
      elevation: isSelected ? 0 : null,
      shape: isSelected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AppConfig.cardBorderRadiusSmall,
              ),
              side: BorderSide(
                color: colorScheme.primary,
                width: 2,
              ),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConfig.cardBorderRadiusSmall),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppConfig.spacingSmall),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ArtikelListBild(artikel: artikel),
              const SizedBox(width: AppConfig.spacingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (artikel.artikelnummer != null) ...[
                          Text(
                            '#${artikel.artikelnummer}',
                            style: textTheme.labelSmall?.copyWith(
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.primary,
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

// ══════════════════════════════════════════════════════════════════════════════
// ArtikelInfoChip
// ══════════════════════════════════════════════════════════════════════════════

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

enum _PanelMode { none, detail, erfassen, settings }
enum _MenuAction { importExport, pdfReports, resetDb, showLog, settings }