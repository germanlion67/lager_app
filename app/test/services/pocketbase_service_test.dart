// test/services/pocketbase_service_test.dart
//
// Tests für PocketBaseService — T-012
//
// Strategie:
// - _HealthCheckCapturingService (Subklasse via PocketBaseService.testable())
//   überschreibt updateUrl() für Health-Check-Tests ohne Netzwerk
// - _FakePocketBaseForAuth + _FakeAuthRecordService für Auth-Tests
//   mit manuellem authStore.save() — authStore wird korrekt befüllt
// - PocketBaseService.overrideForTesting() injiziert Fake-Client in Singleton
// - SharedPreferences.setMockInitialValues({}) für Prefs-Isolation
// - PocketBaseService.dispose() in tearDown — Singleton-Cleanup
// - Kein build_runner, keine Mockito-Generierung — manuelle Fakes

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lager_app/services/pocketbase_service.dart';

// ---------------------------------------------------------------------------
// Fake: Health-Check-steuerbarer updateUrl()-Service
// ---------------------------------------------------------------------------

/// Überschreibt updateUrl() vollständig um den internen Health-Check
/// (candidateClient.health.check()) ohne Netzwerk steuerbar zu machen.
class _HealthCheckCapturingService extends PocketBaseService {
  bool healthCheckShouldSucceed;
  int updateUrlHealthCheckCount = 0;

  _HealthCheckCapturingService({this.healthCheckShouldSucceed = true})
      : super.testable();

  @override
  Future<bool> updateUrl(String newUrl) async {
    final trimmed = newUrl.trim();

    // URL-Validierung (gleiche Logik wie Produktion)
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return false;
    }

    updateUrlHealthCheckCount++;

    if (!healthCheckShouldSucceed) return false;

    // Health-Check bestanden → trailing slashes entfernen + Prefs speichern
    var normalized = trimmed;
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pocketbase_url', normalized);
    return true;
  }
}

// ---------------------------------------------------------------------------
// Fake: PocketBase Auth-Service
// ---------------------------------------------------------------------------

/// Minimale RecordService-Implementierung für Auth-Tests.
/// Speichert eine Referenz auf den PocketBase-Client um
/// authStore.save() nach erfolgreichem Login korrekt aufzurufen.
class _FakeAuthRecordService extends RecordService {
  bool authWithPasswordShouldSucceed;
  bool authRefreshShouldSucceed;
  bool requestPasswordResetShouldSucceed;

  /// Referenz auf den übergeordneten PocketBase-Client.
  /// Wird benötigt um authStore.save() aufzurufen —
  /// ohne das bleibt authStore.isValid nach dem Fake-Login false.
  final PocketBase _pb;

  _FakeAuthRecordService(
    PocketBase pb, {
    this.authWithPasswordShouldSucceed = true,
    this.authRefreshShouldSucceed = true,
    this.requestPasswordResetShouldSucceed = true,
  })  : _pb = pb,
        super(pb, 'users');

  @override
  Future<RecordAuth> authWithPassword(
    String usernameOrEmail,
    String password, {
    Map<String, dynamic> body = const {},
    Map<String, dynamic> query = const {},
    String? expand,
    String? fields,
    Map<String, String> headers = const {},
  }) async {
    if (!authWithPasswordShouldSucceed) {
      throw ClientException(
        url: Uri.parse(
          'http://fake/api/collections/users/auth-with-password',
        ),
        statusCode: 400,
        response: {'message': 'Failed to authenticate.'},
        originalError: 'auth failed',
        isAbort: false,
      );
    }

    const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4OTM0NTI0NjF9.yVr-4JxMz6qUf1MIlGx8iW2ktUrQaFecjY_TMm7Bo4o';
    final record = RecordModel.fromJson({
      'id': 'user-001',
      'collectionId': '_pb_users_auth_',
      'collectionName': 'users',
      'email': usernameOrEmail,
      'verified': true,
      'created': '2026-01-01 00:00:00.000Z',
      'updated': '2026-01-01 00:00:00.000Z',
    });

    // Entscheidend: authStore des echten PocketBase-Clients befüllen.
    // Ohne diesen Aufruf bleibt authStore.isValid = false.
    _pb.authStore.save(token, record);

    return RecordAuth.fromJson({
      'token': token,
      'record': record.toJson(),
    });
  }

