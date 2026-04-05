// lib/core/app_exception.dart
//
// M-003: Zentrale Fehlerklassen für die gesamte App.
//
// HIERARCHIE:
//   AppException                  ← Basis (sealed)
//   ├── NetworkException          ← Keine Verbindung, Timeout
//   ├── ServerException           ← HTTP 4xx / 5xx, PocketBase-Fehler
//   ├── AuthException             ← Login, Token, Rechte
//   ├── SyncException             ← Sync-spezifische Fehler
//   ├── StorageException          ← SQLite, Dateisystem
//   ├── ValidationException       ← Eingabe-Validierung
//   └── UnknownException          ← Generischer Fallback

/// Basis-Klasse für alle App-spezifischen Fehler.
sealed class AppException implements Exception {
  /// Benutzerfreundliche Fehlermeldung (wird in der UI angezeigt).
  final String message;

  /// Technisches Detail für Logs und den Debug-Dialog (optional).
  final String? technicalDetail;

  /// Original-Exception die gefangen wurde (für Stack-Traces).
  final Object? cause;

  const AppException({
    required this.message,
    this.technicalDetail,
    this.cause,
  });

  @override
  String toString() => 'AppException: $message'
      '${technicalDetail != null ? " [$technicalDetail]" : ""}';
}

/// Netzwerkfehler: Keine Verbindung, Timeout, DNS-Fehler.
final class NetworkException extends AppException {
  const NetworkException({
    super.message = 'Keine Verbindung zum Server. '
        'Bitte Internetverbindung prüfen.',
    super.technicalDetail,
    super.cause,
  });
}

/// Serverfehler: HTTP 4xx / 5xx, PocketBase ClientException.
final class ServerException extends AppException {
  /// HTTP-Statuscode (z. B. 404, 500), falls verfügbar.
  final int? statusCode;

  const ServerException({
    super.message = 'Serverfehler. Bitte später erneut versuchen.',
    super.technicalDetail,
    super.cause,
    this.statusCode,
  });
}

/// Authentifizierungsfehler: Login, Token abgelaufen, fehlende Rechte.
final class AuthException extends AppException {
  const AuthException({
    super.message = 'Anmeldung fehlgeschlagen. '
        'Bitte Zugangsdaten prüfen.',
    super.technicalDetail,
    super.cause,
  });
}

/// Sync-Fehler: Konflikte, Push/Pull-Fehler, Initialisierungsfehler.
final class SyncException extends AppException {
  const SyncException({
    super.message = 'Synchronisation fehlgeschlagen. '
        'Bitte später erneut versuchen.',
    super.technicalDetail,
    super.cause,
  });
}

/// Speicherfehler: SQLite, Dateisystem, fehlende Berechtigungen.
final class StorageException extends AppException {
  const StorageException({
    super.message = 'Fehler beim Speichern der Daten.',
    super.technicalDetail,
    super.cause,
  });
}

/// Validierungsfehler: Pflichtfelder, Duplikate, ungültige Eingaben.
final class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.technicalDetail,
    super.cause,
  });
}

/// Generischer Fallback für unbekannte Exceptions.
///
// FIX instantiate_abstract_class: AppException ist sealed und kann
// nicht direkt instanziiert werden. UnknownException dient als
// konkreter Fallback in AppErrorHandler.classify().
final class UnknownException extends AppException {
  const UnknownException({
    super.message = 'Ein unerwarteter Fehler ist aufgetreten.',
    super.technicalDetail,
    super.cause,
  });
}