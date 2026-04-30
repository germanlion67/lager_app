// lib/main.dart
//
// CHANGES v0.8.5+3:
//   FIX — _registerConflictCallback(): Guard verhindert mehrfache
//          Registrierung des Konflikt-Callbacks (war: 3x bei
//          initState + Login + Server-Setup).
//   F2  — _onConflictDetected(): ConflictData bauen + ConflictResolutionScreen
//          mit korrekter Signatur (conflicts + syncService) aufrufen.
//   F2  — PocketBaseConflictAdapter: minimaler SyncService-Wrapper der
//          applyConflictResolution() auf _db weiterleitet.
//          Alle anderen SyncService-Methoden werfen UnimplementedError —
//          sie werden vom ConflictResolutionScreen nicht aufgerufen.
//   FIX — openDatabase() / markAsModified() korrekt aufgerufen.
//   FIX — Trailing-Comma-Lints (Zeilen 79, 455, 499).
//   FIX — Doc-Comment HTML-Lint: <NavigatorState> → `NavigatorState`.
//   FIX — Explizite Typen im onResolved-Callback.

import 'dart:async';
import 'dart:ui';

import 'services/connectivity_service.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'config/app_images.dart';
import 'models/artikel_model.dart';
import 'screens/artikel_list_screen.dart';
import 'screens/conflict_resolution_screen.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/app_lock_screen.dart';
import 'screens/server_setup_screen.dart';
import 'services/app_log_service.dart';
import 'services/artikel_db_service.dart';
import 'services/pocketbase_service.dart';
import 'services/app_lock_service.dart';
import 'services/pocketbase_sync_service.dart';
import 'services/sync_orchestrator.dart';
import 'services/sync_service.dart';
import 'services/conflict_resolution_utils.dart';
import 'services/sync_progress_service.dart';
import 'services/sync_error_recovery.dart';

import 'main_io.dart' if (dart.library.html) 'main_stub.dart' as platform;

