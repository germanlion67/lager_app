//../packages/runtime_env_config/lib/runtime_env_config_web.dart


import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'runtime_env_config_platform_interface.dart';

class RuntimeEnvConfigWeb extends RuntimeEnvConfigPlatform {
  /// Wird vom Flutter Web Plugin-Registrator aufgerufen.
  static void registerWith(Registrar registrar) {
    RuntimeEnvConfigPlatform.instance = RuntimeEnvConfigWeb();
  }

  @override
  Future<String?> pocketBaseUrl() async {
    try {
      // Erwartet: window.ENV_CONFIG = { POCKETBASE_URL: "..." }
      final dynamic envConfig = (web.window as dynamic).ENV_CONFIG;
      if (envConfig == null) return null;

      final dynamic value = envConfig.POCKETBASE_URL;
      if (value is String && value.isNotEmpty) return value;

      return null;
    } catch (_) {
      return null;
    }
  }
}
