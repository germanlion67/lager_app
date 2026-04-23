// lib/screens/settings_controller.dart

import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_lock_service.dart';
import '../services/app_log_service.dart';
import '../services/artikel_db_service.dart';
import '../services/pocketbase_service.dart';
import 'settings_state.dart';

enum SaveSettingsResult {
  success,
  pocketBaseUrlRejected,
  error,
}

class SettingsController extends ChangeNotifier {
  SettingsController({
    PocketBaseService? pocketBaseService,
    ArtikelDbService? artikelDbService,
    AppLockService? appLockService,
  })  : _pbService = pocketBaseService ?? PocketBaseService(),
        _db = artikelDbService ?? ArtikelDbService(),
        _appLockService = appLockService ?? AppLockService() {
    pocketBaseUrlController.addListener(checkForUnsavedChanges);
    artikelNummerController.addListener(checkForUnsavedChanges);
  }

  final PocketBaseService _pbService;
  final ArtikelDbService _db;
  final AppLockService _appLockService;

  static const String _artikelStartNummerPrefsKey = 'artikel_start_nummer';

  final TextEditingController artikelNummerController = TextEditingController();
  final TextEditingController pocketBaseUrlController = TextEditingController();

  bool isDatabaseEmpty = true;
  bool isCheckingConnection = false;
  bool? pbConnectionOk;

  bool appLockEnabled = false;
  bool appLockBiometricsEnabled = true;
  int appLockTimeoutMinutes = 5;

  bool hasUnsavedChanges = false;
  String _initialUrl = '';
  String _initialArtikelNummer = '';

  bool showLastSync = defaultShowLastSync;

  Future<void> init() async {
    await loadSettings();
    if (!kIsWeb) {
      await checkDatabaseStatus();
    }
  }

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      artikelNummerController.text =
          (prefs.getInt(_artikelStartNummerPrefsKey) ?? 1000).toString();
      pocketBaseUrlController.text = _pbService.url;

      if (!kIsWeb) {
        await _appLockService.init();
        appLockEnabled = _appLockService.isEnabled;
        appLockBiometricsEnabled = _appLockService.isBiometricsEnabled;
        appLockTimeoutMinutes =
            (_appLockService.timeoutSeconds / 60).round().clamp(1, 30);
      }

      _initialUrl = pocketBaseUrlController.text.trim();
      _initialArtikelNummer = artikelNummerController.text.trim();
      hasUnsavedChanges = false;

      showLastSync =
          prefs.getBool(showLastSyncPrefsKey) ?? defaultShowLastSync;
      showLastSyncNotifier.value = showLastSync;

      pbConnectionOk = null;

