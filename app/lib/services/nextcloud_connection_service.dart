// lib/services/nextcloud_connection_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import '../screens/nextcloud_settings_screen.dart';
import 'nextcloud_credentials.dart';

enum NextcloudConnectionStatus { online, offline, unknown }

class NextcloudConnectionService {
  static final NextcloudConnectionService _instance =
      NextcloudConnectionService._internal();
  factory NextcloudConnectionService() => _instance;
  NextcloudConnectionService._internal();

  final Logger _logger = Logger();
  final ValueNotifier<NextcloudConnectionStatus> _connectionStatus =
      ValueNotifier<NextcloudConnectionStatus>(
    NextcloudConnectionStatus.unknown,
  );

  Timer? _timer;
  NextcloudCredentials? _currentCredentials;

  ValueNotifier<NextcloudConnectionStatus> get connectionStatus =>
      _connectionStatus;

  /// Startet die periodische Verbindungsprüfung.
  Future<void> startPeriodicCheck() async {
    _logger.i('Starting Nextcloud connection monitoring');

    _currentCredentials = await NextcloudCredentialsStore().read();
    if (_currentCredentials == null) {
      _logger.w('No Nextcloud credentials found, cannot start monitoring');
      _connectionStatus.value = NextcloudConnectionStatus.unknown;
      return;
    }

    _timer?.cancel();
    await _checkConnection();

    final intervalMinutes = _currentCredentials!.checkIntervalMinutes;
    _timer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) async {
        try {
          await _checkConnection();
        } catch (e, st) {
          _logger.e(
            'Error during periodic connection check',
            error: e,
            stackTrace: st,
          );
        }
      },
    );

    _logger.i(
      'Nextcloud connection monitoring started '
      'with ${intervalMinutes}min interval',
    );
  }

  /// Stoppt die periodische Verbindungsprüfung.
  void stopPeriodicCheck() {
    _logger.i('Stopping Nextcloud connection monitoring');
    _timer?.cancel();
    _timer = null;
    _connectionStatus.value = NextcloudConnectionStatus.unknown;
  }

  /// Löst manuell eine Verbindungsprüfung aus.
  Future<void> checkConnectionNow() async {
    await _checkConnection();
  }

  /// Startet das Monitoring neu (z. B. nach Einstellungsänderung).
  Future<void> restartMonitoring() async {
    stopPeriodicCheck();
    await startPeriodicCheck();
  }

  /// Interne Verbindungsprüfung via HTTP HEAD.
  Future<void> _checkConnection() async {
    if (_currentCredentials == null) {
      _currentCredentials = await NextcloudCredentialsStore().read();
      if (_currentCredentials == null) {
        _connectionStatus.value = NextcloudConnectionStatus.unknown;
        return;
      }
    }

    // Lokale Kopie — vermeidet wiederholtes Force-Unwrap
    final creds = _currentCredentials!;

    try {
      final uri = creds.server.replace(
        path: 'remote.php/dav/files/${Uri.encodeComponent(creds.user)}/',
      );

      final basicAuth = base64Encode(
        utf8.encode('${creds.user}:${creds.appPw}'),
      );

      final response = await http.head(
        uri,
        headers: {'Authorization': 'Basic $basicAuth'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 207) {
        if (_connectionStatus.value != NextcloudConnectionStatus.online) {
          _logger.i('Nextcloud connection: Online');
          _connectionStatus.value = NextcloudConnectionStatus.online;
        }
      } else {
        if (_connectionStatus.value != NextcloudConnectionStatus.offline) {
          _logger.w(
            'Nextcloud connection: Offline '
            '(Status: ${response.statusCode})',
          );
          _connectionStatus.value = NextcloudConnectionStatus.offline;
        }
      }
    } on TimeoutException catch (e) {
      if (_connectionStatus.value != NextcloudConnectionStatus.offline) {
        _logger.w('Nextcloud connection: Offline (Timeout: $e)');
        _connectionStatus.value = NextcloudConnectionStatus.offline;
      }
    } catch (e, st) {
      if (_connectionStatus.value != NextcloudConnectionStatus.offline) {
        _logger.w(
          'Nextcloud connection: Offline (Error: $e)',
          stackTrace: st,
        );
        _connectionStatus.value = NextcloudConnectionStatus.offline;
      }
    }
  }

  /// Singleton-sicheres dispose — nur aufrufen wenn App vollständig beendet.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    // Hinweis: _connectionStatus.dispose() bei Singleton weglassen —
    // ValueNotifier kann nach dispose() nicht mehr genutzt werden.
  }

  /// Öffnet den Einstellungsscreen.
  /// FIX 1: connectionService wird an Screen übergeben — required Parameter
  /// FIX 2: restartMonitoring() hier entfernt — Screen ruft es selbst auf
  ///         in _speichern(), doppelter Aufruf vermieden
  static Future<void> showSettingsScreen(
    BuildContext context,
    NextcloudConnectionService connectionService,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NextcloudSettingsScreen(
          connectionService: connectionService, // FIX 1
        ),
      ),
    );
    // FIX 2: kein restartMonitoring() hier — wird bereits in _speichern()
    // des Screens aufgerufen. Doppelter Aufruf würde Timer zweimal neu
    // starten und unnötige HTTP-Requests auslösen.
  }
}