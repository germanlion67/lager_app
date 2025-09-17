//lib/services/nextcloud_connection_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'nextcloud_credentials.dart';

enum NextcloudConnectionStatus { online, offline, unknown }

class NextcloudConnectionService {
  static final NextcloudConnectionService _instance = NextcloudConnectionService._internal();
  factory NextcloudConnectionService() => _instance;
  NextcloudConnectionService._internal();

  final Logger _logger = Logger();
  final ValueNotifier<NextcloudConnectionStatus> _connectionStatus = 
      ValueNotifier<NextcloudConnectionStatus>(NextcloudConnectionStatus.unknown);
  
  Timer? _timer;
  NextcloudCredentials? _currentCredentials;

  ValueNotifier<NextcloudConnectionStatus> get connectionStatus => _connectionStatus;

  /// Starts the periodic connection check with the given credentials
  Future<void> startPeriodicCheck() async {
    _logger.i('Starting Nextcloud connection monitoring');
    
    // Load credentials
    _currentCredentials = await NextcloudCredentialsStore().read();
    if (_currentCredentials == null) {
      _logger.w('No Nextcloud credentials found, cannot start monitoring');
      _connectionStatus.value = NextcloudConnectionStatus.unknown;
      return;
    }

    // Cancel existing timer
    _timer?.cancel();

    // Perform initial check
    await _checkConnection();

    // Setup periodic timer
    final intervalMinutes = _currentCredentials!.checkIntervalMinutes;
    _timer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) async {
        try {
          await _checkConnection();
        } catch (e) {
          _logger.e('Error during periodic connection check', error: e);
        }
      },
    );
    
    _logger.i('Nextcloud connection monitoring started with ${intervalMinutes}min interval');
  }

  /// Stops the periodic connection check
  void stopPeriodicCheck() {
    _logger.i('Stopping Nextcloud connection monitoring');
    _timer?.cancel();
    _timer = null;
    _connectionStatus.value = NextcloudConnectionStatus.unknown;
  }

  /// Manually trigger a connection check
  Future<void> checkConnectionNow() async {
    await _checkConnection();
  }

  /// Restarts the monitoring (useful when settings change)
  Future<void> restartMonitoring() async {
    stopPeriodicCheck();
    await startPeriodicCheck();
  }

  /// Internal method to perform the actual connection check
  Future<void> _checkConnection() async {
    if (_currentCredentials == null) {
      _currentCredentials = await NextcloudCredentialsStore().read();
      if (_currentCredentials == null) {
        _connectionStatus.value = NextcloudConnectionStatus.unknown;
        return;
      }
    }

    try {
      final uri = _currentCredentials!.server.replace(
        path: 'remote.php/dav/files/${Uri.encodeComponent(_currentCredentials!.user)}/',
      );
      
      final basicAuth = base64Encode(
        utf8.encode('${_currentCredentials!.user}:${_currentCredentials!.appPw}'),
      );

      final response = await http.head(
        uri,
        headers: {'Authorization': 'Basic $basicAuth'},
      ).timeout(const Duration(seconds: 30)); // Increased timeout for reliability

      if (response.statusCode == 200 || response.statusCode == 207) {
        if (_connectionStatus.value != NextcloudConnectionStatus.online) {
          _logger.i('Nextcloud connection: Online');
          _connectionStatus.value = NextcloudConnectionStatus.online;
        }
      } else {
        if (_connectionStatus.value != NextcloudConnectionStatus.offline) {
          _logger.w('Nextcloud connection: Offline (Status: ${response.statusCode})');
          _connectionStatus.value = NextcloudConnectionStatus.offline;
        }
      }
    } on TimeoutException catch (e) {
      if (_connectionStatus.value != NextcloudConnectionStatus.offline) {
        _logger.w('Nextcloud connection: Offline (Timeout: $e)');
        _connectionStatus.value = NextcloudConnectionStatus.offline;
      }
    } catch (e) {
      if (_connectionStatus.value != NextcloudConnectionStatus.offline) {
        _logger.w('Nextcloud connection: Offline (Error: $e)');
        _connectionStatus.value = NextcloudConnectionStatus.offline;
      }
    }
  }

  /// Dispose resources when service is no longer needed
  void dispose() {
    _timer?.cancel();
    _connectionStatus.dispose();
  }
}