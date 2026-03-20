// lib/config/app_config.dart
//
// Zentrale App-Konfiguration.
//
// URL-Priorität:
// 1. --dart-define=POCKETBASE_URL=https://...  (Build-Zeit)
// 2. Plattform + Debug/Release Fallback
//
// Für Produktion: 'your-production-server.com' durch echte URL ersetzen
// oder per --dart-define=POCKETBASE_URL=... zur Build-Zeit übergeben.

import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

class AppConfig {
  AppConfig._();

  // Über --dart-define=POCKETBASE_URL=https://... überschreibbar.
  // Leer wenn nicht gesetzt → Fallback greift.
  static const String _pocketBaseUrlOverride = String.fromEnvironment(
    'POCKETBASE_URL',
    defaultValue: '',
  );

  /// Liefert die PocketBase-Basis-URL passend zur aktuellen Umgebung.
  ///
  /// Reihenfolge:
  /// 1. `--dart-define=POCKETBASE_URL=...` (Build-Zeit, höchste Priorität)
  /// 2. Web + Debug  → http://localhost:8090
  /// 3. Web + Release → https://your-production-server.com
  /// 4. Mobile/Desktop + Debug  → http://192.168.178.XX:8090
  /// 5. Mobile/Desktop + Release → https://your-production-server.com
  static String get pocketBaseUrl {
    // Priorität 1: Explizites Build-Argument
    if (_pocketBaseUrlOverride.isNotEmpty) return _pocketBaseUrlOverride;

    if (kIsWeb) {
      return kDebugMode
          ? 'http://localhost:8080'
          : 'https://your-production-server.com';
    }

    // Mobile / Desktop
    // FIX: Placeholder dokumentiert — muss vor erstem Build ersetzt werden.
    return kDebugMode
        ? 'http://192.168.178.XX:8090' // ← lokale Dev-IP hier eintragen
        : 'https://your-production-server.com';
  }

  /// Gibt `true` zurück wenn die aktuelle Konfiguration noch
  /// unveränderte Placeholder enthält.
  static bool get hasPlaceholderUrl =>
      pocketBaseUrl.contains('192.168.178.XX') ||
      pocketBaseUrl.contains('your-production-server.com');
}