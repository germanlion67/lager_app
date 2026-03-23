import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_env_config/runtime_env_config_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelRuntimeEnvConfig platform = MethodChannelRuntimeEnvConfig();
  const MethodChannel channel = MethodChannel('runtime_env_config');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'getPocketBaseUrl') {
            return 'https://pocketbase.example.com';
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('pocketBaseUrl returns null', () async {
    expect(await platform.pocketBaseUrl(), isNull);
  });
}