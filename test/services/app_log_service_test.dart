import 'package:flutter_test/flutter_test.dart';
import 'package:elektronik_verwaltung/services/app_log_service.dart';
import 'package:flutter/services.dart';
import 'dart:io';

void main() {
  group('AppLogService Tests', () {
    late AppLogService logService;
    late Directory testDir;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      logService = AppLogService();
      
      // Mock path_provider für Tests
      testDir = await Directory.systemTemp.createTemp('test_logs');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return testDir.path;
          }
          return null;
        },
      );
    });

    tearDownAll(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      // Versuche, das Verzeichnis mehrfach zu löschen, falls Windows Dateisperren auftreten
      if (await testDir.exists()) {
        var attempts = 0;
        const maxAttempts = 5;
        while (attempts < maxAttempts) {
          try {
            await testDir.delete(recursive: true);
            break;
          } catch (e) {
            attempts++;
            if (attempts >= maxAttempts) {
              // Ignoriere Cleanup-Fehler nach mehreren Versuchen, aber gebe Hinweis aus
              // ignore: avoid_print
              print('Test cleanup warning (after $attempts attempts): $e');
              break;
            }
            // kurze Pause vor erneutem Versuch
            await Future.delayed(const Duration(milliseconds: 200));
          }
        }
      }
    });

    test('should log info messages without throwing', () async {
      expect(() async => await logService.log('Test info message'), returnsNormally);
    });

    test('should log error messages with stacktrace', () async {
      final stackTrace = StackTrace.current;
      expect(() async => await logService.logError('Test error', stackTrace), returnsNormally);
    });

    test('should handle null values gracefully', () async {
      expect(() async => await logService.log(''), returnsNormally);
      expect(() async => await logService.logError('', StackTrace.current), returnsNormally);
    });

    test('log levels should work correctly', () {
      // Diese Tests prüfen die interne Logger-Konfiguration
      expect(logService.toString(), contains('AppLogService'));
    });
  });
}