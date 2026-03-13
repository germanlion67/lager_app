// lib/widgets/sync_progress_widgets.dart

import 'package:flutter/material.dart';

import '../services/sync_progress_service.dart';

/// Kompakte Fortschrittsanzeige für die AppBar.
class SyncProgressIndicator extends StatelessWidget {
  final SyncOperation? operation;
  final SyncStats stats;
  final VoidCallback? onTap;

  const SyncProgressIndicator({
    super.key,
    required this.operation,
    required this.stats,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Fix: früher return — kein Zugriff auf operation! nötig
    final op = operation;
    if (op == null || !op.isActive) return const SizedBox.shrink();

    final color = _getStatusColor(op);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: op.progress,
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(color),
                backgroundColor: color.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(op.progress * 100).toInt()}%',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fix: operation als Parameter — kein operation!-Zugriff auf nullable field
  Color _getStatusColor(SyncOperation op) {
    return switch (op.status) {
      SyncStatus.error      => Colors.red,
      SyncStatus.completed  => Colors.green,
      SyncStatus.connecting => Colors.orange,
      _                     => Colors.blue,
    };
  }
}

/// Detaillierte Fortschrittsanzeige als Card.
class DetailedSyncProgressCard extends StatelessWidget {
  final SyncOperation? operation;
  final SyncStats stats;
  final VoidCallback? onCancel;
  final VoidCallback? onViewDetails;

  const DetailedSyncProgressCard({
    super.key,
    required this.operation,
    required this.stats,
    this.onCancel,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    // Fix: lokale Variable — kein wiederholtes operation! im build-Tree
    final op = operation;
    if (op == null) return const SizedBox.shrink();

    final statusColor = _getStatusColor(op);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(op),
                  color: statusColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        op.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        op.statusText,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (op.isActive && onCancel != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onCancel,
                    tooltip: 'Abbrechen',
                  ),
              ],
            ),

            const SizedBox(height: 16),

