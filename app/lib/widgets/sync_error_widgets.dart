// lib/widgets/sync_error_widgets.dart
//
// O-004 Batch 2: Alle hardcodierten Farben durch colorScheme ersetzt,
// alle Magic-Number-Abstände/Radien durch AppConfig-Tokens.

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/app_log_service.dart';
import '../services/sync_error_recovery.dart';

/// Dialog für die Behandlung von Sync-Fehlern.
class SyncErrorDialog extends StatelessWidget {
  final SyncError error;
  final void Function(RecoveryAction) onAction;

  const SyncErrorDialog({
    super.key,
    required this.error,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final severityColor = _getSeverityColor(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _getSeverityIcon(),
            color: severityColor,
            size: AppConfig.iconSizeLarge,
          ),
          const SizedBox(width: AppConfig.spacingSmall),
          const Expanded(
            child: Text('Synchronisationsfehler'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppConfig.spacingMedium),
              decoration: BoxDecoration(
                color: severityColor.withValues(
                  alpha: AppConfig.opacitySubtle,
                ),
                borderRadius: BorderRadius.circular(
                  AppConfig.borderRadiusMedium,
                ),
                border: Border.all(
                  color: severityColor.withValues(
                    alpha: AppConfig.opacityMedium,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    error.message,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (error.itemName != null) ...[
                    const SizedBox(height: AppConfig.spacingSmall),
                    Text(
                      'Betroffener Artikel: ${error.itemName}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppConfig.spacingLarge),

            if (error.technicalDetails != null)
              ExpansionTile(
                title: const Text('Technische Details'),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConfig.spacingMedium),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(
                        AppConfig.borderRadiusMedium,
                      ),
                    ),
                    child: Text(
                      error.technicalDetails!,
                      style: textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: AppConfig.spacingLarge),

            Text(
              'Empfohlene Lösungen:',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConfig.spacingSmall),

            ...error.suggestedActions.take(3).map(_buildActionTile),
          ],
        ),
      ),
      actions: [
        if (error.suggestedActions.isNotEmpty)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onAction(error.suggestedActions.first);
            },
            child: Text(error.suggestedActions.first.title),
          ),

        if (error.suggestedActions.length > 1)
          TextButton(
            onPressed: () => _showAllActions(context),
            child: const Text('Weitere Optionen'),
          ),

        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }

  Widget _buildActionTile(RecoveryAction action) {
    return ListTile(
      dense: true,
      leading: Icon(_getActionIcon(action), size: AppConfig.iconSizeMedium),
      title: Text(action.title),
      subtitle: Text(
        action.description,
        style: const TextStyle(fontSize: AppConfig.fontSizeSmall),
      ),
      onTap: () => onAction(action),
    );
  }

  void _showAllActions(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alle Lösungsoptionen'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: error.suggestedActions
                .map(
                  (action) => ListTile(
                    leading: Icon(_getActionIcon(action)),
                    title: Text(action.title),
                    subtitle: Text(action.description),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                      onAction(action);
                    },
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  IconData _getSeverityIcon() {
    return switch (error.severity) {
      ErrorSeverity.critical => Icons.error,
      ErrorSeverity.high     => Icons.warning,
      ErrorSeverity.medium   => Icons.info,
      ErrorSeverity.low      => Icons.info_outline,
    };
  }

  Color _getSeverityColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (error.severity) {
      ErrorSeverity.critical => colorScheme.error,
      ErrorSeverity.high     => colorScheme.secondary,
      ErrorSeverity.medium   => colorScheme.primary,
      ErrorSeverity.low      => colorScheme.onSurfaceVariant,
    };
  }

  IconData _getActionIcon(RecoveryAction action) {
    return switch (action) {
      RecoveryAction.retry             => Icons.refresh,
      RecoveryAction.retryLater        => Icons.schedule,
      RecoveryAction.skipItem          => Icons.skip_next,
      RecoveryAction.resolveConflict   => Icons.merge_type,
      RecoveryAction.checkConnection   => Icons.wifi,
      RecoveryAction.checkCredentials  => Icons.key,
      RecoveryAction.relogin           => Icons.login,
      RecoveryAction.clearCache        => Icons.clear_all,
      RecoveryAction.checkStorage      => Icons.storage,
      RecoveryAction.adjustTimeout     => Icons.timer,
      RecoveryAction.contactAdmin      => Icons.support_agent,
      RecoveryAction.reportBug         => Icons.bug_report,
      RecoveryAction.viewLogs          => Icons.article,
    };
  }

  static Future<void> show(
    BuildContext context,
    SyncError error,
    void Function(RecoveryAction) onAction,
  ) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => SyncErrorDialog(
        error: error,
        onAction: onAction,
      ),
    );
  }
}

/// Kompakte Error-Anzeige für die AppBar oder als Banner.
class SyncErrorBanner extends StatelessWidget {
  final List<SyncError> errors;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const SyncErrorBanner({
    super.key,
    required this.errors,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final criticalErrors =
        errors.where((e) => e.severity == ErrorSeverity.critical).length;
    final totalErrors = errors.length;
    final isCritical = criticalErrors > 0;

    final bannerColor = isCritical
        ? colorScheme.errorContainer
        : colorScheme.secondaryContainer;
    final contentColor = isCritical
        ? colorScheme.onErrorContainer
        : colorScheme.onSecondaryContainer;

    return Container(
      margin: const EdgeInsets.all(AppConfig.spacingSmall),
      child: Material(
        color: bannerColor,
        borderRadius: BorderRadius.circular(AppConfig.borderRadiusMedium),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConfig.borderRadiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(AppConfig.spacingMedium),
            child: Row(
              children: [
                Icon(
                  isCritical ? Icons.error : Icons.warning,
                  color: contentColor,
                  size: AppConfig.iconSizeMedium,
                ),
                const SizedBox(width: AppConfig.spacingSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isCritical
                            ? 'Kritische Sync-Fehler ($criticalErrors)'
                            : 'Sync-Probleme ($totalErrors)',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: contentColor,
                        ),
                      ),
                      Text(
                        isCritical
                            ? 'Synchronisation blockiert - Aktion erforderlich'
                            : 'Einige Artikel konnten nicht synchronisiert werden',
                        style: textTheme.bodySmall?.copyWith(
                          color: contentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDismiss == null)
                  Icon(Icons.chevron_right, color: contentColor),
                if (onDismiss != null)
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: AppConfig.iconSizeSmall,
                      color: contentColor,
                    ),
                    onPressed: onDismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Error Recovery Progress Dialog.
class ErrorRecoveryProgressDialog extends StatefulWidget {
  final List<SyncError> errors;
  final Future<void> Function(SyncError) retryFunction;

  const ErrorRecoveryProgressDialog({
    super.key,
    required this.errors,
    required this.retryFunction,
  });

  @override
  State<ErrorRecoveryProgressDialog> createState() =>
      _ErrorRecoveryProgressDialogState();

  static Future<BatchRecoveryResult?> show(
    BuildContext context,
    List<SyncError> errors,
    Future<void> Function(SyncError) retryFunction,
  ) {
    return showDialog<BatchRecoveryResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ErrorRecoveryProgressDialog(
        errors: errors,
        retryFunction: retryFunction,
      ),
    );
  }
}

class _ErrorRecoveryProgressDialogState
    extends State<ErrorRecoveryProgressDialog> {
  final _logger = AppLogService.logger;
  late final SyncErrorRecoveryService _recoveryService;
  BatchRecoveryResult? _result;
  bool _isRunning = false;
  int _currentIndex = 0;
  String _currentStatus = '';

  @override
  void initState() {
    super.initState();
    _recoveryService = SyncErrorRecoveryService();
    _startRecovery();
  }

  Future<void> _startRecovery() async {
    setState(() {
      _isRunning = true;
      _currentStatus = 'Starte Wiederherstellung...';
    });

    try {
      final result = await _recoveryService.performBatchRecovery(
        widget.errors,
        (error) async {
          if (!mounted) return;
          setState(() {
            _currentIndex++;
            _currentStatus =
                'Bearbeite: ${error.itemName ?? error.message}';
          });
          await widget.retryFunction(error);
        },
      );

      if (!mounted) return;

      setState(() {
        _result = result;
        _isRunning = false;
        _currentStatus = 'Wiederherstellung abgeschlossen';
      });

      await Future<void>.delayed(const Duration(seconds: 3));

      if (mounted) {
        Navigator.of(context).pop(_result);
      }
    } catch (e, st) {
      _logger.e(
        '[ErrorRecovery] Wiederherstellung fehlgeschlagen',
        error: e,
        stackTrace: st,
      );

      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _currentStatus = 'Fehler bei der Wiederherstellung: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progress = widget.errors.isNotEmpty
        ? _currentIndex / widget.errors.length
        : 0.0;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.healing, color: colorScheme.primary),
          const SizedBox(width: AppConfig.spacingSmall),
          const Text('Fehler-Wiederherstellung'),
        ],
      ),
      content: SizedBox(
        width: AppConfig.dialogContentWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentStatus),
            const SizedBox(height: AppConfig.spacingLarge),
            LinearProgressIndicator(
              value: _isRunning ? progress : 1.0,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: AppConfig.spacingSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_currentIndex/${widget.errors.length}',
                  style: textTheme.bodySmall,
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
            if (_result != null) ...[
              const SizedBox(height: AppConfig.spacingLarge),
              const Divider(),
              const SizedBox(height: AppConfig.spacingSmall),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildResultChip(
                    context,
                    'Erfolgreich',
                    _result!.successful.toString(),
                    colorScheme.tertiary,
                  ),
                  _buildResultChip(
                    context,
                    'Fehlgeschlagen',
                    _result!.failed.toString(),
                    colorScheme.error,
                  ),
                  _buildResultChip(
                    context,
                    'Übersprungen',
                    _result!.skipped.toString(),
                    colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isRunning)
          TextButton(
            onPressed: () => Navigator.of(context).pop(_result),
            child: const Text('OK'),
          ),
      ],
    );
  }

  Widget _buildResultChip(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConfig.spacingMedium,
            vertical: AppConfig.spacingSmall - 2, // 6.0
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: AppConfig.opacitySubtle),
            borderRadius: BorderRadius.circular(
              AppConfig.borderRadiusXLarge,
            ),
            border: Border.all(
              color: color.withValues(alpha: AppConfig.opacityMedium),
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: AppConfig.spacingXSmall),
        Text(
          label,
          style: textTheme.labelSmall,
        ),
      ],
    );
  }
}

/// Error List Widget für detaillierte Fehleranzeige.
class SyncErrorList extends StatelessWidget {
  final List<SyncError> errors;
  final void Function(RecoveryAction, SyncError)? onAction;
  final bool showActions;

