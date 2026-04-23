// lib/services/app_lock_service.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef SharedPreferencesProvider = Future<SharedPreferences> Function();
typedef NowProvider = DateTime Function();

class AppLockService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  static AppLockService? _instance;

  factory AppLockService() {
    _instance ??= AppLockService._internal();
    return _instance!;
  }

  AppLockService._internal({
    SharedPreferencesProvider? prefsProvider,
    NowProvider? nowProvider,
  })  : _prefsProvider = prefsProvider ?? SharedPreferences.getInstance,
        _now = nowProvider ?? DateTime.now;

  @visibleForTesting
  factory AppLockService.testable({
    SharedPreferencesProvider? prefsProvider,
    NowProvider? nowProvider,
  }) {
    return AppLockService._internal(
      prefsProvider: prefsProvider,
      nowProvider: nowProvider,
    );
  }

  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  // ── Konfiguration ─────────────────────────────────────────────────────────
  static const String prefKeyEnabled = 'app_lock_enabled';
  static const String prefKeyTimeout = 'app_lock_timeout_seconds';
  static const String prefKeyBiometrics = 'app_lock_biometrics_enabled';
  static const int defaultTimeoutSeconds = 300; // 5 Minuten

  // ── Abhängigkeiten ────────────────────────────────────────────────────────
  final SharedPreferencesProvider _prefsProvider;
  final NowProvider _now;

  // ── State ─────────────────────────────────────────────────────────────────
  DateTime? _pausedAt;
  bool _enabled = false;
  int _timeoutSeconds = defaultTimeoutSeconds;
  bool _biometricsEnabled = true;
  bool _initialized = false;

  // ── Getter ────────────────────────────────────────────────────────────────
  bool get isEnabled => _enabled;
  int get timeoutSeconds => _timeoutSeconds;
  bool get isBiometricsEnabled => _biometricsEnabled;

  // ── Initialisierung (aus main.dart aufrufen) ──────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    final prefs = await _prefsProvider();
    _enabled = prefs.getBool(prefKeyEnabled) ?? false;
    _timeoutSeconds = prefs.getInt(prefKeyTimeout) ?? defaultTimeoutSeconds;
    _biometricsEnabled = prefs.getBool(prefKeyBiometrics) ?? true;
    _initialized = true;
  }

  // ── Einstellungen ändern ──────────────────────────────────────────────────
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await _prefsProvider();
    await prefs.setBool(prefKeyEnabled, value);
  }

  Future<void> setTimeoutSeconds(int seconds) async {
    _timeoutSeconds = seconds;
    final prefs = await _prefsProvider();
    await prefs.setInt(prefKeyTimeout, seconds);
  }

  Future<void> setBiometricsEnabled(bool value) async {
    _biometricsEnabled = value;
    final prefs = await _prefsProvider();
    await prefs.setBool(prefKeyBiometrics, value);
  }

  // ── Lifecycle-Hooks ───────────────────────────────────────────────────────

  /// Wird aufgerufen wenn die App in den Hintergrund geht.
  void onAppPaused() {
    _pausedAt = _now();
  }

  /// Wird aufgerufen wenn die App wieder in den Vordergrund kommt.
  /// Gibt `true` zurück wenn die App gesperrt werden soll.
  bool onAppResumed() {
    if (!_enabled) return false;
    if (_pausedAt == null) return false;

    final elapsed = _now().difference(_pausedAt!);
    _pausedAt = null;

    return elapsed.inSeconds >= _timeoutSeconds;
  }
}