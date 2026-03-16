// lib/services/pocketbase_service.dart
//
// Zentraler PocketBase-Service.
//
// URL-Priorität (kombiniert AppConfig + SharedPreferences):
// 1. Gespeicherte URL aus Einstellungen (SharedPreferences) — Laufzeit
// 2. --dart-define=POCKETBASE_URL=...                       — Build-Zeit
// 3. Plattform-Fallback aus AppConfig                       — Compile-Zeit

import 'dart:async';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../config/app_config.dart';

class PocketBaseService {
  static const String _prefsKey = 'pocketbase_url';

  static final _logger = Logger();

  // Singleton
  static PocketBaseService? _instance;
  factory PocketBaseService() => _instance ??= PocketBaseService._();
  PocketBaseService._();

  PocketBase? _client;
  String _currentUrl = AppConfig.pocketBaseUrl;

  // FIX Bug 1: Completer als Init-Lock verhindert Race Condition bei
  // parallelen initialize()-Aufrufen (z.B. mehrere Widgets beim App-Start).
  Completer<void>? _initCompleter;

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

  /// Aktuelle PocketBase-URL.
  String get url => _currentUrl;

  /// Prüft ob der Service initialisiert ist.
  bool get isInitialized => _client != null;

  /// Initialisiert den Service.
  ///
  /// Lädt die gespeicherte URL aus SharedPreferences.
  /// Fällt auf [AppConfig.pocketBaseUrl] zurück wenn keine gespeicherte
  /// URL vorhanden ist.
  ///
  /// Mehrfache parallele Aufrufe sind sicher — nur eine Initialisierung
  /// wird durchgeführt.
  Future<void> initialize() async {
    // Bereits vollständig initialisiert
    if (_client != null) return;

    // FIX Bug 1: Läuft bereits — auf denselben Completer warten
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_prefsKey);

      if (savedUrl != null && savedUrl.isNotEmpty) {
        _currentUrl = savedUrl;
        _logger.i('🌐 PocketBase URL aus Einstellungen: $_currentUrl');
      } else {
        _currentUrl = AppConfig.pocketBaseUrl;
        _logger.i('🌐 PocketBase URL (AppConfig): $_currentUrl');
      }

      // Warnung wenn Placeholder noch aktiv
      if (AppConfig.hasPlaceholderUrl) {
        _logger.w(
          '⚠️ PocketBase URL enthält noch einen Placeholder! '
          'Bitte in app_config.dart oder per --dart-define anpassen.',
        );
      }

