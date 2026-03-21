// lib/config/app_config.dart
//
// Zentrale App-Konfiguration mit Runtime-Unterstützung.
//
// URL-Priorität:
// 1. window.ENV_CONFIG.POCKETBASE_URL (Runtime - Web only)
// 2. --dart-define=POCKETBASE_URL=https://...  (Build-Zeit)
// 3. Plattform + Debug/Release Fallback
//
// Für Produktion: Runtime-Config wird automatisch beim Container-Start
// aus Umgebungsvariablen generiert (docker-entrypoint.sh).

import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'dart:js' as js;

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
  /// 1. `window.ENV_CONFIG.POCKETBASE_URL` (Runtime - Web only)
  /// 2. `--dart-define=POCKETBASE_URL=...` (Build-Zeit)
  /// 3. Web + Debug  → http://localhost:8080
  /// 4. Web + Release → https://your-production-server.com (Fallback)
  /// 5. Mobile/Desktop + Debug  → http://192.168.178.XX:8080
  /// 6. Mobile/Desktop + Release → https://your-production-server.com
  static String get pocketBaseUrl {
    // Priorität 1: Runtime-Config (nur Web)
    if (kIsWeb) {
      try {
        final runtimeUrl = js.context['ENV_CONFIG']?['POCKETBASE_URL'];
        if (runtimeUrl != null && runtimeUrl.toString().isNotEmpty) {
          return runtimeUrl.toString();
        }
      } catch (e) {
        // ENV_CONFIG nicht verfügbar, fahre mit Fallbacks fort
      }
    }

    // Priorität 2: Explizites Build-Argument
    if (_pocketBaseUrlOverride.isNotEmpty) return _pocketBaseUrlOverride;

    if (kIsWeb) {
      return kDebugMode
          ? 'http://localhost:8080'
          : 'https://your-production-server.com';
    }

    // Mobile / Desktop
    // FIX: Placeholder dokumentiert — muss vor erstem Build ersetzt werden.
    return kDebugMode
        ? 'http://192.168.178.XX:8080' // ← lokale Dev-IP hier eintragen
        : 'https://your-production-server.com';
  }

  /// Gibt `true` zurück wenn die aktuelle Konfiguration noch
  /// unveränderte Placeholder enthält.
  static bool get hasPlaceholderUrl =>
      pocketBaseUrl.contains('192.168.178.XX') ||
      pocketBaseUrl.contains('your-production-server.com');
}