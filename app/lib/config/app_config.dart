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
  // UI-Konfiguration
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
  // Spacing-Konstanten
  // ============================================================================

  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 12.0;
  static const double spacingLarge = 16.0;
  static const double spacingXLarge = 24.0;
  static const double spacingXXLarge = 32.0;

  // ============================================================================
  // Border-Radius-Konstanten
  // ============================================================================

  static const double borderRadiusXXSmall = 2.0;
  static const double borderRadiusXSmall = 4.0;
  static const double borderRadiusMedium = 8.0;
  static const double borderRadiusXLarge = 16.0;

  // ============================================================================
  // Font-Size-Konstanten
  // ============================================================================

  static const double fontSizeXSmall = 10.0;
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeLarge = 16.0;
  static const double fontSizeXLarge = 18.0;
  static const double fontSizeXXLarge = 20.0;

  // ============================================================================
  // Icon-Größen (O-004: Hardcoded Icon-Sizes eliminieren)
  // ============================================================================

  /// Kleine Icons in Chips, Badges, kompakten Stat-Zeilen.
  static const double iconSizeXSmall = 14.0;

  /// Standard-Inline-Icons — Fortschrittsanzeigen, kompakte Buttons.
  static const double iconSizeSmall = 16.0;

  /// Status-Icons in Dialog-Titeln, Card-Headern.
  static const double iconSizeMedium = 20.0;

  /// Größere Icons in Card-Headern, ListTile-Leading.
  static const double iconSizeLarge = 24.0;

  // ============================================================================
  // Stroke / Border-Breiten (O-004: Hardcoded strokeWidth eliminieren)
  // ============================================================================

  /// Dünne Borders für Chips, Badges, Status-Container.
  static const double strokeWidthThin = 1.0;

  /// Standard-Stroke für CircularProgressIndicator u.ä.
  static const double strokeWidthMedium = 2.0;

  /// Dickerer Stroke für prominente Progress-Indikatoren (z.B. FAB).
  static const double strokeWidthThick = 3.0;

  // ============================================================================
  // Spezifische Layout-Konstanten (O-004)
  // ============================================================================

  /// Breite des Label-Bereichs in Info-Zeilen (z.B. Settings-InfoCard).
  static const double infoLabelWidth = 120.0;

  /// Standard-Radius für CircleAvatars in Listen/Cards.
  static const double avatarRadiusSmall = 20.0;

  /// Breite für modale Dialog-Content-Bereiche.
  static const double dialogContentWidth = 300.0;

  /// Größe des kreisförmigen Progress-Indicators (z.B. in FAB).
  static const double progressIndicatorSize = 32.0;

  // ============================================================================
  // Opacity-Konstanten (O-004: Hardcoded withOpacity/withValues eliminieren)
  // ============================================================================

  /// Leichte Hintergrund-Transparenz für Status-Chips, Stat-Badges.
  static const double opacitySubtle = 0.1;

  /// Mittlere Transparenz für Container-Hintergründe, Overlays.
  static const double opacityLight = 0.2;

  /// Stärkere Transparenz für Progress-Hintergründe, Borders.
  static const double opacityMedium = 0.3;

  /// Breite des Label-Bereichs in kompakten Detail-Zeilen
  /// (z.B. Conflict-Resolution Version-Cards). Schmaler als infoLabelWidth.
  static const double infoLabelWidthSmall = 80.0;

  /// Vertikale Padding-Höhe für Buttons mit mehr Gewicht (12.0).
  static const double buttonPaddingVertical = 12.0;

  // ============================================================================
  // Layout-Konstanten Batch 4 (O-004)
  // ============================================================================

  /// Icon-Größe für große Platzhalter (Empty-States, Upload-Area-Header).
  static const double iconSizeXLarge = 48.0;

  /// Icon-Größe für Setup-Screen Header.
  static const double iconSizeXXLarge = 64.0;

  /// Maximale Breite für Login-Formulare.
  static const double loginFormMaxWidth = 400.0;

  /// Maximale Breite für Setup-Formulare.
  static const double setupFormMaxWidth = 480.0;

  /// Größe des App-Logos auf dem Login-Screen.
  static const double loginLogoSize = 80.0;

  /// Höhe für prominente Buttons (z.B. Login).
  static const double buttonHeight = 48.0;

  /// Kleiner Progress-Indikator in Buttons.
  static const double progressIndicatorSizeSmall = 20.0;

  /// Breite der Label-Spalte in Beispiel-Zeilen (Setup-Screen).
  static const double exampleLabelWidth = 85.0;

  /// Thumbnail-Breite für Bild-Anhänge in der Liste.
  static const double attachmentImageWidth = 56.0;

  /// Thumbnail-Höhe für Bild-Anhänge in der Liste.
  static const double attachmentImageHeight = 48.0;

  /// Standard-Icon-Größe in Anhang-Tiles.
  static const double attachmentIconSize = 28.0;

  /// Container-Größe für Anhang-Typ-Icons.
  static const double attachmentIconContainerSize = 48.0;

  /// Icon-Größe für Fehler-Fallback in Bild-Anhängen.
  static const double uploadAreaIconSize = 40.0;
}