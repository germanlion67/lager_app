// lib/services/nextcloud_service_interface.dart
//
// Interface für NextcloudConnectionService.
// Ermöglicht Dependency Injection im Test ohne den Singleton zu umgehen.

import 'package:flutter/foundation.dart';

import 'nextcloud_connection_service.dart';

abstract class NextcloudServiceInterface {
  ValueNotifier<NextcloudConnectionStatus> get connectionStatus;

  Future<void> startPeriodicCheck();
  void stopPeriodicCheck();
  Future<void> checkConnectionNow();
  Future<void> restartMonitoring();
  void dispose();
}