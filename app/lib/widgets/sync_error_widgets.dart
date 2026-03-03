// lib/widgets/sync_error_widgets.dart

import 'package:flutter/material.dart';
import '../services/sync_error_recovery.dart';

/// Dialog für die Behandlung von Sync-Fehlern
class SyncErrorDialog extends StatelessWidget {
  final SyncError error;
  final Function(RecoveryAction) onAction;

  const SyncErrorDialog({
    super.key,
    required this.error,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _getSeverityIcon(),
            color: _getSeverityColor(),
            size: 24,
          ),
          const SizedBox(width: 8),
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
            // Fehlermeldung
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getSeverityColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getSeverityColor().withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    error.message,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  if (error.itemName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Betroffener Artikel: ${error.itemName}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Technische Details (ausklappbar)
            if (error.technicalDetails != null)
              ExpansionTile(
                title: const Text('Technische Details'),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      error.technicalDetails!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // Empfohlene Aktionen
            const Text(
              'Empfohlene Lösungen:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),

            ...error.suggestedActions.take(3).map((action) => 
              _buildActionTile(action)
            ),
          ],
        ),
      ),
      actions: [
        // Primäre Aktionen
        if (error.suggestedActions.isNotEmpty) ...[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onAction(error.suggestedActions.first);
            },
            child: Text(error.suggestedActions.first.title),
          ),
        ],
        
        // Weitere Optionen
        if (error.suggestedActions.length > 1)
          TextButton(
            onPressed: () => _showAllActions(context),
            child: const Text('Weitere Optionen'),
          ),
        
        // Schließen
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
      leading: Icon(_getActionIcon(action), size: 20),
      title: Text(action.title),
      subtitle: Text(
        action.description,
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () => onAction(action),
    );
  }

  void _showAllActions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alle Lösungsoptionen'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: error.suggestedActions.map((action) => 
              ListTile(
                leading: Icon(_getActionIcon(action)),
                title: Text(action.title),
                subtitle: Text(action.description),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                  onAction(action);
                },
              )
            ).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  IconData _getSeverityIcon() {
    switch (error.severity) {
      case ErrorSeverity.critical:
        return Icons.error;
      case ErrorSeverity.high:
        return Icons.warning;
      case ErrorSeverity.medium:
        return Icons.info;
      case ErrorSeverity.low:
        return Icons.info_outline;
    }
  }

  Color _getSeverityColor() {
    switch (error.severity) {
      case ErrorSeverity.critical:
        return Colors.red[700]!;
      case ErrorSeverity.high:
        return Colors.orange[700]!;
      case ErrorSeverity.medium:
        return Colors.blue[700]!;
      case ErrorSeverity.low:
        return Colors.grey[700]!;
    }
  }

  IconData _getActionIcon(RecoveryAction action) {
    switch (action) {
      case RecoveryAction.retry:
        return Icons.refresh;
      case RecoveryAction.retryLater:
        return Icons.schedule;
      case RecoveryAction.skipItem:
        return Icons.skip_next;
      case RecoveryAction.resolveConflict:
        return Icons.merge_type;
      case RecoveryAction.checkConnection:
        return Icons.wifi;
      case RecoveryAction.checkCredentials:
        return Icons.key;
      case RecoveryAction.relogin:
        return Icons.login;
      case RecoveryAction.clearCache:
        return Icons.clear_all;
      case RecoveryAction.checkStorage:
        return Icons.storage;
      case RecoveryAction.adjustTimeout:
        return Icons.timer;
      case RecoveryAction.contactAdmin:
        return Icons.support_agent;
      case RecoveryAction.reportBug:
        return Icons.bug_report;
      case RecoveryAction.viewLogs:
        return Icons.article;
    }
  }

  /// Zeigt den Error Dialog an
  static Future<void> show(
    BuildContext context,
    SyncError error,
    Function(RecoveryAction) onAction,
  ) {
    return showDialog(
      context: context,
      builder: (context) => SyncErrorDialog(
        error: error,
        onAction: onAction,
      ),
    );
  }
}

