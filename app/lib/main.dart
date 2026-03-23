// lib/main.dart

import 'dart:async';
import 'dart:ui';

import 'services/connectivity_service.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'config/app_images.dart';
import 'screens/artikel_list_screen.dart';
import 'screens/settings_screen.dart';
import 'services/app_log_service.dart';
import 'services/artikel_db_service.dart';
import 'services/pocketbase_service.dart';
import 'services/pocketbase_sync_service.dart';
import 'services/sync_orchestrator.dart';

import 'main_io.dart' if (dart.library.html) 'main_stub.dart' as platform;

// Punkt 1 — Kurzreferenz auf den globalen Logger
final _log = AppLogService.logger;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Punkt 1 — Runtime-Konfiguration laden (Web) ───────────────────────────
  // Muss vor validateConfig() passieren, damit window.ENV_CONFIG berücksichtigt wird.
  await AppConfig.init();

  // ── Punkt 2 — App-Konfiguration validieren ───────────────────────────────
  // Wirft Error bei Release-Build mit Placeholder-URLs
  AppConfig.validateConfig();

  // ── Punkt 2 — Unbehandelte Flutter-Framework-Fehler fangen ──────────────
  FlutterError.onError = (details) {
    _log.e(
      'Flutter Framework Fehler',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // ── Punkt 2 — Unbehandelte Dart-Fehler fangen (async, isolates) ─────────
  PlatformDispatcher.instance.onError = (error, stack) {
    _log.f(
      'Unbehandelter Dart-Fehler',
      error: error,
      stackTrace: stack,
    );
    return true; // true = Fehler als behandelt markieren
  };

  if (!kIsWeb) {
    platform.initDesktopDatabase();
  }

  await PocketBaseService().initialize();

  if (!kIsWeb) {
    // Bewusst fire-and-forget — blockiert den App-Start nicht
    unawaited(
      PocketBaseService().checkHealth().then((ok) {
        if (ok) {
          _log.i('[Main] PocketBase erreichbar');
        } else {
          _log.w('[Main] PocketBase nicht erreichbar beim Start');
        }
      }).catchError((Object e, StackTrace st) {
        _log.e('[Main] PocketBase Health-Check Fehler', error: e, stackTrace: st);
      }),
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _wifiOnlySync = true;
  Timer? _syncTimer;

  static const int _syncIntervalMinutes = 15;

  late final ArtikelDbService _db;
  late final PocketBaseService _pbService;
  late final PocketBaseSyncService _pocketSync;
  late final SyncOrchestrator _orchestrator;

  bool _cleanupDone = false;
  bool _syncRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _db = ArtikelDbService();
    _pbService = PocketBaseService();
    _pocketSync = PocketBaseSyncService('artikel', _pbService, _db);
    _orchestrator = SyncOrchestrator(pocketBaseSync: _pocketSync);

    if (!kIsWeb) {
      _loadSyncSettings().then((_) {
        _runInitialSync();
        _startPeriodicSync();
      });
    }
  }

  Future<void> _loadSyncSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _wifiOnlySync = prefs.getBool('wifi_only_sync') ?? true;
      });
    }
  }

  Future<void> _runInitialSync() async {
    if (_syncRunning) return;
    _syncRunning = true;

    try {
      _log.i('[Sync] Initialer Sync startet...');
      await _orchestrator.runOnce();
      _log.i('[Sync] Initialer Sync abgeschlossen');
    } catch (e, st) {
      _log.e('[Sync] Initialer Sync fehlgeschlagen', error: e, stackTrace: st);
    } finally {
      _syncRunning = false;
    }
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(minutes: _syncIntervalMinutes),
      (_) => _syncIfConnected(),
    );
  }

  Future<void> _syncIfConnected() async {
    if (kIsWeb) return;

    if (_syncRunning) {
      _log.d('[Sync] Übersprungen: Sync läuft bereits');
      return;
    }
    _syncRunning = true;

    try {
      // Fix: ConnectivityService statt connectivity_plus direkt —
      // verhindert NetworkManager DBus-Fehler auf WSL2/Linux
      final isWifi = await ConnectivityService.isWifi();

      if (_wifiOnlySync && !isWifi) {
        _log.d('[Sync] Übersprungen: Nicht im WLAN');
        return;
      }

      _log.i('[Sync] Periodischer Sync startet um ${DateTime.now()}');
      await _orchestrator.runOnce();
      _log.i('[Sync] Periodischer Sync beendet um ${DateTime.now()}');
    } catch (e, st) {
      _log.e('[Sync] Fehler beim periodischen Sync', error: e, stackTrace: st);
    } finally {
      _syncRunning = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _orchestrator.dispose();

    // ── Punkt 5 — Logger sauber schließen ───────────────────────────────────
    AppLogService.logger.close();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _cleanupDone = false;
        if (!kIsWeb) {
          unawaited(_syncIfConnected());
        }
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_cleanupResources());
      default:
        break;
    }
  }

  Future<void> _cleanupResources() async {
    if (kIsWeb) return;
    if (_cleanupDone) return;
    _cleanupDone = true;

    try {
      await _db.closeDatabase();
    } catch (e, st) {
      _log.e('Cleanup Fehler', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elektronik Verwaltung',
      theme: AppTheme.hell,
      darkTheme: AppTheme.dunkel,
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => _buildHomeWithBackground(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }

  /// Baut die Home-Seite optional mit Hintergrundbild.
  Widget _buildHomeWithBackground() {
    // Wenn Hintergrundbild aktiv ist, zeige es als Background-Stack
    if (AppImages.hintergrundAktiv) {
      return Stack(
        children: [
          // Hintergrundbild
          Positioned.fill(
            child: Image.asset(
              AppImages.hintergrundPfad,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Fallback wenn Bild nicht gefunden wird
                // Respektiert aktuelles Theme (Light/Dark)
                return Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                );
              },
            ),
          ),
          // App-Inhalt
          const ArtikelListScreen(),
        ],
      );
    }
    
    // Ohne Hintergrundbild: Standard-Screen
    return const ArtikelListScreen();
  }
}