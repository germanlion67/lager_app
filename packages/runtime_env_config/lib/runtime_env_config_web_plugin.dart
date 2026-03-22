import 'runtime_env_config_platform_interface.dart';
import 'runtime_env_config_web.dart';

/// Wird im Web automatisch aufgerufen (durch generated registrant),
/// und setzt die Web-Implementation.
void registerWith([Object? registrar]) {
  RuntimeEnvConfigPlatform.instance = RuntimeEnvConfigWeb();
}