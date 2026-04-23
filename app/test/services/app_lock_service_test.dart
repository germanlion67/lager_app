// test/services/app_lock_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lager_app/services/app_lock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLockService', () {
    tearDown(() {
      AppLockService.resetForTesting();
      SharedPreferences.setMockInitialValues({});
    });

    group('init()', () {
      test('lädt Defaultwerte wenn keine Preferences gesetzt sind', () async {
        SharedPreferences.setMockInitialValues({});

        final service = AppLockService.testable();

        await service.init();

        expect(service.isEnabled, isFalse);
        expect(
          service.timeoutSeconds,
          AppLockService.defaultTimeoutSeconds,
        );
        expect(service.isBiometricsEnabled, isTrue);
      });

      test('lädt persistierte Werte korrekt', () async {
        SharedPreferences.setMockInitialValues({
          AppLockService.prefKeyEnabled: true,
          AppLockService.prefKeyTimeout: 120,
          AppLockService.prefKeyBiometrics: false,
        });

        final service = AppLockService.testable();

        await service.init();

        expect(service.isEnabled, isTrue);
        expect(service.timeoutSeconds, 120);
        expect(service.isBiometricsEnabled, isFalse);
      });

      test('ist idempotent und lädt nur einmal', () async {
        SharedPreferences.setMockInitialValues({
          AppLockService.prefKeyEnabled: true,
          AppLockService.prefKeyTimeout: 180,
          AppLockService.prefKeyBiometrics: false,
        });

        final service = AppLockService.testable();

        await service.init();

        expect(service.isEnabled, isTrue);
        expect(service.timeoutSeconds, 180);
        expect(service.isBiometricsEnabled, isFalse);

        SharedPreferences.setMockInitialValues({
          AppLockService.prefKeyEnabled: false,
          AppLockService.prefKeyTimeout: 999,
          AppLockService.prefKeyBiometrics: true,
        });

        await service.init();

        expect(service.isEnabled, isTrue);
        expect(service.timeoutSeconds, 180);
        expect(service.isBiometricsEnabled, isFalse);
      });
    });

    group('Persistenz', () {
      test('setEnabled(true) aktualisiert State und speichert Wert', () async {
        SharedPreferences.setMockInitialValues({});

        final service = AppLockService.testable();

        await service.setEnabled(true);

        expect(service.isEnabled, isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(AppLockService.prefKeyEnabled), isTrue);
      });

      test('setEnabled(false) aktualisiert State und speichert Wert', () async {
        SharedPreferences.setMockInitialValues({
          AppLockService.prefKeyEnabled: true,
        });

        final service = AppLockService.testable();

        await service.setEnabled(false);

        expect(service.isEnabled, isFalse);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(AppLockService.prefKeyEnabled), isFalse);
      });

      test(
        'setTimeoutSeconds() aktualisiert State und speichert Wert',
        () async {
          SharedPreferences.setMockInitialValues({});

          final service = AppLockService.testable();

          await service.setTimeoutSeconds(42);

          expect(service.timeoutSeconds, 42);

          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getInt(AppLockService.prefKeyTimeout), 42);
        },
      );

      test(
        'setBiometricsEnabled() aktualisiert State und speichert Wert',
        () async {
          SharedPreferences.setMockInitialValues({});

          final service = AppLockService.testable();

          await service.setBiometricsEnabled(false);

          expect(service.isBiometricsEnabled, isFalse);

          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getBool(AppLockService.prefKeyBiometrics), isFalse);
        },
      );
    });

    group('Lifecycle / Timeout', () {
      test('onAppResumed gibt false zurück wenn App-Lock deaktiviert ist',
          () async {
        DateTime current = DateTime(2026, 4, 23, 12, 0, 0);

        final service = AppLockService.testable(
          nowProvider: () => current,
        );

        service.onAppPaused();
        current = current.add(const Duration(minutes: 10));

        final shouldLock = service.onAppResumed();

        expect(shouldLock, isFalse);
      });

      test('onAppResumed gibt false zurück wenn nie pausiert wurde', () async {
        final service = AppLockService.testable();

        await service.setEnabled(true);

        final shouldLock = service.onAppResumed();

        expect(shouldLock, isFalse);
      });

      test('onAppResumed gibt false zurück wenn Timeout noch nicht erreicht ist',
          () async {
        DateTime current = DateTime(2026, 4, 23, 12, 0, 0);

        final service = AppLockService.testable(
          nowProvider: () => current,
        );

        await service.setEnabled(true);
        await service.setTimeoutSeconds(300);

        service.onAppPaused();
        current = current.add(const Duration(seconds: 299));

        final shouldLock = service.onAppResumed();

        expect(shouldLock, isFalse);
      });

      test('onAppResumed gibt true zurück wenn Timeout exakt erreicht ist',
          () async {
        DateTime current = DateTime(2026, 4, 23, 12, 0, 0);

        final service = AppLockService.testable(
          nowProvider: () => current,
        );

        await service.setEnabled(true);
        await service.setTimeoutSeconds(300);

        service.onAppPaused();
        current = current.add(const Duration(seconds: 300));

        final shouldLock = service.onAppResumed();

        expect(shouldLock, isTrue);
      });

      test('onAppResumed gibt true zurück wenn Timeout überschritten ist',
          () async {
        DateTime current = DateTime(2026, 4, 23, 12, 0, 0);

        final service = AppLockService.testable(
          nowProvider: () => current,
        );

        await service.setEnabled(true);
        await service.setTimeoutSeconds(300);

        service.onAppPaused();
        current = current.add(const Duration(minutes: 6));

        final shouldLock = service.onAppResumed();

        expect(shouldLock, isTrue);
      });

      test(
        'onAppResumed konsumiert pausedAt, zweiter Resume liefert false',
        () async {
          DateTime current = DateTime(2026, 4, 23, 12, 0, 0);

          final service = AppLockService.testable(
            nowProvider: () => current,
          );

          await service.setEnabled(true);
          await service.setTimeoutSeconds(60);

          service.onAppPaused();
          current = current.add(const Duration(minutes: 2));

          final firstResume = service.onAppResumed();
          final secondResume = service.onAppResumed();

          expect(firstResume, isTrue);
          expect(secondResume, isFalse);
        },
      );
    });
  });
}