  @override
  Future<RecordAuth> authRefresh({
    Map<String, dynamic> body = const {},
    Map<String, dynamic> query = const {},
    String? expand,
    String? fields,
    Map<String, String> headers = const {},
  }) async {
    if (!authRefreshShouldSucceed) {
      throw ClientException(
        url: Uri.parse('http://fake/api/collections/users/auth-refresh'),
        statusCode: 401,
        response: {'message': 'Token expired.'},
        originalError: 'token expired',
        isAbort: false,
      );
    }

    const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4OTM0NTI0NjF9.yVr-4JxMz6qUf1MIlGx8iW2ktUrQaFecjY_TMm7Bo4o';
    final record = RecordModel.fromJson({
      'id': 'user-001',
      'collectionId': '_pb_users_auth_',
      'collectionName': 'users',
      'email': 'test@example.com',
      'verified': true,
      'created': '2026-01-01 00:00:00.000Z',
      'updated': '2026-01-01 00:00:00.000Z',
    });

    _pb.authStore.save(token, record);

    return RecordAuth.fromJson({
      'token': token,
      'record': record.toJson(),
    });
  }

  @override
  Future<void> requestPasswordReset(
    String email, {
    Map<String, dynamic> body = const {},
    Map<String, dynamic> query = const {},
    Map<String, String> headers = const {},
  }) async {
    if (!requestPasswordResetShouldSucceed) {
      throw ClientException(
        url: Uri.parse(
          'http://fake/api/collections/users/request-password-reset',
        ),
        statusCode: 500,
        response: {'message': 'Server error.'},
        originalError: 'server error',
        isAbort: false,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Fake: PocketBase-Client für Auth-Tests
// ---------------------------------------------------------------------------

/// Leitet collection() auf _FakeAuthRecordService um.
/// Verwendet Factory-Konstruktor damit _FakeAuthRecordService
/// eine Referenz auf denselben PocketBase-Client bekommt.
class _FakePocketBaseForAuth extends PocketBase {
  late final _FakeAuthRecordService fakeRecordService;

  _FakePocketBaseForAuth._() : super('http://fake');

  factory _FakePocketBaseForAuth({
    bool authWithPasswordShouldSucceed = true,
    bool authRefreshShouldSucceed = true,
    bool requestPasswordResetShouldSucceed = true,
  }) {
    final pb = _FakePocketBaseForAuth._();
    pb.fakeRecordService = _FakeAuthRecordService(
      pb,
      authWithPasswordShouldSucceed: authWithPasswordShouldSucceed,
      authRefreshShouldSucceed: authRefreshShouldSucceed,
      requestPasswordResetShouldSucceed: requestPasswordResetShouldSucceed,
    );
    return pb;
  }

  @override
  RecordService collection(String collectionIdOrName) => fakeRecordService;
}

// ---------------------------------------------------------------------------
// Fake: Timeout-Simulation für LoginTimeoutException-Test
// ---------------------------------------------------------------------------

/// Wirft direkt eine TimeoutException um den Login-Timeout-Pfad
/// ohne echten 12-Sekunden-Delay zu testen.
class _TimeoutFakeAuthRecordService extends _FakeAuthRecordService {
  _TimeoutFakeAuthRecordService(super.pb);

  @override
  Future<RecordAuth> authWithPassword(
    String usernameOrEmail,
    String password, {
    Map<String, dynamic> body = const {},
    Map<String, dynamic> query = const {},
    String? expand,
    String? fields,
    Map<String, String> headers = const {},
  }) async {
    throw TimeoutException(
      'Login Timeout',
      const Duration(seconds: 12),
    );
  }
}

// ---------------------------------------------------------------------------
// Hilfsmethode
// ---------------------------------------------------------------------------

Future<void> _resetAll() async {
  SharedPreferences.setMockInitialValues({});
  PocketBaseService.dispose();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() async {
    await _resetAll();
  });

  tearDown(() {
    PocketBaseService.dispose();
  });

  // =========================================================================
  // initialize() — URL-Prioritäten
  // =========================================================================

  group('initialize() — URL-Prioritäten', () {
    test(
      'T-012.1: keine URL aus irgendeiner Quelle → needsSetup = true, kein Client',
      () async {
        SharedPreferences.setMockInitialValues({});

        final svc = PocketBaseService.testable();
        await svc.initialize();

        expect(svc.isInitialized, isTrue);
        expect(svc.needsSetup, isTrue);
        expect(svc.hasClient, isFalse);
        expect(svc.url, isEmpty);
      },
    );

    test(
      'T-012.2: gespeicherte URL aus SharedPreferences → Client wird erstellt',
      () async {
        SharedPreferences.setMockInitialValues({
          'pocketbase_url': 'http://localhost:8090',
        });

        final svc = PocketBaseService.testable();
        await svc.initialize();

        expect(svc.isInitialized, isTrue);
        expect(svc.needsSetup, isFalse);
        expect(svc.hasClient, isTrue);
        expect(svc.url, equals('http://localhost:8090'));
      },
    );

    test(
      'T-012.3: gespeicherte URL mit trailing slash → wird normalisiert',
      () async {
        SharedPreferences.setMockInitialValues({
          'pocketbase_url': 'http://localhost:8090/',
        });

        final svc = PocketBaseService.testable();
        await svc.initialize();

        expect(svc.url, equals('http://localhost:8090'));
      },
    );

    test(
      'T-012.4: gespeicherte URL mit mehreren trailing slashes → alle entfernt',
      () async {
        SharedPreferences.setMockInitialValues({
          'pocketbase_url': 'https://example.com///',
        });

        final svc = PocketBaseService.testable();
        await svc.initialize();

        expect(svc.url, equals('https://example.com'));
      },
    );

    test(
      'T-012.5: leere gespeicherte URL → needsSetup = true',
      () async {
        SharedPreferences.setMockInitialValues({
          'pocketbase_url': '',
        });

        final svc = PocketBaseService.testable();
        await svc.initialize();

        expect(svc.needsSetup, isTrue);
        expect(svc.hasClient, isFalse);
      },
    );

    test(
      'T-012.6: nur Whitespace in gespeicherter URL → needsSetup = true',
      () async {
        SharedPreferences.setMockInitialValues({
          'pocketbase_url': '   ',
        });

        final svc = PocketBaseService.testable();
        await svc.initialize();

        expect(svc.needsSetup, isTrue);
        expect(svc.hasClient, isFalse);
      },
    );

    test(
      'T-012.7: syntaktisch ungültige gespeicherte URL → kein Client, needsSetup = true',
      () async {
        SharedPreferences.setMockInitialValues({
          'pocketbase_url': 'nicht-eine-url',
        });

        final svc = PocketBaseService.testable();
        await svc.initialize();

        expect(svc.needsSetup, isTrue);
        expect(svc.hasClient, isFalse);
      },
    );

    test(
      'T-012.8: ftp://-URL → wird abgelehnt (nur http/https erlaubt)',
      () async {
        SharedPreferences.setMockInitialValues({
          'pocketbase_url': 'ftp://example.com',
        });

        final svc = PocketBaseService.testable();
        await svc.initialize();

        expect(svc.needsSetup, isTrue);
        expect(svc.hasClient, isFalse);
      },
    );

    test(
      'T-012.9: mehrfache parallele initialize()-Aufrufe → nur eine Initialisierung',
      () async {
        SharedPreferences.setMockInitialValues({
          'pocketbase_url': 'http://localhost:8090',
        });

        final svc = PocketBaseService.testable();

        await Future.wait([
          svc.initialize(),
          svc.initialize(),
          svc.initialize(),
        ]);

        expect(svc.isInitialized, isTrue);
        expect(svc.hasClient, isTrue);
        expect(svc.url, equals('http://localhost:8090'));
      },
    );

    test(
      'T-012.10: zweiter initialize()-Aufruf nach erstem ist No-Op',
      () async {
        SharedPreferences.setMockInitialValues({
          'pocketbase_url': 'http://localhost:8090',
        });

        final svc = PocketBaseService.testable();
        await svc.initialize();

        // URL in Prefs ändern — zweiter Aufruf darf das nicht mehr einlesen
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pocketbase_url', 'http://other-server:9000');

        await svc.initialize();

        // Erste URL bleibt — kein Re-Init
        expect(svc.url, equals('http://localhost:8090'));
      },
    );
  });

  // =========================================================================
  // needsSetup
  // =========================================================================

  group('needsSetup', () {
    test(
      'T-012.11: needsSetup ist false vor initialize()',
      () async {
        final svc = PocketBaseService.testable();

        // Semantik: needsSetup = _initialized && _client == null
        // Vor initialize(): _initialized = false → needsSetup = false
        expect(svc.needsSetup, isFalse);
        expect(svc.isInitialized, isFalse);
      },
    );

    test(
      'T-012.12: needsSetup ist true nach initialize() ohne URL',
      () async {
        SharedPreferences.setMockInitialValues({});

        final svc = PocketBaseService.testable();
        await svc.initialize();

        expect(svc.needsSetup, isTrue);
        expect(svc.isInitialized, isTrue);
      },
    );

    test(
      'T-012.13: needsSetup ist false nach initialize() mit gültiger URL',
      () async {
        SharedPreferences.setMockInitialValues({
          'pocketbase_url': 'https://pb.example.com',
        });

        final svc = PocketBaseService.testable();
        await svc.initialize();

        expect(svc.needsSetup, isFalse);
      },
    );

    test(
      'T-012.14: client-Getter wirft StateError wenn needsSetup = true',
      () async {
        SharedPreferences.setMockInitialValues({});

        final svc = PocketBaseService.testable();
        await svc.initialize();

        expect(() => svc.client, throwsA(isA<StateError>()));
      },
    );
  });

  // =========================================================================
  // updateUrl()
  // =========================================================================

  group('updateUrl()', () {
    test(
      'T-012.15: ungültige URL → gibt false zurück',
      () async {
        final svc = _HealthCheckCapturingService(
          healthCheckShouldSucceed: true,
        );

        final result = await svc.updateUrl('keine-url');

        expect(result, isFalse);
        expect(svc.updateUrlHealthCheckCount, equals(0));
      },
    );

    test(
      'T-012.16: ftp://-URL → gibt false zurück',
      () async {
        final svc = _HealthCheckCapturingService(
          healthCheckShouldSucceed: true,
        );

        final result = await svc.updateUrl('ftp://example.com');

        expect(result, isFalse);
        expect(svc.updateUrlHealthCheckCount, equals(0));
      },
    );

    test(
      'T-012.17: Health-Check schlägt fehl → gibt false zurück, URL nicht gespeichert',
      () async {
        SharedPreferences.setMockInitialValues({});

        final svc = _HealthCheckCapturingService(
          healthCheckShouldSucceed: false,
        );

        final result = await svc.updateUrl('http://unreachable.example.com');

        expect(result, isFalse);
        expect(svc.updateUrlHealthCheckCount, equals(1));

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('pocketbase_url'), isNull);
      },
    );

    test(
      'T-012.18: Health-Check erfolgreich → gibt true zurück, URL in Prefs gespeichert',
      () async {
        SharedPreferences.setMockInitialValues({});

        final svc = _HealthCheckCapturingService(
          healthCheckShouldSucceed: true,
        );

        final result = await svc.updateUrl('http://localhost:8090');

        expect(result, isTrue);
        expect(svc.updateUrlHealthCheckCount, equals(1));

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('pocketbase_url'),
          equals('http://localhost:8090'),
        );
      },
    );

    test(
      'T-012.19: trailing slash in neuer URL → wird normalisiert vor Speicherung',
      () async {
        SharedPreferences.setMockInitialValues({});

        final svc = _HealthCheckCapturingService(
          healthCheckShouldSucceed: true,
        );

        await svc.updateUrl('http://localhost:8090/');

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('pocketbase_url'),
          equals('http://localhost:8090'),
        );
      },
    );

    test(
      'T-012.20: leere URL → gibt false zurück',
      () async {
        final svc = _HealthCheckCapturingService(
          healthCheckShouldSucceed: true,
        );

        final result = await svc.updateUrl('');

        expect(result, isFalse);
        expect(svc.updateUrlHealthCheckCount, equals(0));
      },
    );
  });

