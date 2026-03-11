// lib/services/pocketbase_service.dart

import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

/// Zentraler PocketBase-Service.
/// 
/// URL-Priorität:
/// 1. Gespeicherte URL aus Einstellungen (SharedPreferences)
/// 2. Build-Argument (--dart-define=PB_URL=...)
/// 3. Fallback: http://127.0.0.1:8090
class PocketBaseService {
  // Build-Zeit Default (kann per --dart-define überschrieben werden)
  static const String _defaultUrl = String.fromEnvironment(
    'PB_URL',
    defaultValue: 'http://127.0.0.1:8090',
  );

  static const String _prefsKey = 'pocketbase_url';

  // Singleton
  static PocketBaseService? _instance;
  factory PocketBaseService() => _instance ??= PocketBaseService._();
  PocketBaseService._();

  PocketBase? _client;
  String _currentUrl = _defaultUrl;

  /// Der aktive PocketBase-Client.
  /// Muss vorher mit [initialize] initialisiert werden.
  PocketBase get client {
    if (_client == null) {
      throw StateError(
        'PocketBaseService nicht initialisiert. '
        'Rufe zuerst PocketBaseService().initialize() auf.',
      );
    }
    return _client!;
  }

  /// Aktuelle PocketBase-URL
  String get url => _currentUrl;

  /// Prüft ob der Service initialisiert ist
  bool get isInitialized => _client != null;

  /// Initialisiert den Service.
  /// Lädt die gespeicherte URL aus SharedPreferences oder nutzt den Default.
  Future<void> initialize() async {
    if (_client != null) return; // Bereits initialisiert

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_prefsKey);

      if (savedUrl != null && savedUrl.isNotEmpty) {
        _currentUrl = savedUrl;
        developer.log('PocketBase URL aus Einstellungen: $_currentUrl', name: 'pb');
      } else {
        _currentUrl = _defaultUrl;
        developer.log('PocketBase URL (Default): $_currentUrl', name: 'pb');
      }
    } catch (e) {
      _currentUrl = _defaultUrl;
      developer.log('SharedPreferences Fehler, nutze Default: $e', name: 'pb');
    }

    _client = PocketBase(_currentUrl);
    developer.log('PocketBase Client initialisiert: $_currentUrl', name: 'pb');
  }

  /// Ändert die PocketBase-URL und erstellt einen neuen Client.
  /// Speichert die URL persistent in SharedPreferences.
  Future<void> updateUrl(String newUrl) async {
    // URL normalisieren (trailing slash entfernen)
    final normalized = newUrl.endsWith('/')
        ? newUrl.substring(0, newUrl.length - 1)
        : newUrl;

    _currentUrl = normalized;
    _client = PocketBase(normalized);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, normalized);
      developer.log('PocketBase URL aktualisiert: $normalized', name: 'pb');
    } catch (e) {
      developer.log('Fehler beim Speichern der URL: $e', name: 'pb');
    }
  }

  /// Prüft ob PocketBase erreichbar ist.
  /// Gibt `true` zurück wenn der Health-Endpoint antwortet.
  Future<bool> checkHealth() async {
    if (_client == null) return false;
    try {
      await _client!.health.check();
      developer.log('PocketBase Health-Check OK', name: 'pb');
      return true;
    } catch (e) {
      developer.log('PocketBase Health-Check fehlgeschlagen: $e', name: 'pb');
      return false;
    }
  }

  /// Setzt die URL auf den Default zurück.
  Future<void> resetToDefault() async {
    await updateUrl(_defaultUrl);
  }

  /// Gibt die Default-URL zurück (aus Build-Argumenten).
  static String get defaultUrl => _defaultUrl;
}