final _log = AppLogService.logger;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppConfig.init();
  AppConfig.validateForRelease();
  AppConfig.validateConfig();

  FlutterError.onError = (details) {
    _log.e(
      'Flutter Framework Fehler',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

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

  await PocketBaseService().initialize();

  if (!kIsWeb && PocketBaseService().hasClient) {
    unawaited(
      PocketBaseService().checkHealth().then((ok) {
        if (ok) {
          _log.i('[Main] PocketBase erreichbar');
        } else {
          _log.w('[Main] PocketBase nicht erreichbar beim Start');
        }
      }).catchError((Object e, StackTrace st) {
        _log.e(
          '[Main] PocketBase Health-Check Fehler',
          error: e,
          stackTrace: st,
        );
      }),
    );
  }

  if (!kIsWeb) {
    await AppLockService().init();
  }

  runApp(const MyApp());
}

// ── PocketBaseConflictAdapter ─────────────────────────────────────────────────
//
// Minimaler Adapter der SyncService für den ConflictResolutionScreen
// implementiert — ohne Nextcloud-Abhängigkeit.
//
// ConflictResolutionScreen ruft ausschließlich applyConflictResolution() auf.
// Alle anderen Methoden werden nie aufgerufen und werfen UnimplementedError
// als Sicherheitsnetz.
//
// Begründung für eigene Klasse statt SyncService-Subclass:
// SyncService hat required-Parameter (NextcloudClient, ArtikelDbService)
// die wir nicht haben wollen. Der Adapter ist leichtgewichtiger.
class _PocketBaseConflictAdapter implements SyncService {
  final ArtikelDbService _db;

  _PocketBaseConflictAdapter(this._db);

  @override
  final logger = _log;

  @override
  final SyncProgressService progressService = SyncProgressService();

  @override
  final SyncErrorRecoveryService errorRecoveryService =
      SyncErrorRecoveryService();

  @override
  Future<void> applyConflictResolution(
    ConflictData conflict,
    ConflictResolution resolution, {
    Artikel? mergedVersion,
  }) async {
    switch (resolution) {
      case ConflictResolution.useLocal:
        // Bewusste Nutzerentscheidung:
        // lokale Version beim nächsten Sync gezielt nach Remote pushen.
        await _db.markForForceLocal(conflict.localVersion.uuid);
        _log.i(
          '[Conflict] Lokale Version behalten: ${conflict.localVersion.uuid}',
        );
        return;

      case ConflictResolution.useRemote:
        // Remote-Version lokal übernehmen und als synchronisierten Stand speichern.
        // Als neue Baseline sind nur belastbare Remote-Versionsstände erlaubt.
        final remoteEtag = requireRemoteBaselineEtag(conflict.remoteVersion);

        await _db.upsertArtikel(
          conflict.remoteVersion,
          etag: remoteEtag,
        );
        await _db.clearPendingResolution(conflict.remoteVersion.uuid);
        _log.i(
          '[Conflict] Remote-Version übernommen: ${conflict.remoteVersion.uuid}',
        );
        return;

      case ConflictResolution.merge:
        if (mergedVersion != null) {
          // Gemergte Version lokal speichern und bewusst für Force-Push markieren.
          await _db.updateArtikel(mergedVersion);
          await _db.markForForceMerge(mergedVersion.uuid);
          _log.i(
            '[Conflict] Zusammengeführte Version gespeichert: '
            '${mergedVersion.uuid}',
          );
        } else {
          _log.w(
            '[Conflict] Merge gewählt, aber mergedVersion ist null: '
            '${conflict.localVersion.uuid}',
          );
        }
        return;

      case ConflictResolution.skip:
        // Absichtlich nichts ändern:
        // Konflikt bleibt offen und wird beim nächsten Sync erneut erkannt.
        _log.i(
          '[Conflict] Übersprungen: ${conflict.localVersion.uuid}',
        );
        return;
    }
  }

  @override
  Future<List<ConflictData>> detectConflicts() async {
    throw UnimplementedError(
      '_PocketBaseConflictAdapter.detectConflicts ist nicht implementiert. '
      'Der ConflictResolutionScreen benötigt nur applyConflictResolution().',
    );
  }

  @override
  Future<String> getDeviceId() async {
    throw UnimplementedError(
      '_PocketBaseConflictAdapter.getDeviceId ist nicht implementiert. '
      'Der ConflictResolutionScreen benötigt nur applyConflictResolution().',
    );
  }

  @override
  Future<void> syncAttachments() async {
    throw UnimplementedError(
      '_PocketBaseConflictAdapter.syncAttachments ist nicht implementiert. '
      'Der ConflictResolutionScreen benötigt nur applyConflictResolution().',
    );
  }

  @override
  Future<SyncResult> syncOnce() async {
    throw UnimplementedError(
      '_PocketBaseConflictAdapter.syncOnce ist nicht implementiert. '
      'Der ConflictResolutionScreen benötigt nur applyConflictResolution().',
    );
  }

  @override
  Future<Map<String, dynamic>> syncWithConflictResolution() async {
    throw UnimplementedError(
      '_PocketBaseConflictAdapter.syncWithConflictResolution ist nicht '
      'implementiert. Der ConflictResolutionScreen benötigt nur '
      'applyConflictResolution().',
    );
  }

  @override
  Future<bool> testAndInitialize() async {
    throw UnimplementedError(
      '_PocketBaseConflictAdapter.testAndInitialize ist nicht implementiert. '
      'Der ConflictResolutionScreen benötigt nur applyConflictResolution().',
    );
  }
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

  // F2: GlobalKey für Navigator-Zugriff aus Callbacks ohne BuildContext.
  // Typ-Annotation explizit — kein HTML-Lint-Problem da kein Doc-Comment.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late final ArtikelDbService _db;
  late final PocketBaseService _pbService;
  late PocketBaseSyncService _pocketSync;
  late SyncOrchestrator _orchestrator;

  bool _cleanupDone = false;
  bool _syncRunning = false;
  bool _isConflictScreenOpen = false;
  final Set<String> _activeConflictUuids = {}; // NEU: UUID-basierter Guard
  bool _conflictCallbackRegistered = false; // NEU: Guard gegen Mehrfach-Registrierung

  bool _needsSetup = false;
  bool _isCheckingAuth = true;
  bool _isLoggedIn = false;
  bool _isAppLocked = false;

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

    if (_devMode) {
      _log.w(
        '[Main] ⚠️ DEV-MODE aktiv (PB_DEV_MODE=1) — Login wird übersprungen!',
      );
    }

    if (_pbService.hasClient) {
      _pocketSync = PocketBaseSyncService('artikel', _pbService, _db);
      _orchestrator = SyncOrchestrator(pocketBaseSync: _pocketSync);

      // F2: Konflikt-Callback nach erstem Frame registrieren.
      // Navigator ist erst nach dem ersten Build verfügbar.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _registerConflictCallback();
      });

      _checkAuthStatus().then((_) {
        if ((_isLoggedIn || _devMode) && !kIsWeb) {
          _loadSyncSettings().then((_) {
            _runInitialSync();
            _startPeriodicSync();
          });
        }
      });
    } else {
      _pocketSync = PocketBaseSyncService('artikel', _pbService, _db);
      _orchestrator = SyncOrchestrator(pocketBaseSync: _pocketSync);
      _isCheckingAuth = false;
    }
  }

  // ── F2: Konflikt-Callback ─────────────────────────────────────────────────

  void _registerConflictCallback() {
    if (_conflictCallbackRegistered) {
      _log.d('[Main] Konflikt-Callback bereits registriert — überspringe');
      return;
    }
    _orchestrator.setConflictCallback(_onConflictDetected);
    _conflictCallbackRegistered = true;
    _log.d('[Main] Konflikt-Callback am Orchestrator registriert');
  }

  /// Wird aufgerufen wenn PocketBaseSyncService einen Konflikt erkennt.
  ///
  /// Baut ein `ConflictData`-Objekt und öffnet `ConflictResolutionScreen`
  /// via `GlobalKey<NavigatorState>` — kein BuildContext nötig.
  Future<void> _onConflictDetected(
    Artikel lokalerArtikel,
    Artikel remoteArtikel,
  ) async {
    // ── Guard 1: UUID bereits in Bearbeitung ──────────────────────────────
    // Verhindert Doppel-Trigger durch Push UND Pull für dieselbe UUID.
    if (_activeConflictUuids.contains(lokalerArtikel.uuid)) {
      _log.d(
        '[Main] Konflikt für ${lokalerArtikel.uuid} bereits aktiv — '
        'überspringe (UUID-Guard)',
      );
      return;
    }

    // ── Guard 2: Screen bereits offen ─────────────────────────────────────
    // Verhindert gleichzeitige Konflikt-Screens für verschiedene UUIDs.
    if (_isConflictScreenOpen) {
      _log.w(
        '[Main] Konflikt-UI bereits offen — '
        'weiterer Konflikt bleibt pending: ${lokalerArtikel.uuid}',
      );
      return;
    }

    // ── Ab hier: Konflikt wird verarbeitet ───────────────────────────────
    _log.i(
      '[Main] Konflikt-UI für ${lokalerArtikel.name} '
      '(uuid: ${lokalerArtikel.uuid})',
    );

    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      _log.w(
        '[Main] Konflikt erkannt aber Navigator nicht verfügbar — '
        'überspringe UI für ${lokalerArtikel.uuid}',
      );
      return;
    }

    // UUID als aktiv markieren — ab jetzt wird kein zweiter Trigger
    // für dieselbe UUID durchgelassen (Push + Pull + nächster Sync).
    _activeConflictUuids.add(lokalerArtikel.uuid);
    _isConflictScreenOpen = true;

    final conflictData = ConflictData(
      localVersion: lokalerArtikel,
      remoteVersion: remoteArtikel,
      conflictReason: _buildConflictReason(lokalerArtikel, remoteArtikel),
      detectedAt: DateTime.now(),
    );

    try {
      await navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => ConflictResolutionScreen(
            conflicts: [conflictData],
            syncService: _PocketBaseConflictAdapter(_db),
          ),
          fullscreenDialog: true,
        ),
      );
    } catch (e, st) {
      _log.e(
        '[Main] Konflikt-UI fehlgeschlagen für ${lokalerArtikel.uuid}',
        error: e,
        stackTrace: st,
      );
    } finally {
      // UUID erst nach Auflösung freigeben —
      // erst dann darf ein neuer Konflikt für dieselbe UUID erkannt werden.
      _activeConflictUuids.remove(lokalerArtikel.uuid);
      _isConflictScreenOpen = false;
      _log.d(
        '[Main] Konflikt-UI geschlossen für ${lokalerArtikel.uuid}',
      );
    }
  }

  /// Bestimmt den Konflikt-Grund für die UI-Anzeige.
  String _buildConflictReason(Artikel lokal, Artikel remote) {
    final diffMs = (lokal.updatedAt - remote.updatedAt).abs();
    if (diffMs < 60000) {
      return 'Gleichzeitige Bearbeitung auf zwei Geräten';
    }
    if (lokal.updatedAt > remote.updatedAt) {
      return 'Lokale Version neuer als Remote-Version';
    }
    return 'Remote-Version neuer als lokale Version';
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<void> _checkAuthStatus() async {
    if (_devMode) {
      _log.w('[Auth] ⚠️ DEV-MODE: Login übersprungen (PB_DEV_MODE=1)');
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
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
      _log.i('[Auth] Gespeicherter Token gefunden, versuche Refresh...');
      loggedIn = await _pbService.refreshAuthToken();
      if (loggedIn) {
        _log.i(
          '[Auth] Auto-Login erfolgreich: ${_pbService.currentUserEmail}',
        );
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

  void _onLoginSuccess() {
    _log.i('[Auth] Login erfolgreich, starte App...');
    setState(() => _isLoggedIn = true);

    // Konflikt-Callback nach Login (erneut) registrieren
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerConflictCallback();
    });

    if (_pbService.hasClient && !kIsWeb) {
      _loadSyncSettings().then((_) {
        _runInitialSync();
        _startPeriodicSync();
      });
    }
  }

  void _onLogout() {
    _log.i('[Auth] Logout durchgeführt.');
    _pbService.logout();
    _syncTimer?.cancel();
    setState(() => _isLoggedIn = false);
  }

  // ── Sync ──────────────────────────────────────────────────────────────────

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

  // ── Setup ─────────────────────────────────────────────────────────────────

  void _onServerConfigured() {
    _log.i('[Main] Server konfiguriert, starte initialen Sync...');

    if (_pbService.hasClient) {
      try {
        _orchestrator.dispose();
      } catch (e) {
        _log.d('[Main] Orchestrator dispose übersprungen: $e');
      }
      _pocketSync = PocketBaseSyncService('artikel', _pbService, _db);
      _orchestrator = SyncOrchestrator(pocketBaseSync: _pocketSync);
      _conflictCallbackRegistered = false; // NEU: Reset nach Neuinitialisierung

      // Konflikt-Callback nach Neuinitialisierung wieder registrieren
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _registerConflictCallback();
      });

      _checkAuthStatus().then((_) {
        if ((_isLoggedIn || _devMode) && !kIsWeb) {
          _loadSyncSettings().then((_) async {
            _log.i('[Main] Starte initialen Sync nach Setup...');
            await _runInitialSync();
            _log.i('[Main] Initialer Sync abgeschlossen');

            if (mounted) {
              setState(() => _needsSetup = false);
            }

            _startPeriodicSync();
          });
        } else {
          _log.i('[Main] Kein Sync nötig → direkt zur App');
          if (mounted) {
            setState(() => _needsSetup = false);
          }
        }
      });

      if (!kIsWeb) {
        unawaited(
          _pbService.checkHealth().then((ok) {
            if (ok) {
              _log.i('[Main] PocketBase erreichbar nach Setup');
            } else {
              _log.w('[Main] PocketBase nicht erreichbar nach Setup');
            }
          }).catchError((Object e, StackTrace st) {
            _log.e(
              '[Main] Health-Check Fehler nach Setup',
              error: e,
              stackTrace: st,
            );
          }),
        );
      }
    } else {
      _log.w('[Main] Kein PocketBase-Client nach Setup → Fehlerfall');
      if (mounted) {
        setState(() => _needsSetup = false);
      }
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

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

        if (!kIsWeb && AppLockService().onAppResumed()) {
          setState(() => _isAppLocked = true);
        }

        if (!kIsWeb && _pbService.hasClient) {
          // F2: DB vor Sync wiederherstellen.
          // closeDatabase() setzt _db = null bei paused.
          // openDatabase() ist idempotent — No-op wenn DB bereits offen.
          unawaited(
            _db.openDatabase().then((_) {
              _log.d('[Main] DB nach Resume geöffnet');
              return _syncIfConnected();
            }).catchError((Object e, StackTrace st) {
              _log.e(
                '[Main] DB-Reopen nach Resume fehlgeschlagen',
                error: e,
                stackTrace: st,
              );
            }),
          );
        }

      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elektronik Verwaltung',
      theme: AppTheme.hell,
      darkTheme: AppTheme.dunkel,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      // F2: NavigatorKey für Konflikt-UI ohne BuildContext
      navigatorKey: _navigatorKey,
      home: _buildHome(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/settings':
            return MaterialPageRoute(
              builder: (_) => SettingsScreen(onLogout: _onLogout),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => _buildHomeWithBackground(),
            );
        }
      },
    );
  }

  Widget _buildHome() {
    _log.d('[Main] Baue Home-Widget. Eingeloggt: $_isLoggedIn'); // Diese Zeile einfügen    
    if (_needsSetup) {
      return ServerSetupScreen(onConfigured: _onServerConfigured);
    }

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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isLoggedIn && !_devMode) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }

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
          ArtikelListScreen(syncStatusProvider: _orchestrator),
        ],
      );
    }
    return ArtikelListScreen(syncStatusProvider: _orchestrator);
  }
}