  const SyncErrorList({
    super.key,
    required this.errors,
    this.onAction,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (errors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: colorScheme.tertiary,
            ),
            const SizedBox(height: AppConfig.spacingLarge),
            Text(
              'Keine Fehler!',
              style: textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: errors.length,
      itemBuilder: (context, index) {
        final error = errors[index];
        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppConfig.spacingLarge,
            vertical: AppConfig.spacingXSmall,
          ),
          child: ExpansionTile(
            leading: Icon(
              _getSeverityIcon(error.severity),
              color: _getSeverityColor(context, error.severity),
            ),
            title: Text(error.message),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error.itemName != null)
                  Text('Artikel: ${error.itemName}'),
                Text(
                  '${_formatTimestamp(error.timestamp)} • ${error.type.name}',
                ),
              ],
            ),
            children: [
              if (error.technicalDetails != null)
                Padding(
                  padding: const EdgeInsets.all(AppConfig.spacingLarge),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConfig.spacingMedium),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(
                        AppConfig.borderRadiusMedium,
                      ),
                    ),
                    child: Text(
                      error.technicalDetails!,
                      style: textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              if (showActions && error.suggestedActions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppConfig.spacingLarge),
                  child: Wrap(
                    spacing: AppConfig.spacingSmall,
                    children: error.suggestedActions
                        .take(3)
                        .map(
                          (action) => ActionChip(
                            label: Text(action.title),
                            onPressed: () =>
                                onAction?.call(action, error),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  IconData _getSeverityIcon(ErrorSeverity severity) {
    return switch (severity) {
      ErrorSeverity.critical => Icons.error,
      ErrorSeverity.high     => Icons.warning,
      ErrorSeverity.medium   => Icons.info,
      ErrorSeverity.low      => Icons.info_outline,
    };
  }

  Color _getSeverityColor(BuildContext context, ErrorSeverity severity) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (severity) {
      ErrorSeverity.critical => colorScheme.error,
      ErrorSeverity.high     => colorScheme.secondary,
      ErrorSeverity.medium   => colorScheme.primary,
      ErrorSeverity.low      => colorScheme.onSurfaceVariant,
    };
  }

  String _formatTimestamp(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Gerade eben';
    if (diff.inMinutes < 60) return 'Vor ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Vor ${diff.inHours}h';
    return 'Vor ${diff.inDays}d';
  }
}