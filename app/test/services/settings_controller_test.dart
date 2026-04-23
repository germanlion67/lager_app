import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lager_app/screens/settings_controller.dart';
import 'package:lager_app/screens/settings_state.dart';
import 'package:lager_app/services/pocketbase_service.dart';

class FakePocketBaseService extends PocketBaseService {
  FakePocketBaseService({
    this.initialUrl = '',
    this.updateUrlResult = true,
    this.checkHealthResult = true,
    this.defaultUrlAfterReset = '',
  }) : super.testable() {
    _url = initialUrl;
  }

  final String initialUrl;
  final bool updateUrlResult;
  final bool checkHealthResult;
  final String defaultUrlAfterReset;

  String _url = '';
  bool resetCalled = false;
  String? lastUpdateUrl;

  @override
  String get url => _url;

  @override
  Future<bool> updateUrl(String newUrl) async {
    lastUpdateUrl = newUrl;
    if (updateUrlResult) {
      _url = newUrl.trim();
    }
    return updateUrlResult;
  }

  @override
  Future<bool> checkHealth() async {
    return checkHealthResult;
  }

  @override
  Future<void> resetToDefault() async {
    resetCalled = true;
    _url = defaultUrlAfterReset;
  }
}

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

    test('setzt hasUnsavedChanges zurück, wenn URL auf Initialwert zurückgesetzt wird',
        () async {
      final controller = SettingsController();
      await controller.init();

      expect(controller.hasUnsavedChanges, isFalse);

      final initialUrl = controller.pocketBaseUrlController.text;

      controller.pocketBaseUrlController.text = 'https://example.com';
      expect(controller.hasUnsavedChanges, isTrue);

      controller.pocketBaseUrlController.text = initialUrl;
      expect(controller.hasUnsavedChanges, isFalse);

      controller.dispose();
    });

    test(
        'setShowLastSync aktualisiert State, Notifier und Preferences auch auf false',
        () async {
      SharedPreferences.setMockInitialValues({
        showLastSyncPrefsKey: true,
      });

      final controller = SettingsController();
      await controller.init();

      expect(controller.showLastSync, isTrue);
      expect(showLastSyncNotifier.value, isTrue);

      final ok = await controller.setShowLastSync(false);
      final prefs = await SharedPreferences.getInstance();

      expect(ok, isTrue);
      expect(controller.showLastSync, isFalse);
      expect(showLastSyncNotifier.value, isFalse);
      expect(prefs.getBool(showLastSyncPrefsKey), isFalse);

      controller.dispose();
    });

    test('resetPocketBaseUrl setzt URL zurück und entfernt ungespeicherte Änderungen',
        () async {
      final fakeService = FakePocketBaseService(
        initialUrl: 'https://initial.example.com',
        defaultUrlAfterReset: 'https://default.example.com',
      );

      final controller = SettingsController(pocketBaseService: fakeService);
      await controller.init();

      expect(controller.pocketBaseUrlController.text, 'https://initial.example.com');
      expect(controller.hasUnsavedChanges, isFalse);

      controller.pocketBaseUrlController.text = 'https://changed.example.com';
      expect(controller.hasUnsavedChanges, isTrue);

      await controller.resetPocketBaseUrl();

      expect(fakeService.resetCalled, isTrue);
      expect(
        controller.pocketBaseUrlController.text,
        'https://default.example.com',
      );
      expect(controller.hasUnsavedChanges, isFalse);
      expect(controller.pbConnectionOk, isNull);

      controller.dispose();
    });

    test('saveSettings setzt URL bei Ablehnung auf Initialwert zurück', () async {
      final fakeService = FakePocketBaseService(
        initialUrl: 'https://initial.example.com',
        updateUrlResult: false,
      );

      final controller = SettingsController(pocketBaseService: fakeService);
      await controller.init();

      controller.pocketBaseUrlController.text = 'https://invalid.example.com';

      final result = await controller.saveSettings();

      expect(result, SaveSettingsResult.pocketBaseUrlRejected);
      expect(controller.pocketBaseUrlController.text, 'https://initial.example.com');
      expect(controller.pbConnectionOk, isFalse);
      expect(controller.hasUnsavedChanges, isFalse);

      controller.dispose();
    });

    test('saveSettings übernimmt gültige URL und markiert als gespeichert',
        () async {
      final fakeService = FakePocketBaseService(
        initialUrl: 'https://initial.example.com',
        updateUrlResult: true,
      );

      final controller = SettingsController(pocketBaseService: fakeService);
      await controller.init();

      controller.pocketBaseUrlController.text = 'https://new.example.com';

      final result = await controller.saveSettings();

      expect(result, SaveSettingsResult.success);
      expect(fakeService.lastUpdateUrl, 'https://new.example.com');
      expect(controller.pocketBaseUrlController.text, 'https://new.example.com');
      expect(controller.hasUnsavedChanges, isFalse);

      controller.dispose();
    });

    test('testPocketBaseConnection setzt pbConnectionOk auf true bei Erfolg',
        () async {
      final fakeService = FakePocketBaseService(
        initialUrl: 'https://initial.example.com',
        checkHealthResult: true,
      );

      final controller = SettingsController(pocketBaseService: fakeService);
      await controller.init();

      final ok = await controller.testPocketBaseConnection();

      expect(ok, isTrue);
      expect(controller.pbConnectionOk, isTrue);

      controller.dispose();
    });

    test('testPocketBaseConnection setzt pbConnectionOk auf false bei Fehler',
        () async {
      final fakeService = FakePocketBaseService(
        initialUrl: 'https://initial.example.com',
        checkHealthResult: false,
      );

      final controller = SettingsController(pocketBaseService: fakeService);
      await controller.init();

      final ok = await controller.testPocketBaseConnection();

      expect(ok, isFalse);
      expect(controller.pbConnectionOk, isFalse);

      controller.dispose();
    });

  });
}