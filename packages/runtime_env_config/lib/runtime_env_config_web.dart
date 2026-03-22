import 'dart:js_interop';

import 'runtime_env_config_platform_interface.dart';

@JS('ENV_CONFIG')
external JSAny? get _envConfig;

class RuntimeEnvConfigWeb extends RuntimeEnvConfigPlatform {
  @override
  Future<String?> pocketBaseUrl() async {
    try {
      final env = _envConfig;
      if (env == null) return null;

      final obj = env as JSObject;
      final urlAny = obj.getProperty('POCKETBASE_URL'.toJS);

      final url = urlAny?.dartify();
      if (url is String && url.isNotEmpty) return url;

      return null;
    } catch (_) {
      return null;
    }
  }
}