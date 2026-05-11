//../packages/runtime_env_config/lib/runtime_env_config_web.dart


import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'runtime_env_config_platform_interface.dart';

class RuntimeEnvConfigWeb extends RuntimeEnvConfigPlatform {
  static void registerWith(Registrar registrar) {
    RuntimeEnvConfigPlatform.instance = RuntimeEnvConfigWeb();
  }

  @override
  Future<String?> pocketBaseUrl() async {
    try {
      // window.ENV_CONFIG lesen
      final config = globalContext.getProperty('ENV_CONFIG'.toJS);
      if (config == null || config.isUndefinedOrNull) return null;

      // ENV_CONFIG.POCKETBASE_URL lesen
      final jsValue =
          (config as JSObject).getProperty('POCKETBASE_URL'.toJS);
      if (jsValue == null || jsValue.isUndefinedOrNull) return null;

      final value = (jsValue as JSString).toDart;
      if (value.isNotEmpty) return value;

      return null;
    } catch (_) {
      return null;
    }
  }
}