      _client = PocketBase(_currentUrl);
      _logger.i('✅ PocketBase Client initialisiert: $_currentUrl');
      _initCompleter!.complete();
    } catch (e, stack) {
      // Fallback auf AppConfig-Default
      _currentUrl = AppConfig.pocketBaseUrl;
      _client = PocketBase(_currentUrl);
      _logger.e(
        '❌ Fehler bei Initialisierung, nutze AppConfig-Default: $e',
        error: e,
        stackTrace: stack,
      );
      // Completer abschließen — Service ist mit Fallback-URL nutzbar
      _initCompleter!.complete();
    }
  }

  /// Ändert die PocketBase-URL und erstellt einen neuen Client.
  /// Speichert die URL persistent in SharedPreferences.
  ///
  /// Führt vor dem Client-Ersatz einen Health-Check durch.
  /// Ist die neue URL nicht erreichbar, bleibt der bestehende
  /// Client aktiv und die URL wird nicht gespeichert.
  /// Gibt [true] zurück wenn die URL erfolgreich gewechselt wurde,
  /// [false] wenn Validierung oder Health-Check fehlschlagen.
  Future<bool> updateUrl(String newUrl) async {
    final trimmed = newUrl.trim();
    final uri = Uri.tryParse(trimmed);

    // FIX Bug 2: Nur http/https erlaubt — andere Schemas (ftp, ws, mailto)
    // sind für PocketBase nicht gültig.
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      _logger.w(
        '⚠️ PocketBase URL ungültig oder Schema nicht erlaubt '
        '(nur http/https): $trimmed',
      );
      return false;
    }

    // URL normalisieren: trailing slash entfernen
    final normalized = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;

    // FIX: Health-Check vor Client-Ersatz —
    // Kandidaten-Client temporär erstellen und prüfen ob die neue URL
    // erreichbar ist. Schlägt der Check fehl, bleibt der aktive
    // Client unverändert und die URL wird nicht gespeichert.
    // → Verhindert dass ein funktionierender Client durch eine
    //   nicht erreichbare URL überschrieben wird.
    final candidateClient = PocketBase(normalized);
    try {
      await candidateClient.health.check();
      _logger.d('✅ Health-Check für neue URL OK: $normalized');
    } catch (e, stack) {
      _logger.w(
        '⚠️ Health-Check für neue URL fehlgeschlagen — '
        'bestehender Client bleibt aktiv: $normalized',
        error: e,
        stackTrace: stack,
      );
      return false;
    }

    // Health-Check bestanden → Client und URL ersetzen
    _currentUrl = normalized;
    _client = candidateClient;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, normalized);
      _logger.i('✅ PocketBase URL aktualisiert: $normalized');
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Speichern der URL: $e',
        error: e,
        stackTrace: stack,
      );
    }

    return true;
  }

  /// Prüft ob PocketBase erreichbar ist.
  /// Gibt `true` zurück wenn der Health-Endpoint antwortet.
  Future<bool> checkHealth() async {
    final activeClient = _client;
    if (activeClient == null) return false;

    try {
      await activeClient.health.check();
      _logger.d('✅ PocketBase Health-Check OK: $_currentUrl');
      return true;
    } catch (e, stack) {
      _logger.w(
        '⚠️ PocketBase Health-Check fehlgeschlagen: $e',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Setzt die URL auf den AppConfig-Default zurück und löscht den
  /// gespeicherten Wert aus SharedPreferences.
  ///
  /// Beim nächsten Start greift wieder der aktuelle Build-Default
  /// aus AppConfig (z.B. nach --dart-define-Änderung).
  Future<void> resetToDefault() async {
    _currentUrl = AppConfig.pocketBaseUrl;
    _client = PocketBase(_currentUrl);

    try {
      final prefs = await SharedPreferences.getInstance();
      // Explizites Löschen statt Speichern des Defaults —
      // so greift beim nächsten Start immer der aktuelle AppConfig-Wert.
      await prefs.remove(_prefsKey);
      _logger.i(
        '✅ PocketBase URL auf AppConfig-Default zurückgesetzt: '
        '$_currentUrl',
      );
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Zurücksetzen der URL: $e',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Gibt die Default-URL aus AppConfig zurück.
  static String get defaultUrl => AppConfig.pocketBaseUrl;

  // FIX Problem 3: Testing-Override — ermöglicht Mocking in Unit-Tests.
  // Nur in Tests aufrufen, nie in Produktionscode.
  // ignore: use_setters_to_change_properties
  static void overrideForTesting(PocketBase mock) {
    _instance ??= PocketBaseService._();
    _instance!._client = mock;
  }

  /// Setzt den Singleton vollständig zurück.
  ///
  /// ⚠️ Nur in Unit-Tests verwenden — niemals in Produktionscode.
  ///
  /// In Tests nach jedem Test-Case aufrufen (z.B. in tearDown()) um
  /// sicherzustellen dass kein Zustand zwischen Tests überläuft.
  /// In der laufenden App hat dispose() keinen sinnvollen Anwendungsfall:
  /// Flutter-Apps haben keinen App-Neustart-Lifecycle der dispose()
  /// triggern würde — ein versehentlicher Aufruf würde den Singleton
  /// zerstören und alle nachfolgenden client-Zugriffe mit StateError
  /// crashen.
  static void dispose() {
    _instance?._client = null;
    _instance?._initCompleter = null;
    _instance?._currentUrl = AppConfig.pocketBaseUrl;
    _instance = null;
  }
}