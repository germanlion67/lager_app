// lib/services/app_lock_service.dart

// ── F-001: App-Lock Service ─────────────────────────────────────────────────
// Verwaltet die App-Sperre nach Inaktivität.
// Singleton – wird über AppLockService() aufgerufen.

import 'package:shared_preferences/shared_preferences.dart';

class AppLockService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  static final AppLockService _instance = AppLockService._internal();
  factory AppLockService() => _instance;
  AppLockService._internal();

  // ── Konfiguration ─────────────────────────────────────────────────────────
  static const String _prefKeyEnabled = 'app_lock_enabled';
  static const String _prefKeyTimeout = 'app_lock_timeout_seconds';
  static const int defaultTimeoutSeconds = 300; // 5 Minuten

  // ── State ─────────────────────────────────────────────────────────────────
  DateTime? _pausedAt;
  bool _enabled = false;
  int _timeoutSeconds = defaultTimeoutSeconds;
  bool _initialized = false;

  // ── Getter ────────────────────────────────────────────────────────────────
  bool get isEnabled => _enabled;
  int get timeoutSeconds => _timeoutSeconds;

  // ── Initialisierung (aus main.dart aufrufen) ──────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKeyEnabled) ?? false;
    _timeoutSeconds = prefs.getInt(_prefKeyTimeout) ?? defaultTimeoutSeconds;
    _initialized = true;
  }

  // ── Einstellungen ändern ──────────────────────────────────────────────────
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyEnabled, value);
  }

  Future<void> setTimeoutSeconds(int seconds) async {
    _timeoutSeconds = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyTimeout, seconds);
  }

  // ── Lifecycle-Hooks ───────────────────────────────────────────────────────

  /// Wird aufgerufen wenn die App in den Hintergrund geht.
  void onAppPaused() {
    _pausedAt = DateTime.now();
  }

  /// Wird aufgerufen wenn die App wieder in den Vordergrund kommt.
  /// Gibt `true` zurück wenn die App gesperrt werden soll.
  bool onAppResumed() {
    if (!_enabled) return false;
    if (_pausedAt == null) return false;

    final elapsed = DateTime.now().difference(_pausedAt!);
    _pausedAt = null;

    return elapsed.inSeconds >= _timeoutSeconds;
  }
}
