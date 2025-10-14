// lib/services/background_sync_manager.dart
// Plattformübergreifendes Background-Sync-Management für Mobile und Desktop

import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
// import 'package:workmanager/workmanager.dart'; // Nur für Mobile
// import 'artikel_db_service.dart';
// import 'nextcloud_client.dart';
// import 'sync_service.dart';

class BackgroundSyncManager {
  static const String syncTaskName = 'periodicSyncTask';
  static const int mobileIntervalMinutes = 15;
  static const int desktopIntervalMinutes = 15;
  Timer? _desktopTimer;

  // Initialisierung je nach Plattform
  Future<void> initialize() async {
    if (kIsWeb) return; // Kein Background auf Web
    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile background sync not implemented: workmanager dependency missing
      // await _initMobileBackgroundSync();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      _initDesktopBackgroundSync();
    }
  }

  // Mobile: Workmanager
  // Mobile background sync not implemented: workmanager dependency missing
  // Future<void> _initMobileBackgroundSync() async {
  //   await Workmanager().initialize(_backgroundTaskDispatcher, isInDebugMode: true);
  //   await Workmanager().registerPeriodicTask(
  //     syncTaskName,
  //     syncTaskName,
  //     frequency: Duration(minutes: mobileIntervalMinutes),
  //     constraints: Constraints(
  //       networkType: NetworkType.connected, // Optional: nur mit Netzwerk
  //     ),
  //   );
  // }

  // Desktop: Timer
  void _initDesktopBackgroundSync() {
    _desktopTimer?.cancel();
    _desktopTimer = Timer.periodic(Duration(minutes: desktopIntervalMinutes), (timer) async {
      // Background sync implementation
      // final dbService = ArtikelDbService();
      // final client = NextcloudClient(...);
      // final syncService = SyncService(client, dbService);
      // await syncService.syncOnce();
      debugPrint('[BackgroundSync] Desktop-Sync ausgeführt um ${DateTime.now()}');
    });
  }

  // Workmanager-Callback für Mobile
  // static Future<void> _backgroundTaskDispatcher() async {
  //   Workmanager().executeTask((task, inputData) async {
  //     // Background sync implementation for mobile
  //     // final dbService = ArtikelDbService();
  //     // final client = NextcloudClient(...);
  //     // final syncService = SyncService(client, dbService);
  //     // await syncService.syncOnce();
  //     print('[BackgroundSync] Mobile-Sync ausgeführt um {DateTime.now()}');
  //     return Future.value(true);
  //   });
  // }

  // Stoppt Desktop-Timer
  void dispose() {
    _desktopTimer?.cancel();
  }
}
