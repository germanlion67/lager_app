import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lager_app/screens/settings_controller.dart';
import 'package:lager_app/screens/settings_state.dart';
import 'package:lager_app/services/pocketbase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PocketBaseService.dispose();
    showLastSyncNotifier.value = defaultShowLastSync;
  });

  tearDown(() {
    PocketBaseService.dispose();
  });

  group('SettingsController', () {
    test('lädt Defaults korrekt inklusive F-007 Default true', () async {
      final controller = SettingsController();

      await controller.init();

      expect(controller.artikelNummerController.text, '1000');
      expect(controller.showLastSync, isTrue);
      expect(showLastSyncNotifier.value, isTrue);

      controller.dispose();
    });

    test('lädt show_last_sync aus SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        showLastSyncPrefsKey: true,
      });

      final controller = SettingsController();
      await controller.init();

      expect(controller.showLastSync, isTrue);
      expect(showLastSyncNotifier.value, isTrue);

      controller.dispose();
    });

    test('erkennt URL-Änderung als ungespeicherte Änderung', () async {
      final controller = SettingsController();
      await controller.init();

      expect(controller.hasUnsavedChanges, isFalse);

      controller.pocketBaseUrlController.text = 'https://example.com';

      expect(controller.hasUnsavedChanges, isTrue);

      controller.dispose();
    });

    test('erkennt Artikelnummer-Änderung als ungespeicherte Änderung',
        () async {
      final controller = SettingsController();
      await controller.init();

      expect(controller.hasUnsavedChanges, isFalse);

      controller.artikelNummerController.text = '1234';

      expect(controller.hasUnsavedChanges, isTrue);

      controller.dispose();
    });

    test('setShowLastSync aktualisiert State, Notifier und Preferences',
        () async {
      final controller = SettingsController();
      await controller.init();

      final ok = await controller.setShowLastSync(true);
      final prefs = await SharedPreferences.getInstance();

      expect(ok, isTrue);
      expect(controller.showLastSync, isTrue);
      expect(showLastSyncNotifier.value, isTrue);
      expect(prefs.getBool(showLastSyncPrefsKey), isTrue);

      controller.dispose();
    });
  });
}