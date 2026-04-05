// lib/widgets/app_error_handler.dart
//
// M-003: Zentrales Error-Handling Utility.
//
// VERWENDUNG:
//   AppErrorHandler.showSnackBar(context, e);
//   AppErrorHandler.showSnackBarWithDetails(context, e, stackTrace: st);
//   AppErrorHandler.log(e, stackTrace: st, context: 'ArtikelDetailScreen');
//   final appEx = AppErrorHandler.classify(e);
//
// FEHLER-ÜBERSETZUNG:
//   SocketException / HandshakeException  → NetworkException
//   TimeoutException                      → NetworkException
//   ClientException (PocketBase 401/403)  → AuthException
//   ClientException (PocketBase 4xx/5xx)  → ServerException
//   ClientException (kein Statuscode)     → NetworkException
//   AppException-Subklassen               → direkt durchgereicht
//   Alles andere                          → UnknownException

import 'dart:io' show SocketException, HandshakeException;
import 'dart:async' show TimeoutException;

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart' show ClientException;

import '../config/app_config.dart';
import '../core/app_exception.dart';
import '../services/app_log_service.dart';

abstract final class AppErrorHandler {
  static final _logger = AppLogService.logger;

  // ---------------------------------------------------------------------------
  // Klassifizierung
  // ---------------------------------------------------------------------------

  /// Übersetzt eine beliebige Exception in eine [AppException]-Subklasse.
  ///
  /// Bereits klassifizierte [AppException]s werden direkt zurückgegeben.
  /// Unbekannte Exceptions werden als [UnknownException] verpackt.
  static AppException classify(Object error) {
    // Bereits klassifiziert → direkt zurückgeben
    if (error is AppException) return error;

    // Netzwerkfehler
    if (error is SocketException) {
      // FIX unnecessary_null_comparison:
      // SocketException.message ist String (non-nullable) → kein null-Check.
      return NetworkException(
        message: 'Keine Verbindung zum Server. '
            'Bitte Internetverbindung prüfen.',
        technicalDetail: error.message.isNotEmpty ? error.message : null,
        cause: error,
      );
    }

    if (error is HandshakeException) {
      // FIX unnecessary_null_comparison:
      // HandshakeException.message ist String (non-nullable) → kein null-Check.
      return NetworkException(
        message: 'Sichere Verbindung konnte nicht hergestellt werden.',
        technicalDetail: error.message.isNotEmpty ? error.message : null,
        cause: error,
      );
    }

    if (error is TimeoutException) {
      return NetworkException(
        message: 'Zeitüberschreitung. Server antwortet nicht.',
        technicalDetail: error.message,
        cause: error,
      );
    }

    // PocketBase ClientException
    if (error is ClientException) {
      final status = error.statusCode;

      if (status == 401 || status == 403) {
        return AuthException(
          message: status == 401
              ? 'Anmeldung abgelaufen. Bitte erneut einloggen.'
              : 'Keine Berechtigung für diese Aktion.',
          technicalDetail: 'HTTP $status: ${error.response}',
          cause: error,
        );
      }

      if (status >= 500) {
        return ServerException(
          message: 'Serverfehler ($status). '
              'Bitte später erneut versuchen.',
          technicalDetail: 'HTTP $status: ${error.response}',
          statusCode: status,
          cause: error,
        );
      }

      if (status >= 400) {
        return ServerException(
          message: 'Anfrage fehlgeschlagen ($status).',
          technicalDetail: 'HTTP $status: ${error.response}',
          statusCode: status,
          cause: error,
        );
      }

      // status == 0 oder anderer Wert → Netzwerkproblem
      return NetworkException(
        message: 'Verbindung zum Server fehlgeschlagen.',
        technicalDetail: error.url?.toString(),
        cause: error,
      );
    }

    // FIX instantiate_abstract_class:
    // AppException ist sealed → UnknownException als konkreter Fallback.
    return UnknownException(
      technicalDetail: error.toString(),
      cause: error,
    );
  }

  // ---------------------------------------------------------------------------
  // Logging
  // ---------------------------------------------------------------------------

