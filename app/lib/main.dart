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
import 'screens/server_setup_screen.dart';
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

  // ── Runtime-Konfiguration laden (Web) ─────────────────────────────────────
  await AppConfig.init();

  // ── App-Konfiguration validieren (wirft nicht mehr bei fehlender URL) ──────
  AppConfig.validateForRelease();
  AppConfig.validateConfig();

  // ── Unbehandelte Flutter-Framework-Fehler fangen ──────────────────────────
  FlutterError.onError = (details) {
    _log.e(
      'Flutter Framework Fehler',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // ── Unbehandelte Dart-Fehler fangen (async, isolates) ─────────────────────
  PlatformDispatcher.instance.onError = (error, stack) {
    _log.f(
      'Unbehandelter Dart-Fehler',
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  if (!kIsWeb) {
    platform.initDesktopDatabase();
  }

  // ── PocketBase initialisieren (crasht nie) ────────────────────────────────
  await PocketBaseService().initialize();

  // ── Health-Check nur wenn Client vorhanden ────────────────────────────────
  if (!kIsWeb && PocketBaseService().hasClient) {
    unawaited(
      PocketBaseService().checkHealth().then((ok) {
        if (ok) {
          _log.i('[Main] PocketBase erreichbar');
        } else {
          _log.w('[Main] PocketBase nicht erreichbar beim Start');
        }
      }).catchError((Object e, StackTrace st) {
        _log.e('[Main] PocketBase Health-Check Fehler',
            error: e, stackTrace: st,);
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

  /// Steuert ob die normale App oder der Setup-Screen angezeigt wird.
  bool _needsSetup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pbService = PocketBaseService();
    _needsSetup = _pbService.needsSetup;

    _db = ArtikelDbService();

    // Sync-Services nur initialisieren wenn ein Client vorhanden ist
    if (_pbService.hasClient) {
      _pocketSync = PocketBaseSyncService('artikel', _pbService, _db);
      _orchestrator = SyncOrchestrator(pocketBaseSync: _pocketSync);

      if (!kIsWeb) {
        _loadSyncSettings().then((_) {
          _runInitialSync();
          _startPeriodicSync();
        });
      }
    } else {
      // Dummy-Initialisierung damit late-Felder nicht crashen
      // wenn sie nie genutzt werden (Setup-Screen-Modus)
      _pocketSync = PocketBaseSyncService('artikel', _pbService, _db);
      _orchestrator = SyncOrchestrator(pocketBaseSync: _pocketSync);
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
    if (_syncRunning || !_pbService.hasClient) return;
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
    if (!_pbService.hasClient) return;
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(minutes: _syncIntervalMinutes),
      (_) => _syncIfConnected(),
    );
  }

  Future<void> _syncIfConnected() async {
    if (kIsWeb || !_pbService.hasClient) return;

    if (_syncRunning) {
      _log.d('[Sync] Übersprungen: Sync läuft bereits');
      return;
    }
    _syncRunning = true;

    try {
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

  /// Wird aufgerufen wenn der Setup-Screen erfolgreich eine URL
  /// konfiguriert hat. Initialisiert die Sync-Services und wechselt
  /// zur normalen App-Ansicht.
  void _onServerConfigured() {
    _log.i('[Main] Server konfiguriert, starte normale App...');

    // Sync-Services neu initialisieren mit dem jetzt verfügbaren Client
    if (_pbService.hasClient) {
      _pocketSync = PocketBaseSyncService('artikel', _pbService, _db);
      _orchestrator = SyncOrchestrator(pocketBaseSync: _pocketSync);

      if (!kIsWeb) {
        _loadSyncSettings().then((_) {
          _runInitialSync();
          _startPeriodicSync();
        });
      }

      // Health-Check im Hintergrund
      if (!kIsWeb) {
        unawaited(
          _pbService.checkHealth().then((ok) {
            if (ok) {
              _log.i('[Main] PocketBase erreichbar nach Setup');
            } else {
              _log.w('[Main] PocketBase nicht erreichbar nach Setup');
            }
          }).catchError((Object e, StackTrace st) {
            _log.e('[Main] Health-Check Fehler nach Setup',
                error: e, stackTrace: st,);
          }),
        );
      }
    }

    setState(() => _needsSetup = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _orchestrator.dispose();
    AppLogService.logger.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _cleanupDone = false;
        if (!kIsWeb && _pbService.hasClient) {
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
    // Setup-Screen anzeigen wenn keine URL konfiguriert ist
    if (_needsSetup) {
      return MaterialApp(
        title: 'Elektronik Verwaltung',
        theme: AppTheme.hell,
        darkTheme: AppTheme.dunkel,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: ServerSetupScreen(
          onConfigured: _onServerConfigured,
        ),
      );
    }

    // Normale App
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

  Widget _buildHomeWithBackground() {
    if (AppImages.hintergrundAktiv) {
      return Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              AppImages.hintergrundPfad,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                );
              },
            ),
          ),
          const ArtikelListScreen(),
        ],
      );
    }
    return const ArtikelListScreen();
  }
}