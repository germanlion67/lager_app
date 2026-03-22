import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_env_config/runtime_env_config.dart';
import 'package:runtime_env_config/runtime_env_config_platform_interface.dart';
import 'package:runtime_env_config/runtime_env_config_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockRuntimeEnvConfigPlatform
    with MockPlatformInterfaceMixin
    implements RuntimeEnvConfigPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final RuntimeEnvConfigPlatform initialPlatform = RuntimeEnvConfigPlatform.instance;

  test('$MethodChannelRuntimeEnvConfig is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelRuntimeEnvConfig>());
  });

  test('getPlatformVersion', () async {
    RuntimeEnvConfig runtimeEnvConfigPlugin = RuntimeEnvConfig();
    MockRuntimeEnvConfigPlatform fakePlatform = MockRuntimeEnvConfigPlatform();
    RuntimeEnvConfigPlatform.instance = fakePlatform;

    expect(await runtimeEnvConfigPlugin.getPlatformVersion(), '42');
  });
}
