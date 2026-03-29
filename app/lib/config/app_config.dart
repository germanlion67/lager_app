// lib/config/app_config.dart
//
// Zentrale App-Konfiguration mit Runtime-Unterstützung.
//
// URL-Priorität:
// 1. window.ENV_CONFIG.POCKETBASE_URL (Runtime - Web only)
// 2. --dart-define=POCKETBASE_URL=https://...  (Build-Zeit)
// 3. Leer → PocketBaseService prüft SharedPreferences → Setup-Screen
//
// Für Produktion (Web): Runtime-Config wird automatisch beim Container-Start
// aus Umgebungsvariablen generiert (docker-entrypoint.sh).
//
// Für Produktion (Mobile/Desktop): URL wird beim Erststart über den
// Setup-Screen eingegeben und in SharedPreferences gespeichert.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show BoxFit, EdgeInsets;
import 'package:runtime_env_config/runtime_env_config.dart';

class AppConfig {
  AppConfig._();

  // Über --dart-define=POCKETBASE_URL=https://... überschreibbar.
  // Leer wenn nicht gesetzt → Fallback greift.
  static const String _pocketBaseUrlOverride = String.fromEnvironment(
    'POCKETBASE_URL',
    defaultValue: '',
  );

  // Runtime-Config Cache (nur Web sinnvoll).
  //
  // Wird über init() befüllt, damit pocketBaseUrl synchron bleiben kann.
  static String? _runtimePocketBaseUrl;

  /// Muss beim App-Start aufgerufen werden (vor validateConfig() und idealerweise
  /// vor der ersten Nutzung von pocketBaseUrl).
  static Future<void> init() async {
    if (!kIsWeb) return;

    try {
      _runtimePocketBaseUrl = await RuntimeEnvConfig.pocketBaseUrl();
    } catch (_) {
      _runtimePocketBaseUrl = null;
    }
  }

  /// Liefert die PocketBase-Basis-URL passend zur aktuellen Umgebung.
  ///
  /// Reihenfolge:
  /// 1. `window.ENV_CONFIG.POCKETBASE_URL` (Runtime - Web only)
  /// 2. `--dart-define=POCKETBASE_URL=...` (Build-Zeit)
  /// 3. Leer → PocketBaseService nutzt SharedPreferences oder Setup-Screen
  ///
  /// Gibt einen leeren String zurück, wenn keine Quelle eine URL liefert.
  /// Das ist gewollt: Die App crasht nicht, sondern zeigt den Setup-Screen.
  static String get pocketBaseUrl {
    // Priorität 1: Runtime-Config (nur Web)
    final runtimeUrl = _runtimePocketBaseUrl;
    if (runtimeUrl != null && runtimeUrl.isNotEmpty) {
      return runtimeUrl;
    }

    // Priorität 2: Explizites Build-Argument
    if (_pocketBaseUrlOverride.isNotEmpty) return _pocketBaseUrlOverride;

    // Priorität 3: Kein Wert verfügbar
    // → PocketBaseService prüft SharedPreferences
    // → Falls auch dort nichts: Setup-Screen
    return '';
  }

  /// Gibt `true` zurück wenn eine URL aus Build-Zeit oder Runtime-Config
  /// verfügbar ist (unabhängig von SharedPreferences).
  static bool get hasConfiguredUrl => pocketBaseUrl.isNotEmpty;

/// Gibt `true` zurück wenn die aktuelle Konfiguration noch
  /// unveränderte Placeholder enthält.
  static bool get hasPlaceholderUrl =>
      pocketBaseUrl.contains('192.168.178.XX') ||
      pocketBaseUrl.contains('your-production-server.com');

  /// Gibt `true` zurück wenn eine Runtime-Config geladen wurde (Web/Docker).
  /// Wird verwendet um zu unterscheiden ob die Web-App im Docker-Container
  /// (mit Proxy) oder via `flutter run -d chrome` (ohne Proxy) läuft.
  static bool get hasRuntimeConfig =>
      _runtimePocketBaseUrl != null && _runtimePocketBaseUrl!.isNotEmpty;

  /// Validiert die Konfiguration.
  ///
  /// Nach dem Umbau auf Runtime-Konfiguration ist eine fehlende URL
  /// kein Fehler mehr – der Setup-Screen fängt diesen Fall ab.
  /// Nur noch echte Placeholder werden als Warnung geloggt.
  static void validateConfig() {
    // Placeholder-Warnung (kein Crash mehr)
    if (hasPlaceholderUrl) {
      // In Debug: nur Warnung, kein Crash
      assert(() {
        // ignore: avoid_print
        print(
          '⚠️ WARNUNG: PocketBase URL enthält einen Placeholder!\n'
          'Aktuelle URL: $pocketBaseUrl\n'
          'Die URL kann über den Setup-Screen konfiguriert werden.',
        );
        return true;
      }());
    }
  }

  /// H-004: Validierung für Release-Builds.
  ///
  /// Nach dem Umbau auf Runtime-Konfiguration ist eine fehlende URL
  /// kein Fehler mehr. Der Setup-Screen wird stattdessen angezeigt.
  ///
  /// Placeholder-URLs werden weiterhin als Warnung behandelt,
  /// führen aber nicht mehr zum Crash.
  static void validateForRelease() {
    // Keine harten Fehler mehr – der Setup-Screen fängt alles ab.
    // Placeholder-Warnung wird über validateConfig() ausgegeben.
  }

  // ============================================================================
  // UI-Konfiguration (unverändert)
  // ============================================================================

  /// Größe des Artikel-Thumbnails in der Listenansicht (quadratisch).
  static const double artikelListBildSize = 50.0;

  /// Höhe des Artikel-Bildes in der Detailansicht.
  static const double artikelDetailBildHoehe = 200.0;

  /// BoxFit für Artikel-Bilder in der Listenansicht.
  static const BoxFit artikelListBildFit = BoxFit.cover;

  /// BoxFit für Artikel-Bilder in der Detailansicht.
  static const BoxFit artikelDetailBildFit = BoxFit.contain;

  /// PocketBase Thumbnail-Größe (Query-Parameter ?thumb=WxH).
  static const String pbThumbGroesse = '60x60';

  /// Border-Radius für kleine Cards.
  static const double cardBorderRadiusSmall = 6.0;

  /// Border-Radius für größere Cards.
  static const double cardBorderRadiusLarge = 12.0;

  /// Standard-Padding für ListTiles.
  static const EdgeInsets listTilePadding = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 8.0,
  );

  // ============================================================================
  // Spacing-Konstanten (unverändert)
  // ============================================================================

  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 12.0;
  static const double spacingLarge = 16.0;
  static const double spacingXLarge = 24.0;
  static const double spacingXXLarge = 32.0;

  // ============================================================================
  // Border-Radius-Konstanten (unverändert)
  // ============================================================================

  static const double borderRadiusXXSmall = 2.0;
  static const double borderRadiusXSmall = 4.0;
  static const double borderRadiusMedium = 8.0;
  static const double borderRadiusXLarge = 16.0;

  // ============================================================================
  // Font-Size-Konstanten (unverändert)
  // ============================================================================

  static const double fontSizeXSmall = 10.0;
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeLarge = 16.0;
  static const double fontSizeXLarge = 18.0;
  static const double fontSizeXXLarge = 20.0;
}