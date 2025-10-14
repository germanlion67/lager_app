// lib/services/sync_error_recovery.dart

import 'dart:async';
import 'dart:io';
import 'package:logger/logger.dart';


/// Typ von Sync-Fehlern
enum SyncErrorType {
  network,
  authentication,
  server,
  client,
  conflict,
  storage,
  timeout,
  unknown
}

/// Schweregrad eines Fehlers
enum ErrorSeverity {
  low,     // Kann ignoriert werden
  medium,  // Sollte behobeun werden
  high,    // Muss behoben werden
  critical // Blockiert weitere Synchronisation
}

/// Details eines Sync-Fehlers
class SyncError {
  final String id;
  final SyncErrorType type;
  final ErrorSeverity severity;
  final String message;
  final String? technicalDetails;
  final Object? originalError;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final String? itemId;
  final String? itemName;
  final Map<String, dynamic> context;
  final List<RecoveryAction> suggestedActions;

  SyncError({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    this.technicalDetails,
    this.originalError,
    this.stackTrace,
    DateTime? timestamp,
    this.itemId,
    this.itemName,
    this.context = const {},
    this.suggestedActions = const [],
  }) : timestamp = timestamp ?? DateTime.now();

  /// Erstellt einen SyncError aus einer Exception
  factory SyncError.fromException(Object error, {
    StackTrace? stackTrace,
    String? itemId,
    String? itemName,
    Map<String, dynamic>? context,
  }) {
    final type = _determineErrorType(error);
    final severity = _determineSeverity(type, error);
    final message = _generateUserMessage(type, error);
    final actions = _generateSuggestedActions(type, error);
    
    return SyncError(
      id: 'error_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      severity: severity,
      message: message,
      technicalDetails: error.toString(),
      originalError: error,
      stackTrace: stackTrace,
      itemId: itemId,
      itemName: itemName,
      context: context ?? {},
      suggestedActions: actions,
    );
  }

  static SyncErrorType _determineErrorType(Object error) {
    if (error is SocketException || error is HttpException) {
      return SyncErrorType.network;
    }
    if (error is TimeoutException) {
      return SyncErrorType.timeout;
    }
    if (error.toString().contains('authentication') || 
        error.toString().contains('unauthorized') ||
        error.toString().contains('401')) {
      return SyncErrorType.authentication;
    }
    if (error.toString().contains('server') || 
        error.toString().contains('50')) {
      return SyncErrorType.server;
    }
    if (error.toString().contains('conflict') || 
        error.toString().contains('409')) {
      return SyncErrorType.conflict;
    }
    if (error is FileSystemException) {
      return SyncErrorType.storage;
    }
    return SyncErrorType.unknown;
  }

  static ErrorSeverity _determineSeverity(SyncErrorType type, Object error) {
    switch (type) {
      case SyncErrorType.authentication:
        return ErrorSeverity.critical;
      case SyncErrorType.network:
        return ErrorSeverity.medium;
      case SyncErrorType.server:
        return ErrorSeverity.high;
      case SyncErrorType.conflict:
        return ErrorSeverity.medium;
      case SyncErrorType.storage:
        return ErrorSeverity.high;
      case SyncErrorType.timeout:
        return ErrorSeverity.low;
      default:
        return ErrorSeverity.medium;
    }
  }

  static String _generateUserMessage(SyncErrorType type, Object error) {
    switch (type) {
      case SyncErrorType.network:
        return 'Netzwerkfehler: Verbindung zum Server nicht möglich';
      case SyncErrorType.authentication:
        return 'Authentifizierungsfehler: Benutzername oder Passwort ungültig';
      case SyncErrorType.server:
        return 'Serverfehler: Der Nextcloud-Server hat einen Fehler gemeldet';
      case SyncErrorType.conflict:
        return 'Konflikt: Gleichzeitige Bearbeitung erkannt';
      case SyncErrorType.storage:
        return 'Speicherfehler: Lokaler Dateizugriff fehlgeschlagen';
      case SyncErrorType.timeout:
        return 'Timeout: Vorgang dauerte zu lange';
      case SyncErrorType.client:
        return 'Client-Fehler: Problem mit der App-Konfiguration';
      default:
        return 'Unbekannter Fehler bei der Synchronisation';
    }
  }

