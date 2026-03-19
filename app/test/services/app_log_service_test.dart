import 'package:flutter_test/flutter_test.dart';
import 'package:lager_app/services/app_log_service.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'dart:io';

void main() {
  group('AppLogService Tests', () {
    late Directory testDir;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

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
              // ignore: avoid_print
              print('Test cleanup warning (after $attempts attempts): $e');
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 200));
          }
        }
      }
    });

    // ==================== Logger-Instanz ====================

    test('AppLogService.logger sollte eine Logger-Instanz sein', () {
      // ✅ statische Eigenschaft prüfen — kein await nötig
      expect(AppLogService.logger, isA<Logger>());
    });

    test('AppLogService.logger sollte immer dieselbe Instanz zurückgeben', () {
      // ✅ Singleton-Verhalten prüfen
      final logger1 = AppLogService.logger;
      final logger2 = AppLogService.logger;
      expect(identical(logger1, logger2), isTrue);
    });

    // ==================== Logging ohne Exception ====================

    test('logger.i() sollte keine Exception werfen', () {
      // ✅ kein await — void
      expect(
        () => AppLogService.logger.i('Test info message'),
        returnsNormally,
      );
    });

    test('logger.w() sollte keine Exception werfen', () {
      // ✅ kein await — void
      expect(
        () => AppLogService.logger.w('Test warning message'),
        returnsNormally,
      );
    });

    test('logger.e() ohne StackTrace sollte keine Exception werfen', () {
      // ✅ kein await — void
      expect(
        () => AppLogService.logger.e('Test error message'),
        returnsNormally,
      );
    });

    test('logger.e() mit named error + stackTrace sollte keine Exception werfen', () {
      // ✅ named parameters — kein positional StackTrace
      final stack = StackTrace.current;
      expect(
        () => AppLogService.logger.e(
          'Test error mit StackTrace:',
          error: Exception('Test-Exception'),
          stackTrace: stack,
        ),
        returnsNormally,
      );
    });

    test('logger.d() sollte keine Exception werfen', () {
      // ✅ kein await — void
      expect(
        () => AppLogService.logger.d('Test debug message'),
        returnsNormally,
      );
    });

    // ==================== Edge Cases ====================

    test('logger.i() mit leerem String sollte keine Exception werfen', () {
      expect(() => AppLogService.logger.i(''), returnsNormally);
    });

    test('logger.e() mit leerem String sollte keine Exception werfen', () {
      expect(() => AppLogService.logger.e(''), returnsNormally);
    });

    test('logger.e() mit langem String sollte keine Exception werfen', () {
      final longMessage = 'A' * 10000;
      expect(() => AppLogService.logger.e(longMessage), returnsNormally);
    });

    test('logger.i() mit Sonderzeichen sollte keine Exception werfen', () {
      expect(
        () => AppLogService.logger.i('Sonderzeichen: äöü ß 🚀 \n\t'),
        returnsNormally,
      );
    });

    test('logger.e() mit echtem Exception-Objekt sollte keine Exception werfen', () {
      expect(
        () => AppLogService.logger.e(
          'Echter Fehler:',
          error: StateError('Ungültiger Zustand'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });

    // ==================== Log-Level ====================

    test('logger.t() (trace) sollte keine Exception werfen', () {
      expect(() => AppLogService.logger.t('Trace message'), returnsNormally);
    });

    test('logger.f() (fatal) sollte keine Exception werfen', () {
      expect(() => AppLogService.logger.f('Fatal message'), returnsNormally);
    });
  });
}