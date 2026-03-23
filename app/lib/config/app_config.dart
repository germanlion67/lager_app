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
//
// UI-Konfiguration:
// - Artikel-Bild-Größen und BoxFit-Werte
// - Border-Radius-Werte
// - PocketBase Thumbnail-Parameter
// - Padding-Werte

import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
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
  /// 3. Web + Debug  → http://localhost:8080
  /// 4. Web + Release → https://your-production-server.com (Fallback)
  /// 5. Mobile/Desktop + Debug  → http://192.168.178.XX:8080
  /// 6. Mobile/Desktop + Release → https://your-production-server.com
  static String get pocketBaseUrl {
    // Priorität 1: Runtime-Config (nur Web)
    final runtimeUrl = _runtimePocketBaseUrl;
    if (runtimeUrl != null && runtimeUrl.isNotEmpty) {
      return runtimeUrl;
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

  /// Validiert die Konfiguration und wirft einen Error bei ungültiger
  /// Release-Konfiguration (z.B. Placeholder-URLs in Produktion).
  ///
  /// Sollte beim App-Start aufgerufen werden.
  static void validateConfig() {
    // Nur in Release-Builds validieren
    if (kDebugMode) return;

    // Runtime-Config (Web) ist OK - wird zur Laufzeit gesetzt
    final runtimeUrl = _runtimePocketBaseUrl;
    if (kIsWeb && runtimeUrl != null && runtimeUrl.isNotEmpty) {
      // Runtime-Config vorhanden, keine weitere Validierung nötig
      return;
    }

    // Build-Time-Validierung für Release-Builds
    if (hasPlaceholderUrl) {
      throw AssertionError(
        '❌ INVALID CONFIGURATION: Release build with placeholder URL!\n'
        '\n'
        'Current URL: $pocketBaseUrl\n'
        '\n'
        'LÖSUNG:\n'
        '• Web: Setze POCKETBASE_URL Umgebungsvariable (Runtime-Config)\n'
        '• Mobile/Desktop: Setze --dart-define=POCKETBASE_URL=https://...\n'
        '• Oder: Ändere die Fallback-URLs in app_config.dart\n'
        '\n'
        'Siehe: docs/PRODUCTION_DEPLOYMENT.md\n',
      );
    }
  }

  // ============================================================================
  // UI-Konfiguration
  // ============================================================================

  /// Größe des Artikel-Thumbnails in der Listenansicht (quadratisch).
  static const double artikelListBildSize = 50.0;

  /// Höhe des Artikel-Bildes in der Detailansicht.
  static const double artikelDetailBildHoehe = 200.0;

  /// BoxFit für Artikel-Bilder in der Listenansicht.
  static const BoxFit artikelListBildFit = BoxFit.cover;

  /// BoxFit für Artikel-Bilder in der Detailansicht.
  /// Geändert von cover zu contain für bessere Darstellung.
  static const BoxFit artikelDetailBildFit = BoxFit.contain;

  /// PocketBase Thumbnail-Größe (Query-Parameter ?thumb=WxH).
  /// Verwendet in _buildThumbnailUrl() für serverseitiges Thumbnail.
  static const String pbThumbGroesse = '60x60';

  /// Border-Radius für kleine Cards (z.B. Artikel-List-Thumbnails).
  static const double cardBorderRadiusSmall = 6.0;

  /// Border-Radius für größere Cards (z.B. Artikel-Detail-Bilder).
  static const double cardBorderRadiusLarge = 12.0;

  /// Standard-Padding für ListTiles.
  static const EdgeInsets listTilePadding = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 8.0,
  );

  // ============================================================================
  // Spacing-Konstanten
  // ============================================================================

  /// Extra kleiner Abstand (4px).
  static const double spacingXSmall = 4.0;

  /// Kleiner Abstand (8px).
  static const double spacingSmall = 8.0;

  /// Mittlerer Abstand (12px).
  static const double spacingMedium = 12.0;

  /// Großer Abstand (16px) - am häufigsten verwendet.
  static const double spacingLarge = 16.0;

  /// Extra großer Abstand (24px).
  static const double spacingXLarge = 24.0;

  /// Extra extra großer Abstand (32px).
  static const double spacingXXLarge = 32.0;

  // ============================================================================
  // Border-Radius-Konstanten
  // ============================================================================

  /// Extra kleiner Border-Radius (2px).
  static const double borderRadiusXXSmall = 2.0;

  /// Extra kleiner Border-Radius (4px).
  static const double borderRadiusXSmall = 4.0;

  /// Mittlerer Border-Radius (8px) - am häufigsten verwendet.
  static const double borderRadiusMedium = 8.0;

  /// Extra großer Border-Radius (16px).
  static const double borderRadiusXLarge = 16.0;

  // ============================================================================
  // Font-Size-Konstanten
  // ============================================================================

  /// Extra kleine Schriftgröße (10px).
  static const double fontSizeXSmall = 10.0;

  /// Kleine Schriftgröße (12px) - häufig für Body-Text.
  static const double fontSizeSmall = 12.0;

  /// Mittlere Schriftgröße (14px).
  static const double fontSizeMedium = 14.0;

  /// Große Schriftgröße (16px).
  static const double fontSizeLarge = 16.0;

  /// Extra große Schriftgröße (18px).
  static const double fontSizeXLarge = 18.0;

  /// Extra extra große Schriftgröße (20px).
  static const double fontSizeXXLarge = 20.0;
}