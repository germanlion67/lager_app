// test/helpers/no_op_nextcloud_service.dart
//
// Test-Double für NextcloudServiceInterface.
// Startet KEINE Timer, macht KEINE HTTP-Requests.
// Stellt einen funktionierenden connectionStatus ValueNotifier bereit.

import 'package:flutter/foundation.dart';

import 'package:lager_app/services/nextcloud_connection_service.dart';
import 'package:lager_app/services/nextcloud_service_interface.dart';

class NoOpNextcloudService implements NextcloudServiceInterface {
  final ValueNotifier<NextcloudConnectionStatus> _connectionStatus =
      ValueNotifier<NextcloudConnectionStatus>(
    NextcloudConnectionStatus.unknown,
  );

  @override
  ValueNotifier<NextcloudConnectionStatus> get connectionStatus =>
      _connectionStatus;

  @override
  Future<void> startPeriodicCheck() async {
    // No-Op: Im Test soll kein Timer laufen
  }

  @override
  void stopPeriodicCheck() {
    // No-Op: Es gibt nichts zu stoppen
  }

  @override
  Future<void> checkConnectionNow() async {
    // No-Op: Kein HTTP-Request im Test
  }

  @override
  Future<void> restartMonitoring() async {
    // No-Op: Nichts neu zu starten
  }

  @override
  void dispose() {
    _connectionStatus.dispose();
  }
}