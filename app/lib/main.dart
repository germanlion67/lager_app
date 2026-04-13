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
import 'screens/login_screen.dart'; // ── M-009: Login-Screen
import 'screens/settings_screen.dart';
import 'screens/app_lock_screen.dart';  // ── F-001: Sperrbildschirm
import 'screens/server_setup_screen.dart';
import 'services/app_log_service.dart';
import 'services/artikel_db_service.dart';
import 'services/pocketbase_service.dart';
import 'services/app_lock_service.dart';  // ── F-001: App-Lock Service
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

  // ── F-001: App-Lock Service initialisieren ──────────────────────────────
  if (!kIsWeb) {
    await AppLockService().init();
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
  late PocketBaseSyncService _pocketSync;
  late SyncOrchestrator _orchestrator;

  bool _cleanupDone = false;
  bool _syncRunning = false;

  /// Steuert ob die normale App oder der Setup-Screen angezeigt wird.
  bool _needsSetup = false;

  /// ── M-009: Steuert ob der Login-Screen angezeigt wird.
  bool _isCheckingAuth = true;
  bool _isLoggedIn = false;
  bool _isAppLocked = false;  // ── F-001: App-Sperr-Status

  /// ── Dev-Mode: Login überspringen wenn PB_DEV_MODE=1
  /// Wird über --dart-define=PB_DEV_MODE=1 gesetzt.
  /// In Produktion ist der Default 0 (Login erforderlich).
  final bool _devMode = const String.fromEnvironment(
    'PB_DEV_MODE',
    defaultValue: '0',
  ) == '1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pbService = PocketBaseService();
    _needsSetup = _pbService.needsSetup;

    _db = ArtikelDbService();

    // Dev-Mode Hinweis im Log
    if (_devMode) {
      _log.w('[Main] ⚠️ DEV-MODE aktiv (PB_DEV_MODE=1) — Login wird übersprungen!');
    }

    // Sync-Services nur initialisieren wenn ein Client vorhanden ist
    if (_pbService.hasClient) {
      _pocketSync = PocketBaseSyncService('artikel', _pbService, _db);
      _orchestrator = SyncOrchestrator(pocketBaseSync: _pocketSync);

      // ── M-009: Auth-Status prüfen bevor Sync gestartet wird
      _checkAuthStatus().then((_) {
        if ((_isLoggedIn || _devMode) && !kIsWeb) {
          _loadSyncSettings().then((_) {
            _runInitialSync();
            _startPeriodicSync();
          });
        }
      });
    } else {
      // Dummy-Initialisierung damit late-Felder nicht crashen
      // wenn sie nie genutzt werden (Setup-Screen-Modus)
      _pocketSync = PocketBaseSyncService('artikel', _pbService, _db);
      _orchestrator = SyncOrchestrator(pocketBaseSync: _pocketSync);

      // ── M-009: Kein Client → Auth-Check überspringen
      _isCheckingAuth = false;
    }
  }

  // ── M-009: Auth-Status beim App-Start prüfen ─────────────────────────────

  /// Prüft beim App-Start ob ein gültiger Token vorhanden ist
  /// und versucht ihn zu erneuern (Auto-Login).
  ///
  /// Im Dev-Mode (PB_DEV_MODE=1) wird der Auth-Check übersprungen
  /// und der Login-Screen nicht angezeigt.
  Future<void> _checkAuthStatus() async {
    // Dev-Mode: Auth-Check komplett überspringen
    if (_devMode) {
      _log.w('[Auth] ⚠️ DEV-MODE: Login übersprungen (PB_DEV_MODE=1)');
      if (mounted) {
        setState(() {
          _isLoggedIn = false; // bleibt false, aber _devMode überspringt Login-Screen
          _isCheckingAuth = false;
        });
      }
      return;
    }

    if (!_pbService.hasClient) {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isCheckingAuth = false;
        });
      }
      return;
    }

    bool loggedIn = false;

    if (_pbService.isAuthenticated) {
      // Token vorhanden → versuche Refresh
      _log.i('[Auth] Gespeicherter Token gefunden, versuche Refresh...');
      loggedIn = await _pbService.refreshAuthToken();

      if (loggedIn) {
        _log.i('[Auth] Auto-Login erfolgreich: ${_pbService.currentUserEmail}');
      } else {
        _log.w('[Auth] Token abgelaufen, Login erforderlich.');
      }
    } else {
      _log.d('[Auth] Kein gespeicherter Token vorhanden.');
    }

    if (mounted) {
      setState(() {
        _isLoggedIn = loggedIn;
        _isCheckingAuth = false;
      });
    }
  }

  /// ── M-009: Wird vom LoginScreen aufgerufen nach erfolgreichem Login.
  void _onLoginSuccess() {
    _log.i('[Auth] Login erfolgreich, starte App...');

    setState(() => _isLoggedIn = true);

    // Sync starten nach Login (falls noch nicht gestartet)
    if (_pbService.hasClient && !kIsWeb) {
      _loadSyncSettings().then((_) {
        _runInitialSync();
        _startPeriodicSync();
      });
    }
  }

  /// ── M-009: Wird vom SettingsScreen aufgerufen bei Logout.
  void _onLogout() {
    _log.i('[Auth] Logout durchgeführt.');
    _pbService.logout();

    // Sync stoppen
    _syncTimer?.cancel();

    setState(() => _isLoggedIn = false);
  }

  // ── Bestehende Sync-Logik (unverändert) ───────────────────────────────────

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

  // ── Setup-Callback (unverändert) ──────────────────────────────────────────

  /// Wird aufgerufen wenn der Setup-Screen erfolgreich eine URL
  /// konfiguriert hat. Initialisiert die Sync-Services und wechselt
  /// zur normalen App-Ansicht NACHDEM der initiale Sync abgeschlossen ist.
  void _onServerConfigured() {
    _log.i('[Main] Server konfiguriert, starte initialen Sync...');

    // Sync-Services neu initialisieren mit dem jetzt verfügbaren Client
    if (_pbService.hasClient) {
      try {
        _orchestrator.dispose();
      } catch (e) {
        _log.d('[Main] Orchestrator dispose übersprungen: $e');
      }
      _pocketSync = PocketBaseSyncService('artikel', _pbService, _db);
      _orchestrator = SyncOrchestrator(pocketBaseSync: _pocketSync);

      // ── GEÄNDERT: Auth-Check + Sync ABWARTEN, dann erst UI wechseln ──
      _checkAuthStatus().then((_) {
        if ((_isLoggedIn || _devMode) && !kIsWeb) {
          _loadSyncSettings().then((_) async {
            // Initialen Sync durchführen und ABWARTEN
            _log.i('[Main] Starte initialen Sync nach Setup...');
            await _runInitialSync();
            _log.i('[Main] Initialer Sync abgeschlossen');

            // ERST JETZT zur normalen App wechseln
            if (mounted) {
              setState(() => _needsSetup = false);
            }

            _startPeriodicSync();
          });
        } else {
          // Kein Sync nötig (Web oder nicht eingeloggt) → sofort wechseln
          _log.i('[Main] Kein Sync nötig → direkt zur App');
          if (mounted) {
            setState(() => _needsSetup = false);
          }
        }
      });

      // Health-Check im Hintergrund (unverändert)
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
    } else {
      // Kein Client → trotzdem Setup beenden (Fehlerfall)
      _log.w('[Main] Kein PocketBase-Client nach Setup → Fehlerfall');
      if (mounted) {
        setState(() => _needsSetup = false);
      }
    }
  }

  // ── Lifecycle (unverändert) ───────────────────────────────────────────────

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

        // ── F-001: Prüfe ob App gesperrt werden muss ──────────────────────
        if (!kIsWeb && AppLockService().onAppResumed()) {
          setState(() => _isAppLocked = true);
        }

        if (!kIsWeb && _pbService.hasClient) {
          unawaited(_syncIfConnected());
        }
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // ── F-001: Pause-Zeitpunkt merken ─────────────────────────────────
        if (!kIsWeb) {
          AppLockService().onAppPaused();
        }
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

  // ── Build (M-009: Auth-Gate integriert + Dev-Mode) ────────────────────────

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elektronik Verwaltung',
      theme: AppTheme.hell,
      darkTheme: AppTheme.dunkel,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      // Eindeutiger Key erzwingt kompletten Navigator-Neuaufbau
      // beim Wechsel zwischen Setup, Login und Haupt-App
      key: ValueKey(
        _needsSetup
            ? 'setup'
            : (_isLoggedIn || _devMode)
                ? 'app'
                : 'login',
      ),
      home: _buildHome(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/settings':
            return MaterialPageRoute(
              builder: (_) => SettingsScreen(onLogout: _onLogout), // ── M-009
            );
          default:
            return MaterialPageRoute(
              builder: (_) => _buildHomeWithBackground(),
            );
        }
      },
    );
  }

  /// ── M-009: Entscheidet welcher Screen angezeigt wird.
  ///
  /// Priorität:
  /// 1. Setup-Screen (keine Server-URL konfiguriert)
  /// 2. Auth-Check Ladebildschirm (Token wird geprüft, nicht im Dev-Mode)
  /// 3. Login-Screen (nicht eingeloggt UND nicht im Dev-Mode)
  /// 4. Haupt-App (eingeloggt ODER Dev-Mode)
  Widget _buildHome() {
    // Priorität 1: Server-Setup benötigt
    if (_needsSetup) {
      return ServerSetupScreen(onConfigured: _onServerConfigured);
    }

    // Priorität 2: Auth-Status wird noch geprüft (Auto-Login)
    // Im Dev-Mode wird dieser Schritt übersprungen (_isCheckingAuth = false)
    if (_isCheckingAuth) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warehouse_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Authentifizierung wird geprüft…',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Priorität 3: Login erforderlich (im Dev-Mode übersprungen)
    if (!_isLoggedIn && !_devMode) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }

    // Priorität 4: Normale App (eingeloggt oder Dev-Mode)
    // ── F-001: Lock-Screen Overlay wenn App gesperrt ──────────────────────
    if (_isAppLocked) {
      return Stack(
        children: [
          _buildHomeWithBackground(),
          AppLockScreen(
            onUnlocked: () => setState(() => _isAppLocked = false),
          ),
        ],
      );
    }
    return _buildHomeWithBackground();
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
          ArtikelListScreen(syncStatusProvider: _orchestrator), // ← GEÄNDERT
        ],
      );
    }
    return ArtikelListScreen(syncStatusProvider: _orchestrator); // ← GEÄNDERT
  }
}