/// Kompakte Error-Anzeige für die AppBar oder als Banner
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

    final criticalErrors = errors.where((e) => e.severity == ErrorSeverity.critical).length;
    final totalErrors = errors.length;
    
    return Container(
      margin: const EdgeInsets.all(8),
      child: Material(
        color: criticalErrors > 0 ? Colors.red[100] : Colors.orange[100],
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  criticalErrors > 0 ? Icons.error : Icons.warning,
                  color: criticalErrors > 0 ? Colors.red[700] : Colors.orange[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        criticalErrors > 0 
                          ? 'Kritische Sync-Fehler ($criticalErrors)'
                          : 'Sync-Probleme ($totalErrors)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: criticalErrors > 0 ? Colors.red[700] : Colors.orange[700],
                        ),
                      ),
                      Text(
                        criticalErrors > 0
                          ? 'Synchronisation blockiert - Aktion erforderlich'
                          : 'Einige Artikel konnten nicht synchronisiert werden',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
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

/// Error Recovery Progress Dialog
class ErrorRecoveryProgressDialog extends StatefulWidget {
  final List<SyncError> errors;
  final Future<void> Function(SyncError) retryFunction;

  const ErrorRecoveryProgressDialog({
    super.key,
    required this.errors,
    required this.retryFunction,
  });

  @override
  State<ErrorRecoveryProgressDialog> createState() => _ErrorRecoveryProgressDialogState();

  static Future<BatchRecoveryResult?> show(
    BuildContext context,
    List<SyncError> errors,
    Future<void> Function(SyncError) retryFunction,
  ) {
    return showDialog<BatchRecoveryResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ErrorRecoveryProgressDialog(
        errors: errors,
        retryFunction: retryFunction,
      ),
    );
  }
}

class _ErrorRecoveryProgressDialogState extends State<ErrorRecoveryProgressDialog> {
  late SyncErrorRecoveryService _recoveryService;
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
          setState(() {
            _currentIndex++;
            _currentStatus = 'Bearbeite: ${error.itemName ?? error.message}';
          });
          await widget.retryFunction(error);
        },
      );

      setState(() {
        _result = result;
        _isRunning = false;
        _currentStatus = 'Wiederherstellung abgeschlossen';
      });

      // Auto-close nach 3 Sekunden
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        Navigator.of(context).pop(_result);
      }
    } catch (e) {
      setState(() {
        _isRunning = false;
        _currentStatus = 'Fehler bei der Wiederherstellung: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.errors.isNotEmpty ? _currentIndex / widget.errors.length : 0.0;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.healing, color: Colors.blue),
          SizedBox(width: 8),
          Text('Fehler-Wiederherstellung'),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentStatus),
            const SizedBox(height: 16),
            
            LinearProgressIndicator(value: _isRunning ? progress : 1.0),
            const SizedBox(height: 8),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_currentIndex/${widget.errors.length}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            
            if (_result != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildResultChip(
                    'Erfolgreich',
                    _result!.successful.toString(),
                    Colors.green,
                  ),
                  _buildResultChip(
                    'Fehlgeschlagen',
                    _result!.failed.toString(),
                    Colors.red,
                  ),
                  _buildResultChip(
                    'Übersprungen',
                    _result!.skipped.toString(),
                    Colors.grey,
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

  Widget _buildResultChip(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }
}

/// Error List Widget für detaillierte Fehleranzeige
class SyncErrorList extends StatelessWidget {
  final List<SyncError> errors;
  final Function(RecoveryAction, SyncError)? onAction;
  final bool showActions;

  const SyncErrorList({
    super.key,
    required this.errors,
    this.onAction,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('Keine Fehler!', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: errors.length,
      itemBuilder: (context, index) {
        final error = errors[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ExpansionTile(
            leading: Icon(
              _getSeverityIcon(error.severity),
              color: _getSeverityColor(error.severity),
            ),
            title: Text(error.message),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error.itemName != null)
                  Text('Artikel: ${error.itemName}'),
                Text('${_formatTimestamp(error.timestamp)} • ${error.type.name}'),
              ],
            ),
            children: [
              if (error.technicalDetails != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      error.technicalDetails!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              
              if (showActions && error.suggestedActions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    children: error.suggestedActions.take(3).map((action) =>
                      ActionChip(
                        label: Text(action.title),
                        onPressed: () => onAction?.call(action, error),
                      )
                    ).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  IconData _getSeverityIcon(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.critical:
        return Icons.error;
      case ErrorSeverity.high:
        return Icons.warning;
      case ErrorSeverity.medium:
        return Icons.info;
      case ErrorSeverity.low:
        return Icons.info_outline;
    }
  }

  Color _getSeverityColor(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.critical:
        return Colors.red;
      case ErrorSeverity.high:
        return Colors.orange;
      case ErrorSeverity.medium:
        return Colors.blue;
      case ErrorSeverity.low:
        return Colors.grey;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) return 'Gerade eben';
    if (diff.inMinutes < 60) return 'Vor ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Vor ${diff.inHours}h';
    return 'Vor ${diff.inDays}d';
  }
}