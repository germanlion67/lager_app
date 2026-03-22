/// runtime_env_config
///
/// Kleines Flutter-Plugin, das (nur im Web) Runtime-Konfiguration
/// aus `window.ENV_CONFIG` liest.
///
/// Motivation:
/// - In App-Code soll weder `dart:js` noch `dart:html` importiert werden.
/// - Lint-Regel `avoid_web_libraries_in_flutter` bleibt dadurch sauber.
/// - Web-only Code lebt im Web-Plugin (best practice).

import 'runtime_env_config_platform_interface.dart';

class RuntimeEnvConfig {
  /// Liest `window.ENV_CONFIG.POCKETBASE_URL` (nur Web).
  ///
  /// Returns:
  /// - Web: String? (null wenn nicht gesetzt)
  /// - Non-web: null
  static Future<String?> pocketBaseUrl() {
    return RuntimeEnvConfigPlatform.instance.pocketBaseUrl();
  }
}