  static List<RecoveryAction> _generateSuggestedActions(SyncErrorType type, Object error) {
    final actions = <RecoveryAction>[];
    
    switch (type) {
      case SyncErrorType.network:
        actions.addAll([
          RecoveryAction.checkConnection,
          RecoveryAction.retry,
          RecoveryAction.retryLater,
        ]);
        break;
      case SyncErrorType.authentication:
        actions.addAll([
          RecoveryAction.checkCredentials,
          RecoveryAction.relogin,
        ]);
        break;
      case SyncErrorType.server:
        actions.addAll([
          RecoveryAction.retryLater,
          RecoveryAction.contactAdmin,
        ]);
        break;
      case SyncErrorType.conflict:
        actions.addAll([
          RecoveryAction.resolveConflict,
          RecoveryAction.skipItem,
        ]);
        break;
      case SyncErrorType.storage:
        actions.addAll([
          RecoveryAction.checkStorage,
          RecoveryAction.clearCache,
        ]);
        break;
      case SyncErrorType.timeout:
        actions.addAll([
          RecoveryAction.retry,
          RecoveryAction.adjustTimeout,
        ]);
        break;
      default:
        actions.addAll([
          RecoveryAction.retry,
          RecoveryAction.skipItem,
          RecoveryAction.reportBug,
        ]);
    }
    
    return actions;
  }

  bool get isRetryable => severity != ErrorSeverity.critical && 
                         (type == SyncErrorType.network || 
                          type == SyncErrorType.timeout ||
                          type == SyncErrorType.server);

  bool get requiresUserAction => severity == ErrorSeverity.critical ||
                                type == SyncErrorType.conflict ||
                                type == SyncErrorType.authentication;
}

/// Empfohlene Wiederherstellungsaktionen
enum RecoveryAction {
  retry,
  retryLater,
  skipItem,
  resolveConflict,
  checkConnection,
  checkCredentials,
  relogin,
  clearCache,
  checkStorage,
  adjustTimeout,
  contactAdmin,
  reportBug,
  viewLogs,
}

extension RecoveryActionExtension on RecoveryAction {
  String get title {
    switch (this) {
      case RecoveryAction.retry:
        return 'Erneut versuchen';
      case RecoveryAction.retryLater:
        return 'Später erneut versuchen';
      case RecoveryAction.skipItem:
        return 'Element überspringen';
      case RecoveryAction.resolveConflict:
        return 'Konflikt auflösen';
      case RecoveryAction.checkConnection:
        return 'Internetverbindung prüfen';
      case RecoveryAction.checkCredentials:
        return 'Anmeldedaten prüfen';
      case RecoveryAction.relogin:
        return 'Erneut anmelden';
      case RecoveryAction.clearCache:
        return 'Cache leeren';
      case RecoveryAction.checkStorage:
        return 'Speicherplatz prüfen';
      case RecoveryAction.adjustTimeout:
        return 'Timeout anpassen';
      case RecoveryAction.contactAdmin:
        return 'Administrator kontaktieren';
      case RecoveryAction.reportBug:
        return 'Fehler melden';
      case RecoveryAction.viewLogs:
        return 'Logs anzeigen';
    }
  }

  String get description {
    switch (this) {
      case RecoveryAction.retry:
        return 'Den fehlgeschlagenen Vorgang sofort wiederholen';
      case RecoveryAction.retryLater:
        return 'Den Vorgang zu einem späteren Zeitpunkt wiederholen';
      case RecoveryAction.skipItem:
        return 'Dieses Element vorerst überspringen';
      case RecoveryAction.resolveConflict:
        return 'Den Synchronisationskonflikt manuell auflösen';
      case RecoveryAction.checkConnection:
        return 'WLAN/Mobile Daten und Server-Erreichbarkeit prüfen';
      case RecoveryAction.checkCredentials:
        return 'Benutzername und App-Passwort in den Einstellungen prüfen';
      case RecoveryAction.relogin:
        return 'Sich erneut bei Nextcloud anmelden';
      case RecoveryAction.clearCache:
        return 'App-Cache und temporäre Dateien löschen';
      case RecoveryAction.checkStorage:
        return 'Verfügbaren Speicherplatz auf dem Gerät prüfen';
      case RecoveryAction.adjustTimeout:
        return 'Timeout-Einstellungen für langsame Verbindungen anpassen';
      case RecoveryAction.contactAdmin:
        return 'Den Nextcloud-Administrator über Serverprobleme informieren';
      case RecoveryAction.reportBug:
        return 'Fehlerdetails an die App-Entwickler senden';
      case RecoveryAction.viewLogs:
        return 'Detaillierte Fehlerprotokolle anzeigen';
    }
  }
}

