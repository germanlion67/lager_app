// lib/main.dart

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/artikel_list_screen.dart';
import 'screens/settings_screen.dart';
import 'services/artikel_db_service.dart';
import 'services/pocketbase_service.dart';
import 'services/pocketbase_sync_service.dart';
import 'services/sync_orchestrator.dart';

import 'main_io.dart' if (dart.library.html) 'main_stub.dart' as platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    platform.initDesktopDatabase();
  }

  await PocketBaseService().initialize();

  if (!kIsWeb) {
    // Bewusst fire-and-forget — blockiert den App-Start nicht
    unawaited(
      PocketBaseService().checkHealth().then((ok) {
        debugPrint(
          ok
              ? '[Main] ✅ PocketBase erreichbar'
              : '[Main] ⚠️ PocketBase nicht erreichbar beim Start',
        );
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

  // FIX: static const statt final int — Wert ist kompilierzeitkonstant
  static const int _syncIntervalMinutes = 15;

  late final ArtikelDbService _db;
  late final PocketBaseService _pbService;
  late final PocketBaseSyncService _pocketSync;
  late final SyncOrchestrator _orchestrator;

  // FIX: Guard gegen doppeltes Cleanup (paused + detached)
  bool _cleanupDone = false;

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
    try {
      debugPrint('[Sync] Initialer Sync startet...');
      await _orchestrator.runOnce();
      debugPrint('[Sync] Initialer Sync abgeschlossen');
    } catch (e, st) {
      // FIX: Stack-Trace mitloggen
      debugPrint('[Sync] Initialer Sync fehlgeschlagen: $e\n$st');
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
    } catch (e, st) {
      // FIX: Stack-Trace mitloggen
      debugPrint('[Sync] Fehler beim periodischen Sync: $e\n$st');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _orchestrator.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!kIsWeb) {
          unawaited(_syncIfConnected());
        }
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // FIX: paused + detached zusammengefasst — kein doppeltes Cleanup
        unawaited(_cleanupResources());
      default:
        break;
    }
  }

  Future<void> _cleanupResources() async {
    if (kIsWeb) return;

    // FIX: Guard gegen doppeltes Schließen der DB
    if (_cleanupDone) return;
    _cleanupDone = true;

    try {
      await _db.closeDatabase();
    } catch (e, st) {
      // FIX: Stack-Trace mitloggen
      debugPrint('Cleanup error: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elektronik Verwaltung',
      // FIX: colorScheme statt deprecated primarySwatch
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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