      notifyListeners();
    } catch (e, st) {
      AppLogService.logger.e(
        'Laden fehlgeschlagen',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  void checkForUnsavedChanges() {
    final urlChanged = pocketBaseUrlController.text.trim() != _initialUrl;
    final artikelChanged =
        artikelNummerController.text.trim() != _initialArtikelNummer;
    final dirty = urlChanged || artikelChanged;
    if (dirty != hasUnsavedChanges) {
      hasUnsavedChanges = dirty;
      notifyListeners();
    }
  }

  Future<bool> setShowLastSync(bool value) async {
    final previous = showLastSync;

    showLastSync = value;
    showLastSyncNotifier.value = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(showLastSyncPrefsKey, value);
      return true;
    } catch (e, st) {
      AppLogService.logger.e(
        'show_last_sync speichern fehlgeschlagen',
        error: e,
        stackTrace: st,
      );
      showLastSync = previous;
      showLastSyncNotifier.value = previous;
      notifyListeners();
      return false;
    }
  }

  Future<void> checkDatabaseStatus() async {
    if (kIsWeb) return;
    try {
      isDatabaseEmpty = await _db.isDatabaseEmpty();
      notifyListeners();
    } catch (e, st) {
      AppLogService.logger.e(
        'DB-Status prüfen fehlgeschlagen',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<bool> testPocketBaseConnection() async {
    isCheckingConnection = true;
    pbConnectionOk = null;
    notifyListeners();

    try {
      final ok = await _pbService.checkHealth();
      pbConnectionOk = ok;
      return ok;
    } catch (e, st) {
      AppLogService.logger.e(
        'PocketBase-Test fehlgeschlagen',
        error: e,
        stackTrace: st,
      );
      pbConnectionOk = false;
      return false;
    } finally {
      isCheckingConnection = false;
      notifyListeners();
    }
  }

  Future<bool> resetPocketBaseUrl() async {
    try {
      await _pbService.resetToDefault();
      final resetUrl = _pbService.url;
      pocketBaseUrlController.text = resetUrl;
      _initialUrl = resetUrl;
      pbConnectionOk = null;
      hasUnsavedChanges =
          artikelNummerController.text.trim() != _initialArtikelNummer;
      notifyListeners();
      return true;
    } catch (e, st) {
      AppLogService.logger.e(
        'URL-Reset fehlgeschlagen',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  Future<bool> deleteDatabase() async {
    if (kIsWeb) return false;
    try {
      final startId =
          int.tryParse(artikelNummerController.text.trim()) ?? 1000;
      await _db.resetDatabase(startId: startId);
      await checkDatabaseStatus();
      await loadSettings();
      return true;
    } catch (e, st) {
      AppLogService.logger.e(
        'DB-Löschen fehlgeschlagen',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  Future<SaveSettingsResult> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newUrl = pocketBaseUrlController.text.trim();

      if (newUrl.isNotEmpty && newUrl != _initialUrl) {
        final urlUpdated = await _pbService.updateUrl(newUrl);
        if (!urlUpdated) {
          pocketBaseUrlController.text = _initialUrl;
          pbConnectionOk = false;
          checkForUnsavedChanges();
          notifyListeners();
          return SaveSettingsResult.pocketBaseUrlRejected;
        }

        final normalizedUrl = _pbService.url;
        pocketBaseUrlController.text = normalizedUrl;
        _initialUrl = normalizedUrl;
      }

      if (!kIsWeb && isDatabaseEmpty) {
        final artikelNummer =
            int.tryParse(artikelNummerController.text.trim()) ?? 1000;
        await prefs.setInt(_artikelStartNummerPrefsKey, artikelNummer);
      }

      _initialArtikelNummer = artikelNummerController.text.trim();
      hasUnsavedChanges = false;
      notifyListeners();

      return SaveSettingsResult.success;
    } catch (e, st) {
      AppLogService.logger.e(
        'Speichern fehlgeschlagen',
        error: e,
        stackTrace: st,
      );
      return SaveSettingsResult.error;
    }
  }

  Future<void> setAppLockEnabled(bool value) async {
    if (kIsWeb) return;
    appLockEnabled = value;
    notifyListeners();
    await _appLockService.setEnabled(value);
  }

  Future<void> setAppLockBiometricsEnabled(bool value) async {
    if (kIsWeb) return;
    appLockBiometricsEnabled = value;
    notifyListeners();
    await _appLockService.setBiometricsEnabled(value);
  }

  Future<void> setAppLockTimeoutMinutes(int minutes) async {
    if (kIsWeb) return;
    appLockTimeoutMinutes = minutes.clamp(1, 30);
    notifyListeners();
    await _appLockService.setTimeoutSeconds(appLockTimeoutMinutes * 60);
  }

  void setAppLockTimeoutPreview(int minutes) {
    appLockTimeoutMinutes = minutes.clamp(1, 30);
    notifyListeners();
  }

  @override
  void dispose() {
    pocketBaseUrlController.removeListener(checkForUnsavedChanges);
    artikelNummerController.removeListener(checkForUnsavedChanges);
    artikelNummerController.dispose();
    pocketBaseUrlController.dispose();
    super.dispose();
  }
}