  /// Loggt einen Fehler mit optionalem Kontext-Label und Stack-Trace.
  ///
  /// - [NetworkException] / [ValidationException] → warning
  /// - Alle anderen → error
  static void log(
    Object error, {
    StackTrace? stackTrace,
    String? context,
  }) {
    final appEx = classify(error);
    final prefix = context != null ? '[$context] ' : '';

    if (appEx is NetworkException || appEx is ValidationException) {
      _logger.w(
        '$prefix${appEx.message}',
        error: appEx.cause ?? error,
        stackTrace: stackTrace,
      );
    } else {
      _logger.e(
        '$prefix${appEx.message}'
        '${appEx.technicalDetail != null
            ? " — ${appEx.technicalDetail}"
            : ""}',
        error: appEx.cause ?? error,
        stackTrace: stackTrace,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // SnackBar
  // ---------------------------------------------------------------------------

  /// Zeigt einen einfachen Fehler-SnackBar.
  static void showSnackBar(
    BuildContext context,
    Object error, {
    StackTrace? stackTrace,
    String? contextLabel,
  }) {
    log(error, stackTrace: stackTrace, context: contextLabel);

    if (!context.mounted) return;

    final appEx = classify(error);
    final colorScheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(appEx.message),
          backgroundColor: colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Zeigt einen Fehler-SnackBar mit "Details"-Button.
  ///
  /// Der "Details"-Button öffnet [_showErrorDialog] mit dem
  /// technischen Detail.
  static void showSnackBarWithDetails(
    BuildContext context,
    Object error, {
    StackTrace? stackTrace,
    String? contextLabel,
  }) {
    log(error, stackTrace: stackTrace, context: contextLabel);

    if (!context.mounted) return;

    final appEx = classify(error);
    final colorScheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(appEx.message),
          backgroundColor: colorScheme.error,
          behavior: SnackBarBehavior.floating,
          action: appEx.technicalDetail != null
              ? SnackBarAction(
                  label: 'Details',
                  textColor: colorScheme.onError,
                  onPressed: () {
                    if (context.mounted) {
                      _showErrorDialog(context, appEx);
                    }
                  },
                )
              : null,
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Dialog
  // ---------------------------------------------------------------------------

  /// Zeigt einen modalen Fehler-Dialog.
  static Future<void> showErrorDialog(
    BuildContext context,
    Object error, {
    StackTrace? stackTrace,
    String? contextLabel,
    String title = 'Fehler',
  }) async {
    log(error, stackTrace: stackTrace, context: contextLabel);

    if (!context.mounted) return;

    final appEx = classify(error);
    await _showErrorDialog(context, appEx, title: title);
  }

  // ---------------------------------------------------------------------------
  // Interne Hilfsmethoden
  // ---------------------------------------------------------------------------

  static Future<void> _showErrorDialog(
    BuildContext context,
    AppException appEx, {
    String title = 'Fehler',
  }) async {
    if (!context.mounted) return;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.error),
            const SizedBox(width: AppConfig.spacingSmall),
            Expanded(child: Text(title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                appEx.message,
                style: textTheme.bodyMedium,
              ),
              if (appEx.technicalDetail != null) ...[
                const SizedBox(height: AppConfig.spacingMedium),
                Text(
                  'Technische Details:',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppConfig.spacingXSmall),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppConfig.spacingMedium),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadiusMedium,
                    ),
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                    ),
                  ),
                  child: Text(
                    appEx.technicalDetail!,
                    style: textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              if (_getSuggestions(appEx).isNotEmpty) ...[
                const SizedBox(height: AppConfig.spacingMedium),
                Text(
                  'Mögliche Lösungen:',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppConfig.spacingXSmall),
                ..._getSuggestions(appEx).map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppConfig.spacingXSmall,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            s,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Gibt kontextabhängige Lösungsvorschläge für einen Fehlertyp zurück.
  ///
  // FIX unreachable_switch_case: AppException ist sealed — alle Subklassen
  // sind explizit aufgeführt. Der frühere _-Wildcard-Zweig war unerreichbar
  // und wurde entfernt.
  static List<String> _getSuggestions(AppException appEx) {
    return switch (appEx) {
      NetworkException() => [
          'Internetverbindung prüfen',
          'Server-URL in den Einstellungen überprüfen',
          'Später erneut versuchen',
        ],
      AuthException() => [
          'Zugangsdaten prüfen',
          'Erneut einloggen',
          'Administrator kontaktieren',
        ],
      ServerException() => [
          'Später erneut versuchen',
          'Server-Status prüfen',
          'Administrator kontaktieren',
        ],
      SyncException() => [
          'Internetverbindung prüfen',
          'Sync-Einstellungen überprüfen',
          'Später erneut versuchen',
        ],
      StorageException() => [
          'App-Speicher prüfen',
          'App neu starten',
          'App-Daten zurücksetzen (letzter Ausweg)',
        ],
      // ValidationException und UnknownException: keine Vorschläge
      ValidationException() => const [],
      UnknownException() => [
          'App neu starten',
          'Später erneut versuchen',
        ],
    };
  }
}