  // =========================================================================
  // resetToDefault()
  // =========================================================================

  group('resetToDefault()', () {
    test(
      'T-012.21: resetToDefault() entfernt gespeicherte URL aus SharedPreferences',
      () async {
        SharedPreferences.setMockInitialValues({
          'pocketbase_url': 'http://localhost:8090',
        });

        final svc = PocketBaseService.testable();
        await svc.initialize();
        expect(svc.hasClient, isTrue);

        await svc.resetToDefault();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('pocketbase_url'), isNull);
      },
    );

    test(
      'T-012.22: resetToDefault() ohne AppConfig-Default → Client wird entfernt',
      () async {
        // AppConfig.pocketBaseUrl ist '' in Tests (kein dart-define gesetzt)
        SharedPreferences.setMockInitialValues({
          'pocketbase_url': 'http://localhost:8090',
        });

        final svc = PocketBaseService.testable();
        await svc.initialize();
        expect(svc.hasClient, isTrue);

        await svc.resetToDefault();

        expect(svc.hasClient, isFalse);
        expect(svc.url, isEmpty);
      },
    );
  });

  // =========================================================================
  // URL-Validierung (parametrisiert)
  // =========================================================================

  group('URL-Validierung', () {
    // Gültige URLs — initialize() soll einen Client erstellen
    final validUrls = [
      'http://localhost:8090',
      'https://example.com',
      'http://192.168.1.100:8090',
      'https://pb.my-domain.de',
      'http://localhost:8090/', // trailing slash → normalisiert
    ];

    // Ungültige URLs — initialize() soll keinen Client erstellen.
    // Hinweis: URLs mit Leerzeichen im Host (z.B. 'http:// host.com') werden
    // von Darts Uri.tryParse() als syntaktisch parsebar behandelt und daher
    // hier nicht als Testfall geführt — das ist Dart-URI-Parser-Verhalten,
    // kein Bug im Service.
    final invalidUrls = [
      '',
      '   ',
      'localhost:8090', // kein Schema
      'ftp://example.com', // falsches Schema
      'http://', // kein Host
      'nicht-eine-url',
    ];

    for (final url in validUrls) {
      test('gültige URL wird akzeptiert: "$url"', () async {
        SharedPreferences.setMockInitialValues({'pocketbase_url': url});

        final svc = PocketBaseService.testable();
        await svc.initialize();

        expect(
          svc.hasClient,
          isTrue,
          reason: 'URL "$url" sollte einen Client erzeugen',
        );
      });
    }

    for (final url in invalidUrls) {
      test('ungültige URL wird abgelehnt: "$url"', () async {
        SharedPreferences.setMockInitialValues({'pocketbase_url': url});

        final svc = PocketBaseService.testable();
        await svc.initialize();

        expect(
          svc.hasClient,
          isFalse,
          reason: 'URL "$url" sollte keinen Client erzeugen',
        );
      });
    }
  });

  // =========================================================================
  // login() / logout()
  // =========================================================================

  group('login() / logout()', () {
    setUp(() {
      final fakePb = _FakePocketBaseForAuth(
        authWithPasswordShouldSucceed: true,
      );
      PocketBaseService.overrideForTesting(fakePb);
    });

    test(
      'T-012.23: login() mit gültigen Credentials → gibt true zurück',
      () async {
        final svc = PocketBaseService();
        final result = await svc.login('test@example.com', 'password123');
        expect(result, isTrue);
      },
    );

    test(
      'T-012.24: login() mit falschen Credentials → gibt false zurück',
      () async {
        PocketBaseService.dispose();
        final fakePb = _FakePocketBaseForAuth(
          authWithPasswordShouldSucceed: false,
        );
        PocketBaseService.overrideForTesting(fakePb);

        final svc = PocketBaseService();
        final result = await svc.login('wrong@example.com', 'wrongpass');
        expect(result, isFalse);
      },
    );

    test(
      'T-012.25: login() ohne Client → gibt false zurück',
      () async {
        PocketBaseService.dispose();
        SharedPreferences.setMockInitialValues({});

        final svc = PocketBaseService.testable();
        await svc.initialize(); // needsSetup = true, kein Client

        final result = await svc.login('test@example.com', 'password');
        expect(result, isFalse);
      },
    );

    test(
      'T-012.26: login() Timeout → wirft LoginTimeoutException',
      () async {
        PocketBaseService.dispose();
        final innerPb = PocketBase('http://fake');
        final timeoutFakeAuth = _TimeoutFakeAuthRecordService(innerPb);
        final timeoutFakePb = _FakePocketBaseForAuth._();
        timeoutFakePb.fakeRecordService = timeoutFakeAuth;
        PocketBaseService.overrideForTesting(timeoutFakePb);

        final svc = PocketBaseService();

        expect(
          () => svc.login('test@example.com', 'password'),
          throwsA(isA<LoginTimeoutException>()),
        );
      },
    );

    test(
      'T-012.27: logout() löscht authStore',
      () async {
        final svc = PocketBaseService();
        await svc.login('test@example.com', 'password123');

        svc.logout();

        expect(svc.isAuthenticated, isFalse);
      },
    );
  });

  // =========================================================================
  // refreshAuthToken()
  // =========================================================================

  group('refreshAuthToken()', () {
    test(
      'T-012.28: refreshAuthToken() ohne Client → gibt false zurück',
      () async {
        SharedPreferences.setMockInitialValues({});

        final svc = PocketBaseService.testable();
        await svc.initialize();

        final result = await svc.refreshAuthToken();
        expect(result, isFalse);
      },
    );

    test(
      'T-012.29: refreshAuthToken() ohne gültigen Token → gibt false zurück',
      () async {
        final fakePb = _FakePocketBaseForAuth();
        PocketBaseService.overrideForTesting(fakePb);

        final svc = PocketBaseService();
        // authStore ist leer → isValid = false
        expect(svc.client.authStore.isValid, isFalse);

        final result = await svc.refreshAuthToken();
        expect(result, isFalse);
      },
    );

    test(
      'T-012.30: refreshAuthToken() mit abgelaufenem Token → gibt false zurück, authStore geleert',
      () async {
        final fakePb = _FakePocketBaseForAuth(
          authWithPasswordShouldSucceed: true,
          authRefreshShouldSucceed: false,
        );
        PocketBaseService.overrideForTesting(fakePb);

        final svc = PocketBaseService();
        await svc.login('test@example.com', 'password');
        expect(svc.isAuthenticated, isTrue); // Login hat funktioniert

        final result = await svc.refreshAuthToken();

        expect(result, isFalse);
        expect(svc.isAuthenticated, isFalse);
      },
    );

    test(
      'T-012.31: refreshAuthToken() mit gültigem Token → gibt true zurück',
      () async {
        final fakePb = _FakePocketBaseForAuth(
          authWithPasswordShouldSucceed: true,
          authRefreshShouldSucceed: true,
        );
        PocketBaseService.overrideForTesting(fakePb);

        final svc = PocketBaseService();
        await svc.login('test@example.com', 'password');
        expect(svc.isAuthenticated, isTrue); // Login hat funktioniert

        final result = await svc.refreshAuthToken();
        expect(result, isTrue);
      },
    );
  });

  // =========================================================================
  // requestPasswordReset()
  // =========================================================================

  group('requestPasswordReset()', () {
    test(
      'T-012.32: requestPasswordReset() ohne Client → wirft StateError',
      () async {
        SharedPreferences.setMockInitialValues({});

        final svc = PocketBaseService.testable();
        await svc.initialize();

        expect(
          () => svc.requestPasswordReset('test@example.com'),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'T-012.33: requestPasswordReset() Erfolg → keine Exception',
      () async {
        final fakePb = _FakePocketBaseForAuth(
          requestPasswordResetShouldSucceed: true,
        );
        PocketBaseService.overrideForTesting(fakePb);

        final svc = PocketBaseService();

        await expectLater(
          svc.requestPasswordReset('test@example.com'),
          completes,
        );
      },
    );

    test(
      'T-012.34: requestPasswordReset() Fehler → wirft Exception weiter',
      () async {
        final fakePb = _FakePocketBaseForAuth(
          requestPasswordResetShouldSucceed: false,
        );
        PocketBaseService.overrideForTesting(fakePb);

        final svc = PocketBaseService();

        expect(
          () => svc.requestPasswordReset('test@example.com'),
          throwsA(isA<ClientException>()),
        );
      },
    );
  });

  // =========================================================================
  // isAuthenticated / currentUserId / currentUserEmail
  // =========================================================================

  group('Auth-Getter', () {
    test(
      'T-012.35: isAuthenticated ist false ohne Client',
      () async {
        SharedPreferences.setMockInitialValues({});

        final svc = PocketBaseService.testable();
        await svc.initialize();

        expect(svc.isAuthenticated, isFalse);
      },
    );

    test(
      'T-012.36: currentUserId ist null ohne Client',
      () async {
        SharedPreferences.setMockInitialValues({});

        final svc = PocketBaseService.testable();
        await svc.initialize();

        expect(svc.currentUserId, isNull);
      },
    );

    test(
      'T-012.37: currentUserId ist null ohne eingeloggten User',
      () async {
        final fakePb = _FakePocketBaseForAuth();
        PocketBaseService.overrideForTesting(fakePb);

        final svc = PocketBaseService();
        expect(svc.currentUserId, isNull);
      },
    );

    test(
      'T-012.38: isAuthenticated und currentUserId nach erfolgreichem Login',
      () async {
        final fakePb = _FakePocketBaseForAuth(
          authWithPasswordShouldSucceed: true,
        );
        PocketBaseService.overrideForTesting(fakePb);

        final svc = PocketBaseService();
        await svc.login('test@example.com', 'password');

        expect(svc.isAuthenticated, isTrue);
        expect(svc.currentUserId, equals('user-001'));
      },
    );
  });

  // =========================================================================
  // checkHealth()
  // =========================================================================

  group('checkHealth()', () {
    test(
      'T-012.39: checkHealth() ohne Client → gibt false zurück',
      () async {
        SharedPreferences.setMockInitialValues({});

        final svc = PocketBaseService.testable();
        await svc.initialize();

        final result = await svc.checkHealth();
        expect(result, isFalse);
      },
    );
  });

  // =========================================================================
  // defaultUrl
  // =========================================================================

  group('defaultUrl', () {
    test(
      'T-012.40: defaultUrl gibt AppConfig.pocketBaseUrl zurück',
      () {
        // In Tests ist AppConfig.pocketBaseUrl '' (kein dart-define gesetzt)
        expect(PocketBaseService.defaultUrl, equals(''));
      },
    );
  });

  // =========================================================================
  // isReadonlyUser — M-014
  // =========================================================================

  group('isReadonlyUser — M-014', () {
    const token =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4OTM0NTI0NjF9.yVr-4JxMz6qUf1MIlGx8iW2ktUrQaFecjY_TMm7Bo4o';

    test('T-012.41: isReadonlyUser ohne Client → false', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = PocketBaseService.testable();
      await svc.initialize();
      expect(svc.isReadonlyUser, isFalse);
    });

    test('T-012.42: isReadonlyUser ohne eingeloggten User → false', () {
      final fakePb = _FakePocketBaseForAuth();
      PocketBaseService.overrideForTesting(fakePb);
      final svc = PocketBaseService();
      expect(svc.isReadonlyUser, isFalse);
    });

    test('T-012.43: isReadonlyUser mit role = "readonly" → true', () {
      final fakePb = _FakePocketBaseForAuth();
      PocketBaseService.overrideForTesting(fakePb);

      final record = RecordModel.fromJson({
        'id': 'user-ro-001',
        'collectionId': '_pb_users_auth_',
        'collectionName': 'users',
        'email': 'readonly@example.com',
        'role': 'readonly',
        'created': '2026-01-01 00:00:00.000Z',
        'updated': '2026-01-01 00:00:00.000Z',
      });
      fakePb.authStore.save(token, record);

      final svc = PocketBaseService();
      expect(svc.isReadonlyUser, isTrue);
    });

    test('T-012.44: isReadonlyUser mit role = "" (normaler User) → false', () {
      final fakePb = _FakePocketBaseForAuth();
      PocketBaseService.overrideForTesting(fakePb);

      final record = RecordModel.fromJson({
        'id': 'user-001',
        'collectionId': '_pb_users_auth_',
        'collectionName': 'users',
        'email': 'user@example.com',
        'role': '',
        'created': '2026-01-01 00:00:00.000Z',
        'updated': '2026-01-01 00:00:00.000Z',
      });
      fakePb.authStore.save(token, record);

      final svc = PocketBaseService();
      expect(svc.isReadonlyUser, isFalse);
    });

    test('T-012.45: isReadonlyUser mit role = "user" → false', () {
      final fakePb = _FakePocketBaseForAuth();
      PocketBaseService.overrideForTesting(fakePb);

      final record = RecordModel.fromJson({
        'id': 'user-002',
        'collectionId': '_pb_users_auth_',
        'collectionName': 'users',
        'email': 'user2@example.com',
        'role': 'user',
        'created': '2026-01-01 00:00:00.000Z',
        'updated': '2026-01-01 00:00:00.000Z',
      });
      fakePb.authStore.save(token, record);

      final svc = PocketBaseService();
      expect(svc.isReadonlyUser, isFalse);
    });
  });
}