// lib/services/pocketbase_service.dart
//
// Zentraler PocketBase-Service.
//
// URL-Priorität (kombiniert AppConfig + SharedPreferences):
// 1. Gespeicherte URL aus Einstellungen (SharedPreferences) — Laufzeit
// 2. Runtime-Config / --dart-define=POCKETBASE_URL=...      — Build-Zeit
// 3. Web-Modus: Relativer Pfad /api als Fallback
// 4. Keine URL → needsSetup = true → Setup-Screen
//
// Die App crasht nie bei fehlender URL. Stattdessen wird der
// Setup-Screen angezeigt, bis eine gültige URL konfiguriert ist.

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../config/app_config.dart';

class PocketBaseService {

  static const String _prefsKey = 'pocketbase_url';

  static final Logger _logger = Logger();

  // Singleton
  static PocketBaseService? _instance;
  factory PocketBaseService() => _instance ??= PocketBaseService._();
  PocketBaseService._();

  /// Nur für Tests — ermöglicht Subclassing für Fakes.
  /// Umgeht den Singleton-Factory-Konstruktor.
  @visibleForTesting
  PocketBaseService.testable();

  PocketBase? _client;
  String _currentUrl = '';

  // FIX: Separates Flag — der Service kann initialisiert sein,
  // auch wenn kein Client existiert (weil keine URL konfiguriert ist).
  bool _initialized = false;

  // FIX Bug 1: Completer als Init-Lock verhindert Race Condition bei
  // parallelen initialize()-Aufrufen.
  Completer<void>? _initCompleter;

  /// Der aktive PocketBase-Client.
  /// Muss vorher mit [initialize] initialisiert werden.
  /// Wirft [StateError] wenn keine URL konfiguriert ist.
  PocketBase get client {
    if (_client == null) {
      throw StateError(
        'PocketBaseService: Kein Client verfügbar.\n'
        'Entweder wurde initialize() noch nicht aufgerufen, '
        'oder es ist keine Server-URL konfiguriert.\n'
        'Prüfe needsSetup bevor du auf den Client zugreifst.',
      );
    }
    return _client!;
  }

  /// Aktuelle PocketBase-URL (kann leer sein wenn nicht konfiguriert).
  String get url => _currentUrl;

  /// Prüft ob der Service initialisiert ist (unabhängig davon ob eine URL
  /// konfiguriert ist).
  bool get isInitialized => _initialized;

  /// Prüft ob ein funktionsfähiger Client vorhanden ist.
  bool get hasClient => _client != null;

  /// Gibt `true` zurück wenn keine brauchbare URL konfiguriert ist
  /// und der Setup-Screen angezeigt werden muss.
  ///
  /// Wird nach [initialize] ausgewertet, um zu entscheiden ob die App
  /// den normalen Flow oder den Setup-Screen zeigt.
  bool get needsSetup => _initialized && _client == null;

  /// Initialisiert den Service.
  ///
  /// Lädt die gespeicherte URL aus SharedPreferences.
  /// Fällt auf [AppConfig.pocketBaseUrl] zurück wenn keine gespeicherte
  /// URL vorhanden ist.
  ///
  /// Wenn keine URL aus irgendeiner Quelle verfügbar ist, wird kein
  /// Client erstellt. Die App crasht nicht — stattdessen wird
  /// [needsSetup] = true und der Setup-Screen angezeigt.
  ///
  /// Mehrfache parallele Aufrufe sind sicher — nur eine Initialisierung
  /// wird durchgeführt.
  Future<void> initialize() async {
    // Bereits vollständig initialisiert
    if (_initialized) return;

    // FIX Bug 1: Läuft bereits — auf denselben Completer warten
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_prefsKey);

      String resolvedUrl = '';