            LinearProgressIndicator(
              value: op.progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation(statusColor),
            ),

            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${stats.processedItems}/${stats.totalItems} Artikel',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '${(op.progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (op.currentItem != null) ...[
              const SizedBox(height: 8),
              Text(
                'Aktuell: ${op.currentItem}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            if (stats.totalItems > 0) ...[
              const SizedBox(height: 16),
              _buildStatsRow(),
            ],

            if (!op.isActive) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onViewDetails != null)
                    TextButton.icon(
                      onPressed: onViewDetails,
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Details'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatChip(
          icon: Icons.upload,
          label: 'Hochgeladen',
          value: stats.uploadedItems.toString(),
          color: Colors.green,
        ),
        const SizedBox(width: 8),
        _buildStatChip(
          icon: Icons.download,
          label: 'Heruntergeladen',
          value: stats.downloadedItems.toString(),
          color: Colors.blue,
        ),
        if (stats.conflictItems > 0) ...[
          const SizedBox(width: 8),
          _buildStatChip(
            icon: Icons.warning,
            label: 'Konflikte',
            value: stats.conflictItems.toString(),
            color: Colors.orange,
          ),
        ],
        if (stats.errorItems > 0) ...[
          const SizedBox(width: 8),
          _buildStatChip(
            icon: Icons.error,
            label: 'Fehler',
            value: stats.errorItems.toString(),
            color: Colors.red,
          ),
        ],
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Fix: operation als Parameter + Dart 3 switch-expression —
  // exhaustive, kein default nötig
  IconData _getStatusIcon(SyncOperation op) {
    return switch (op.status) {
      SyncStatus.idle         => Icons.pause_circle,
      SyncStatus.initializing => Icons.settings,
      SyncStatus.connecting   => Icons.wifi,
      SyncStatus.analyzing    => Icons.analytics,
      SyncStatus.downloading  => Icons.download,
      SyncStatus.uploading    => Icons.upload,
      SyncStatus.processing   => Icons.settings,
      SyncStatus.resolving    => Icons.merge_type,
      SyncStatus.finalizing   => Icons.check_circle_outline,
      SyncStatus.completed    => Icons.check_circle,
      SyncStatus.error        => Icons.error,
      SyncStatus.cancelled    => Icons.cancel,
    };
  }

  // Fix: operation als Parameter — kein operation!-Zugriff auf nullable field
  Color _getStatusColor(SyncOperation op) {
    return switch (op.status) {
      SyncStatus.error      => Colors.red,
      SyncStatus.completed  => Colors.green,
      SyncStatus.cancelled  => Colors.grey,
      SyncStatus.connecting => Colors.orange,
      _                     => Colors.blue,
    };
  }
}

/// Modal Progress Dialog für Sync-Operationen.
class SyncProgressDialog extends StatefulWidget {
  final SyncProgressService progressService;
  final String title;
  final bool cancellable;
  final VoidCallback? onCancel;

  const SyncProgressDialog({
    super.key,
    required this.progressService,
    this.title = 'Synchronisiere...',
    this.cancellable = true,
    this.onCancel,
  });

  @override
  State<SyncProgressDialog> createState() =>
      _SyncProgressDialogState();

  /// Zeigt den Progress Dialog an.
  static Future<T?> show<T>({
    required BuildContext context,
    required SyncProgressService progressService,
    String title = 'Synchronisiere...',
    bool cancellable = true,
    VoidCallback? onCancel,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      // Fix: Dialog-eigenen ctx verwenden — nicht äußeren context
      builder: (ctx) => SyncProgressDialog(
        progressService: progressService,
        title: title,
        cancellable: cancellable,
        onCancel: onCancel,
      ),
    );
  }
}

class _SyncProgressDialogState extends State<SyncProgressDialog> {
  // Fix: SyncOperation? statt late SyncOperation? —
  // late auf nullable ist sinnlos, direkt nullable initialisieren
  SyncOperation? _currentOperation;
  late SyncStats _currentStats;

  @override
  void initState() {
    super.initState();
    _currentOperation = widget.progressService.currentOperation;
    _currentStats = widget.progressService.stats;
    widget.progressService.addListener(_onProgressUpdate);
  }

  @override
  void dispose() {
    widget.progressService.removeListener(_onProgressUpdate);
    super.dispose();
  }

  void _onProgressUpdate() {
    if (!mounted) return;

    setState(() {
      _currentOperation = widget.progressService.currentOperation;
      _currentStats = widget.progressService.stats;
    });

    final op = _currentOperation;
    if (op != null && (op.isCompleted || op.isError)) {
      Future.delayed(const Duration(seconds: 2), () {
        // Fix: mounted-Guard nach Future.delayed
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fix: lokale Variable — kein wiederholtes _currentOperation! im build-Tree
    final op = _currentOperation;

    return AlertDialog(
      title: Row(
        children: [
          if (op?.isActive == true)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (op?.isCompleted == true)
            const Icon(Icons.check_circle,
                color: Colors.green, size: 20,)
          else if (op?.isError == true)
            const Icon(Icons.error, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.title)),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (op != null) ...[
              Text(
                op.statusText,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: op.progress,
                backgroundColor: Colors.grey[300],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_currentStats.processedItems}/${_currentStats.totalItems}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '${(op.progress * 100).toInt()}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              if (op.currentItem != null) ...[
                const SizedBox(height: 8),
                Text(
                  op.currentItem!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (op.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  op.message!,
                  style: TextStyle(
                    fontSize: 12,
                    color: op.isError
                        ? Colors.red
                        : Colors.grey[600],
                  ),
                ),
              ],
            ] else ...[
              const Text('Initialisiere...'),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.cancellable && op?.isActive == true)
          TextButton(
            onPressed: () {
              widget.onCancel?.call();
              Navigator.of(context).pop();
            },
            child: const Text('Abbrechen'),
          ),
        if (op?.isCompleted == true || op?.isError == true)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
      ],
    );
  }
}

/// Floating Action Button mit Progress Indicator.
class SyncProgressFab extends StatelessWidget {
  final SyncOperation? operation;
  final VoidCallback? onPressed;
  final String tooltip;

  const SyncProgressFab({
    super.key,
    required this.operation,
    required this.onPressed,
    this.tooltip = 'Synchronisieren',
  });

  @override
  Widget build(BuildContext context) {
    // Fix: lokale Variable — kein wiederholtes operation?. im build-Tree
    final op = operation;
    final isActive = op?.isActive == true;

    return FloatingActionButton(
      onPressed: isActive ? null : onPressed,
      tooltip: tooltip,
      backgroundColor: isActive ? Colors.grey : Colors.blue,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isActive)
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                // Fix: op statt operation! — kein Bang-Operator nötig
                value: op!.progress,
                strokeWidth: 3,
                valueColor:
                    const AlwaysStoppedAnimation(Colors.white),
                backgroundColor:
                    Colors.white.withValues(alpha: 0.3),
              ),
            ),
          Icon(
            isActive ? Icons.hourglass_empty : Icons.sync,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

/// Bottom Sheet für detaillierte Sync-Informationen.
class SyncProgressBottomSheet extends StatefulWidget {
  final SyncProgressService progressService;

  const SyncProgressBottomSheet({
    super.key,
    required this.progressService,
  });

  @override
  State<SyncProgressBottomSheet> createState() =>
      _SyncProgressBottomSheetState();

  static Future<void> show(
    BuildContext context,
    SyncProgressService progressService,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // Fix: Dialog-eigenen ctx verwenden — nicht äußeren context
      builder: (ctx) => SyncProgressBottomSheet(
        progressService: progressService,
      ),
    );
  }
}

class _SyncProgressBottomSheetState
    extends State<SyncProgressBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Fix: Container → SizedBox — kein Styling nötig, nur Größe
      height: MediaQuery.of(context).size.height * 0.7,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_alt, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Synchronisationsdetails',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),

            ListenableBuilder(
              listenable: widget.progressService,
              builder: (context, _) {
                final operation =
                    widget.progressService.currentOperation;
                final stats = widget.progressService.stats;

                return Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (operation != null)
                          DetailedSyncProgressCard(
                            operation: operation,
                            stats: stats,
                          ),
                        const SizedBox(height: 16),
                        if (widget.progressService.operationHistory
                            .isNotEmpty) ...[
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Verlauf',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...widget
                              .progressService.operationHistory.reversed
                              .take(5)
                              .map(_buildHistoryItem),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(SyncOperation operation) {
    return ListTile(
      leading: Icon(
        operation.isCompleted ? Icons.check_circle : Icons.error,
        color: operation.isCompleted ? Colors.green : Colors.red,
      ),
      title: Text(operation.name),
      subtitle: Text(
        '${operation.statusText} • ${_formatDuration(operation.duration)}',
      ),
      trailing: Text(
        '${(operation.progress * 100).toInt()}%',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    }
    return '${duration.inSeconds}s';
  }
}