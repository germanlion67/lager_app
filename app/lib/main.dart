// lib/main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:connectivity_plus/connectivity_plus.dart';

import 'screens/artikel_list_screen.dart';
import 'screens/settings_screen.dart';
import 'services/pocketbase_service.dart';
import 'services/artikel_db_service.dart';
import 'services/pocketbase_sync_service.dart';
import 'services/sync_orchestrator.dart';

// Conditional import für dart:io (Platform-Check)
import 'main_io.dart' if (dart.library.html) 'main_stub.dart' as platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop: SQLite FFI initialisieren (nur Mobile/Desktop)
  if (!kIsWeb) {
    platform.initDesktopDatabase();
  }

  // PocketBase Service initialisieren (URL aus SharedPreferences laden)
  await PocketBaseService().initialize();

  // App sofort starten – Sync im Hintergrund!
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // Sync-Konfiguration
  final bool _wifiOnlySync = true;
  Timer? _syncTimer;
  final int _syncIntervalMinutes = 15;

  // Sync-Instanzen (einmal erstellen, wiederverwenden)
  late final PocketBaseSyncService _pocketSync;
  late final SyncOrchestrator _orchestrator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pocketSync = PocketBaseSyncService('artikel');
    _orchestrator = SyncOrchestrator(pocketBaseSync: _pocketSync);

    // Sync nur auf Mobile/Desktop – Web braucht keinen Sync
    if (!kIsWeb) {
      _runInitialSync();
      _startPeriodicSync();
    }
  }

  /// Initialer Sync nach App-Start (non-blocking)
  Future<void> _runInitialSync() async {
    try {
      debugPrint('[Sync] Initialer Sync startet...');
      await _orchestrator.runOnce();
      debugPrint('[Sync] Initialer Sync abgeschlossen');
    } catch (e) {
      debugPrint('[Sync] Initialer Sync fehlgeschlagen: $e');
    }
  }

  /// Periodischer Sync alle X Minuten
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(minutes: _syncIntervalMinutes),
      (_) => _syncIfConnected(),
    );
  }

  /// Sync nur wenn Netzwerk verfügbar (Mobile/Desktop only)
  Future<void> _syncIfConnected() async {
    if (kIsWeb) return; // ✅ Expliziter Guard – Web braucht keinen lokalen Sync

    try {
      final results = await Connectivity().checkConnectivity();
      final isWifi = results.contains(ConnectivityResult.wifi);

      if (_wifiOnlySync && !isWifi) {
        debugPrint('[Sync] Übersprungen: Nicht im WLAN');
        return;
      }

      debugPrint('[Sync] Periodischer Sync startet um ${DateTime.now()}');
      await _orchestrator.runOnce();
      debugPrint('[Sync] Periodischer Sync beendet um ${DateTime.now()}');
    } catch (e) {
      debugPrint('[Sync] Fehler beim periodischen Sync: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App kommt in den Vordergrund → Sync anstoßen
        if (!kIsWeb) {
          unawaited(_syncIfConnected()); // ✅ unawaited macht Absicht explizit
        }
        break;
      case AppLifecycleState.detached:
        // App wird beendet → DB schließen
        unawaited(_cleanupResources()); // ✅ unawaited macht Absicht explizit
        break;
      default:
        break;
    }
  }

  Future<void> _cleanupResources() async {
    if (kIsWeb) return; // Web hat keine lokale DB
    try {
      await ArtikelDbService().closeDatabase();
    } catch (e) {
      debugPrint('Cleanup error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elektronik Verwaltung',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.black),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black),
          bodySmall: TextStyle(color: Colors.black),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const ArtikelListScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}