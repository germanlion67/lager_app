// lib/services/connectivity_service.dart
//
// Plattformübergreifender Verbindungscheck ohne connectivity_plus auf Linux.
// Grund: connectivity_plus nutzt auf Linux NetworkManager via DBus —
// WSL2 hat keinen NetworkManager-Daemon → DBus-Fehler bei jedem Check.
// Lösung: Direkter TCP-Lookup auf Linux, connectivity_plus auf anderen Plattformen.

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ConnectivityService {
  ConnectivityService._();

  /// Gibt true zurück wenn eine Netzwerkverbindung besteht.
  ///
  /// - Web / Android / iOS / Windows / macOS → connectivity_plus
  /// - Linux (inkl. WSL2)                   → direkter TCP-Lookup
  static Future<bool> isConnected() async {
    // ── Linux: kein NetworkManager → direkter TCP-Check ─────────────────────
    if (!kIsWeb && Platform.isLinux) {
      return _tcpCheck();
    }

    // ── Alle anderen Plattformen → connectivity_plus ─────────────────────────
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.ethernet ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.vpn,
      );
    } catch (_) {
      // Fallback: TCP-Check wenn connectivity_plus unerwartet fehlschlägt
      return _tcpCheck();
    }
  }

  /// Gibt true zurück wenn WLAN aktiv ist.
  /// Auf Linux: identisch mit isConnected() — WSL2 kennt kein WLAN-Konzept.
  static Future<bool> isWifi() async {
    if (!kIsWeb && Platform.isLinux) {
      // WSL2 nutzt immer eine virtuelle Ethernet-Brücke — kein echtes WLAN.
      // Wir geben true zurück wenn überhaupt eine Verbindung besteht,
      // damit wifi_only_sync auf WSL2 nicht dauerhaft blockiert.
      return _tcpCheck();
    }

    try {
      final results = await Connectivity().checkConnectivity();
      return results.contains(ConnectivityResult.wifi);
    } catch (_) {
      return _tcpCheck();
    }
  }

  /// Direkter TCP-Lookup — kein DBus, kein NetworkManager nötig.
  static Future<bool> _tcpCheck() async {
    try {
      final result = await InternetAddress.lookup('8.8.8.8')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }
}