/// Service für Error Recovery und Retry Logic
class SyncErrorRecoveryService {
  final Logger logger = Logger();
  final List<SyncError> _errorHistory = [];
  final Map<String, int> _retryCount = {};
  final Map<String, DateTime> _lastRetryTime = {};
  
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 5);
  static const Duration exponentialBackoffBase = Duration(seconds: 2);

  List<SyncError> get errorHistory => List.unmodifiable(_errorHistory);

  /// Behandelt einen aufgetretenen Fehler
  Future<SyncErrorRecoveryResult> handleError(
    Object error, {
    StackTrace? stackTrace,
    String? itemId,
    String? itemName,
    Map<String, dynamic>? context,
  }) async {
    logger.e('Sync error occurred', error: error, stackTrace: stackTrace);
    
    final syncError = SyncError.fromException(
      error,
      stackTrace: stackTrace,
      itemId: itemId,
      itemName: itemName,
      context: context,
    );
    
    _errorHistory.add(syncError);
    
    // Bestimme Recovery-Strategie
    final strategy = _determineRecoveryStrategy(syncError);
    
    return SyncErrorRecoveryResult(
      error: syncError,
      strategy: strategy,
      canRetry: _canRetry(syncError),
      shouldSkip: _shouldSkip(syncError),
      requiresUserInput: syncError.requiresUserAction,
    );
  }

  /// Bestimmt die optimale Recovery-Strategie
  RecoveryStrategy _determineRecoveryStrategy(SyncError error) {
    // Kritische Fehler erfordern sofortige Benutzeraktion
    if (error.severity == ErrorSeverity.critical) {
      return RecoveryStrategy.requireUserAction;
    }
    
    // Konflikte erfordern Benutzerentscheidung
    if (error.type == SyncErrorType.conflict) {
      return RecoveryStrategy.resolveConflict;
    }
    
    // Prüfe Retry-Möglichkeiten
    if (_canRetry(error)) {
      return RecoveryStrategy.retryWithBackoff;
    }
    
    // Überspringbare Fehler
    if (error.severity == ErrorSeverity.low) {
      return RecoveryStrategy.skipAndContinue;
    }
    
    return RecoveryStrategy.requireUserAction;
  }

  /// Prüft ob ein Retry möglich ist
  bool _canRetry(SyncError error) {
    if (!error.isRetryable) return false;
    
    final key = error.itemId ?? error.type.toString();
    final retries = _retryCount[key] ?? 0;
    
    return retries < maxRetries;
  }

  /// Prüft ob ein Item übersprungen werden sollte
  bool _shouldSkip(SyncError error) {
    return error.severity == ErrorSeverity.low || 
           (!error.isRetryable && error.severity != ErrorSeverity.critical);
  }

  /// Führt einen Retry mit exponential backoff durch
  Future<void> performRetry(
    SyncError error,
    Future<void> Function() retryFunction,
  ) async {
    final key = error.itemId ?? error.type.toString();
    final retries = _retryCount[key] ?? 0;
    
    if (retries >= maxRetries) {
      throw Exception('Maximum retry count reached for ${error.message}');
    }
    
    // Exponential backoff
    final delay = Duration(
      milliseconds: exponentialBackoffBase.inMilliseconds * (1 << retries),
    );
    
    logger.i('Retrying after ${delay.inSeconds}s (attempt ${retries + 1}/$maxRetries)');
    await Future.delayed(delay);
    
    _retryCount[key] = retries + 1;
    _lastRetryTime[key] = DateTime.now();
    
    try {
      await retryFunction();
      // Bei Erfolg: Reset retry count
      _retryCount.remove(key);
      _lastRetryTime.remove(key);
    } catch (e) {
      // Bei erneutem Fehler: Count erhöhen
      rethrow;
    }
  }

  /// Erstellt eine Batch-Recovery für mehrere Fehler
  Future<BatchRecoveryResult> performBatchRecovery(
    List<SyncError> errors,
    Future<void> Function(SyncError) retryFunction,
  ) async {
    int successful = 0;
    int failed = 0;
    int skipped = 0;
    final List<SyncError> remainingErrors = [];

    for (final error in errors) {
      try {
        if (_shouldSkip(error)) {
          skipped++;
          continue;
        }

        if (_canRetry(error)) {
          await performRetry(error, () => retryFunction(error));
          successful++;
        } else {
          remainingErrors.add(error);
          failed++;
        }
      } catch (e) {
        remainingErrors.add(error);
        failed++;
      }
    }

    return BatchRecoveryResult(
      successful: successful,
      failed: failed,
      skipped: skipped,
      remainingErrors: remainingErrors,
    );
  }

  /// Löscht alte Fehler aus der History
  void clearOldErrors({Duration maxAge = const Duration(days: 7)}) {
    final cutoff = DateTime.now().subtract(maxAge);
    _errorHistory.removeWhere((error) => error.timestamp.isBefore(cutoff));
  }

  /// Generiert einen Fehlerbericht
  Map<String, dynamic> generateErrorReport() {
    final now = DateTime.now();
    final last24h = _errorHistory.where(
      (e) => now.difference(e.timestamp).inHours <= 24,
    ).toList();

    return {
      'summary': {
        'totalErrors': _errorHistory.length,
        'errorsLast24h': last24h.length,
        'mostCommonType': _getMostCommonErrorType(),
        'criticalErrors': _errorHistory.where((e) => e.severity == ErrorSeverity.critical).length,
      },
      'errorsByType': _getErrorsByType(),
      'errorsBySeverity': _getErrorsBySeverity(),
      'recentErrors': last24h.take(10).map((e) => {
        'timestamp': e.timestamp.toIso8601String(),
        'type': e.type.toString(),
        'severity': e.severity.toString(),
        'message': e.message,
        'item': e.itemName,
      }).toList(),
    };
  }

  String? _getMostCommonErrorType() {
    if (_errorHistory.isEmpty) return null;
    final typeCount = <SyncErrorType, int>{};
    for (final error in _errorHistory) {
      typeCount[error.type] = (typeCount[error.type] ?? 0) + 1;
    }
    return typeCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key
        .toString();
  }

  Map<String, int> _getErrorsByType() {
    final result = <String, int>{};
    for (final error in _errorHistory) {
      final type = error.type.toString();
      result[type] = (result[type] ?? 0) + 1;
    }
    return result;
  }

  Map<String, int> _getErrorsBySeverity() {
    final result = <String, int>{};
    for (final error in _errorHistory) {
      final severity = error.severity.toString();
      result[severity] = (result[severity] ?? 0) + 1;
    }
    return result;
  }
}

/// Recovery-Strategien
enum RecoveryStrategy {
  retryWithBackoff,
  skipAndContinue,
  resolveConflict,
  requireUserAction,
  abort
}

/// Ergebnis einer Error Recovery
class SyncErrorRecoveryResult {
  final SyncError error;
  final RecoveryStrategy strategy;
  final bool canRetry;
  final bool shouldSkip;
  final bool requiresUserInput;

  SyncErrorRecoveryResult({
    required this.error,
    required this.strategy,
    required this.canRetry,
    required this.shouldSkip,
    required this.requiresUserInput,
  });
}

/// Ergebnis einer Batch-Recovery
class BatchRecoveryResult {
  final int successful;
  final int failed;
  final int skipped;
  final List<SyncError> remainingErrors;

  BatchRecoveryResult({
    required this.successful,
    required this.failed,
    required this.skipped,
    required this.remainingErrors,
  });

  int get total => successful + failed + skipped;
  bool get hasRemainingErrors => remainingErrors.isNotEmpty;
  double get successRate => total > 0 ? successful / total : 0.0;
}