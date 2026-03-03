import 'package:flutter_test/flutter_test.dart';
import 'package:elektronik_verwaltung/services/nextcloud_credentials.dart';

void main() {
  group('NextcloudCredentials Tests', () {
    test('should create credentials with all fields', () {
      final creds = NextcloudCredentials(
        server: Uri.parse('https://example.nextcloud.com'),
        user: 'testuser',
        appPw: 'app-password-123',
        baseFolder: '/Elektronik',
        checkIntervalMinutes: 15,
      );

      expect(creds.server.toString(), 'https://example.nextcloud.com');
      expect(creds.user, 'testuser');
      expect(creds.appPw, 'app-password-123');
      expect(creds.baseFolder, '/Elektronik');
      expect(creds.checkIntervalMinutes, 15);
    });

    test('should use default check interval when not specified', () {
      final creds = NextcloudCredentials(
        server: Uri.parse('https://test.com'),
        user: 'user123',
        appPw: 'password456',
        baseFolder: '/Test',
      );

      expect(creds.checkIntervalMinutes, 10); // Default value
    });

    test('should handle different URI formats', () {
      final httpsCreds = NextcloudCredentials(
        server: Uri.parse('https://secure.nextcloud.com/path'),
        user: 'secureuser',
        appPw: 'securepw',
        baseFolder: '/SecureFolder',
      );

      expect(httpsCreds.server.scheme, 'https');
      expect(httpsCreds.server.host, 'secure.nextcloud.com');
      expect(httpsCreds.server.path, '/path');
    });
  });

  group('NextcloudCredentialsStore Tests', () {
    // Diese Tests benötigen FlutterSecureStorage Mock, 
    // was in Unit Tests komplex ist - überspringe für jetzt
    test('store should exist and be instantiable', () {
      final store = NextcloudCredentialsStore();
      expect(store, isA<NextcloudCredentialsStore>());
    });
  });
}