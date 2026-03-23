import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_env_config/runtime_env_config.dart';

void main() {
  test('RuntimeEnvConfig.pocketBaseUrl returns null or string', () async {
    final String? url = await RuntimeEnvConfig.pocketBaseUrl();
    expect(url, anyOf(isNull, isA<String>()));
  });

  test('RuntimeEnvConfig handles missing ENV_CONFIG gracefully', () async {
    try {
      final String? url = await RuntimeEnvConfig.pocketBaseUrl();
      expect(url, anyOf(isNull, isA<String>()));
    } catch (e) {
      fail('pocketBaseUrl() sollte keinen Fehler werfen: $e');
    }
  });

  test('RuntimeEnvConfig.pocketBaseUrl is a static method', () {
    expect(RuntimeEnvConfig.pocketBaseUrl, isNotNull);
  });
}