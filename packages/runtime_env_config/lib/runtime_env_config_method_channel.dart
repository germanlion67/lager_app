import 'runtime_env_config_platform_interface.dart';

/// Default implementation (non-web):
/// Gibt null zurück (keine Runtime-Konfiguration).
class MethodChannelRuntimeEnvConfig extends RuntimeEnvConfigPlatform {
  @override
  Future<String?> pocketBaseUrl() async => null;
}