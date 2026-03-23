//../packages/runtime_env_config/lib/runtime_env_config_platform_interface.dart

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'runtime_env_config_method_channel.dart';

abstract class RuntimeEnvConfigPlatform extends PlatformInterface {
  RuntimeEnvConfigPlatform() : super(token: _token);

  static final Object _token = Object();

  static RuntimeEnvConfigPlatform _instance = MethodChannelRuntimeEnvConfig();

  static RuntimeEnvConfigPlatform get instance => _instance;

  static set instance(RuntimeEnvConfigPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> pocketBaseUrl();
}