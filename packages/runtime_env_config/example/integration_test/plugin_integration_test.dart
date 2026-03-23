// Integration Test für Runtime Environment Config
//
// Testet das Laden von Umgebungsvariablen zur Laufzeit.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:runtime_env_config/runtime_env_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RuntimeEnvConfig.pocketBaseUrl() test', (WidgetTester tester) async {
    // Test: pocketBaseUrl() sollte null oder einen String zurückgeben
    final String? pocketBaseUrl = await RuntimeEnvConfig.pocketBaseUrl();
    
    // Assertion: Entweder null oder ein nicht-leerer String
    expect(
      pocketBaseUrl == null || pocketBaseUrl.isNotEmpty,
      true,
      reason: 'pocketBaseUrl sollte null oder ein nicht-leerer String sein',
    );
  });

  testWidgets('RuntimeEnvConfig handles missing config gracefully', (WidgetTester tester) async {
    // Test: Auch wenn ENV_CONFIG nicht existiert, sollte kein Fehler geworfen werden
    try {
      final String? url = await RuntimeEnvConfig.pocketBaseUrl();
      expect(url, anyOf(isNull, isA<String>()));
    } catch (e) {
      fail('RuntimeEnvConfig.pocketBaseUrl() sollte keinen Fehler werfen: $e');
    }
  });
}