      // Priorität 1: Gespeicherte URL aus SharedPreferences
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        resolvedUrl = savedUrl.trim();
        _logger.i('🌐 PocketBase URL aus Einstellungen: $resolvedUrl');
      }
      // Priorität 2: AppConfig (Runtime-Config / dart-define)
      else if (AppConfig.pocketBaseUrl.isNotEmpty) {
        resolvedUrl = AppConfig.pocketBaseUrl;
        _logger.i('🌐 PocketBase URL aus AppConfig: $resolvedUrl');

        // Warnung wenn Placeholder noch aktiv
        if (AppConfig.hasPlaceholderUrl) {
          _logger.w(
            '⚠️ PocketBase URL enthält einen Placeholder! '
            'Bitte über den Setup-Screen oder --dart-define konfigurieren.',
          );
          // Placeholder-URL nicht als gültig behandeln
          resolvedUrl = '';
        }
      }
      // Priorität 3 (Web): Relativer Pfad nur wenn Runtime-Config existiert
      // (d.h. die App läuft im Docker-Container hinter einem Proxy).
      // Bei flutter run -d chrome gibt es keine Runtime-Config →
      // Setup-Screen wird angezeigt.
      else if (kIsWeb && AppConfig.hasRuntimeConfig) {
        resolvedUrl = AppConfig.pocketBaseUrl.isNotEmpty
            ? AppConfig.pocketBaseUrl
            : '/api';
        _logger.i(
          '🌐 Web-Modus (Docker): Verwende URL: $resolvedUrl',
        );
      }

      // URL prüfen und Client erstellen
      if (resolvedUrl.isNotEmpty) {
        if (_isValidUrl(resolvedUrl) || (kIsWeb && resolvedUrl == '/api')) {
          _currentUrl = resolvedUrl == '/api'
              ? resolvedUrl
              : _normalizeUrl(resolvedUrl);
          _client = PocketBase(_currentUrl);
          _logger.i('✅ PocketBase Client initialisiert: $_currentUrl');
        } else {
          _logger.w(
            '⚠️ URL syntaktisch ungültig, kein Client erstellt: '
            '$resolvedUrl',
          );
        }
      }

      _initialized = true;
      _initCompleter!.complete();
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler bei Initialisierung: $e',
        error: e,
        stackTrace: stack,
      );
      // Service als initialisiert markieren, auch bei Fehler.
      // Client bleibt null → needsSetup = true → Setup-Screen.
      _initialized = true;
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

    if (!_isValidUrl(trimmed)) {
      _logger.w(
        '⚠️ PocketBase URL ungültig oder Schema nicht erlaubt '
        '(nur http/https): $trimmed',
      );
      return false;
    }

    final normalized = _normalizeUrl(trimmed);

    // Health-Check vor Client-Ersatz
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
  /// Wenn kein AppConfig-Default vorhanden ist (leerer String),
  /// wird der Client entfernt und [needsSetup] wird true.
  Future<void> resetToDefault() async {
    final defaultUrlValue = AppConfig.pocketBaseUrl;

    if (defaultUrlValue.isNotEmpty &&
        !AppConfig.hasPlaceholderUrl &&
        _isValidUrl(defaultUrlValue)) {
      _currentUrl = _normalizeUrl(defaultUrlValue);
      _client = PocketBase(_currentUrl);
      _logger.i(
        '✅ PocketBase URL auf AppConfig-Default zurückgesetzt: '
        '$_currentUrl',
      );
    } else {
      // Kein brauchbarer Default → Client entfernen
      _currentUrl = '';
      _client = null;
      _logger.i(
        '🔧 Kein gültiger AppConfig-Default vorhanden. '
        'Client entfernt — Setup-Screen wird benötigt.',
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Zurücksetzen der URL: $e',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Gibt die Default-URL aus AppConfig zurück.
  /// Kann leer sein wenn kein Default konfiguriert ist.
  static String get defaultUrl => AppConfig.pocketBaseUrl;

  // ---------------------------------------------------------------------------
  // URL-Hilfsmethoden
  // ---------------------------------------------------------------------------

  /// Prüft ob eine URL syntaktisch gültig ist (http/https, hat Authority).
  static bool _isValidUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    if (!uri.hasAuthority) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    if (uri.host.isEmpty) return false;
    return true;
  }

  /// Entfernt trailing Slashes von einer URL.
  static String _normalizeUrl(String url) {
    var normalized = url.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  // ---------------------------------------------------------------------------
  // Authentication
  // ---------------------------------------------------------------------------

  /// Gibt zurück, ob aktuell ein Benutzer eingeloggt ist.
  bool get isAuthenticated {
    final c = _client;
    if (c == null) return false;
    return c.authStore.isValid;
  }

  /// Gibt die ID des aktuell eingeloggten Benutzers zurück, oder null.
  String? get currentUserId {
    final c = _client;
    if (c == null) return null;
    if (!c.authStore.isValid) return null;
    return c.authStore.record?.id;
  }

  /// Gibt die E-Mail des aktuell eingeloggten Benutzers zurück, oder null.
  String? get currentUserEmail {
    final c = _client;
    if (c == null) return null;
    if (!c.authStore.isValid) return null;
    return c.authStore.record?.getStringValue('email');
  }

  /// Loggt einen Benutzer mit E-Mail und Passwort ein.
  Future<bool> login(String email, String password) async {
    final c = _client;
    if (c == null) {
      _logger.w('⚠️ PocketBaseService.login(): Client nicht initialisiert.');
      return false;
    }
    try {
      await c.collection('users').authWithPassword(email, password);
      _logger.i('✅ Login erfolgreich: $email');
      return true;
    } catch (e, stack) {
      _logger.e(
        '❌ Login fehlgeschlagen für $email',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Loggt den aktuellen Benutzer aus.
  void logout() {
    _client?.authStore.clear();
    _logger.i('✅ Logout durchgeführt.');
  }

  // ---------------------------------------------------------------------------
  // Token-Refresh (M-009)
  // ---------------------------------------------------------------------------

  /// Versucht den gespeicherten Auth-Token zu erneuern.
  ///
  /// Sollte beim App-Start aufgerufen werden, wenn [isAuthenticated]
  /// true ist, um sicherzustellen dass der Token noch gültig ist.
  /// PocketBase-Tokens laufen nach einer konfigurierbaren Zeit ab.
  ///
  /// Gibt `true` zurück wenn der User weiterhin eingeloggt ist.
  /// Gibt `false` zurück und räumt den authStore auf, wenn der
  /// Token abgelaufen oder ungültig ist.
  Future<bool> refreshAuthToken() async {
    final c = _client;
    if (c == null) {
      _logger.w(
        '⚠️ PocketBaseService.refreshAuthToken(): '
        'Client nicht initialisiert.',
      );
      return false;
    }

    if (!c.authStore.isValid) {
      _logger.d('ℹ️ Kein gültiger Token zum Erneuern vorhanden.');
      return false;
    }

    try {
      await c.collection('users').authRefresh();
      _logger.i('✅ Auth-Token erfolgreich erneuert.');
      return c.authStore.isValid;
    } catch (e, stack) {
      _logger.w(
        '⚠️ Token-Refresh fehlgeschlagen — User wird ausgeloggt.',
        error: e,
        stackTrace: stack,
      );
      c.authStore.clear();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Passwort-Reset (M-009)
  // ---------------------------------------------------------------------------

  /// Sendet eine Passwort-Reset-E-Mail über PocketBase.
  ///
  /// PocketBase sendet eine E-Mail mit einem Reset-Link an die
  /// angegebene Adresse, sofern ein User mit dieser E-Mail existiert.
  /// Aus Sicherheitsgründen gibt PocketBase keinen Fehler zurück,
  /// wenn die E-Mail nicht existiert.
  ///
  /// Wirft eine Exception wenn der Client nicht initialisiert ist
  /// oder ein Netzwerkfehler auftritt.
  Future<void> requestPasswordReset(String email) async {
    final c = _client;
    if (c == null) {
      throw StateError(
        'PocketBaseService.requestPasswordReset(): '
        'Client nicht initialisiert.',
      );
    }

    try {
      await c.collection('users').requestPasswordReset(email);
      _logger.i('✅ Passwort-Reset angefordert für: $email');
    } catch (e, stack) {
      _logger.e(
        '❌ Passwort-Reset fehlgeschlagen für: $email',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Testing
  // ---------------------------------------------------------------------------

  // ignore: use_setters_to_change_properties
  static void overrideForTesting(PocketBase mock) {
    _instance ??= PocketBaseService._();
    _instance!._client = mock;
    _instance!._initialized = true;
  }

  static void dispose() {
    _instance?._client = null;
    _instance?._initCompleter = null;
    _instance?._currentUrl = '';
    _instance?._initialized = false;
    _instance = null;
  }
}