// lib/widgets/sync_progress_widgets.dart
//
// O-004: Alle hardcodierten Farben durch colorScheme ersetzt,
// alle Magic-Number-Abstände/Radien/Sizes durch AppConfig-Tokens.

import 'package:flutter/material.dart';

import '../config/app_config.dart';
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
    final op = operation;
    if (op == null || !op.isActive) return const SizedBox.shrink();

    final color = _getStatusColor(context, op);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConfig.spacingMedium,
          vertical: AppConfig.spacingSmall - 2, // 6.0 — kein exakter Token, nächster Wert
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppConfig.opacityLight),
          borderRadius: BorderRadius.circular(AppConfig.borderRadiusXLarge),
          border: Border.all(color: color, width: AppConfig.strokeWidthThin),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: AppConfig.iconSizeSmall,
              height: AppConfig.iconSizeSmall,
              child: CircularProgressIndicator(
                value: op.progress,
                strokeWidth: AppConfig.strokeWidthMedium,
                valueColor: AlwaysStoppedAnimation(color),
                backgroundColor: color.withValues(alpha: AppConfig.opacityMedium),
              ),
            ),
            const SizedBox(width: AppConfig.spacingSmall),
            Text(
              '${(op.progress * 100).toInt()}%',
              style: TextStyle(
                color: color,
                fontSize: AppConfig.fontSizeSmall,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(BuildContext context, SyncOperation op) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (op.status) {
      SyncStatus.error      => colorScheme.error,
      SyncStatus.completed  => colorScheme.tertiary,       // Grün-Semantik via Seed
      SyncStatus.connecting => colorScheme.secondary,      // Warn-/Orange-Semantik
      _                     => colorScheme.primary,
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
    final op = operation;
    if (op == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final statusColor = _getStatusColor(context, op);

    return Card(
      margin: const EdgeInsets.all(AppConfig.spacingLarge),
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(op),
                  color: statusColor,
                  size: AppConfig.iconSizeLarge,
                ),
                const SizedBox(width: AppConfig.spacingSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        op.name,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        op.statusText,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
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

            const SizedBox(height: AppConfig.spacingLarge),

            LinearProgressIndicator(
              value: op.progress,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(statusColor),
            ),

            const SizedBox(height: AppConfig.spacingSmall),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${stats.processedItems}/${stats.totalItems} Artikel',
                  style: textTheme.bodySmall,
                ),
                Text(
                  '${(op.progress * 100).toInt()}%',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (op.currentItem != null) ...[
              const SizedBox(height: AppConfig.spacingSmall),
              Text(
                'Aktuell: ${op.currentItem}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            if (stats.totalItems > 0) ...[
              const SizedBox(height: AppConfig.spacingLarge),
              _buildStatsRow(context),
            ],

            if (!op.isActive) ...[
              const SizedBox(height: AppConfig.spacingLarge),
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

  Widget _buildStatsRow(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        _buildStatChip(
          context,
          icon: Icons.upload,
          label: 'Hochgeladen',
          value: stats.uploadedItems.toString(),
          color: colorScheme.tertiary,
        ),
        const SizedBox(width: AppConfig.spacingSmall),
        _buildStatChip(
          context,
          icon: Icons.download,
          label: 'Heruntergeladen',
          value: stats.downloadedItems.toString(),
          color: colorScheme.primary,
        ),
        if (stats.conflictItems > 0) ...[
          const SizedBox(width: AppConfig.spacingSmall),
          _buildStatChip(
            context,
            icon: Icons.warning,
            label: 'Konflikte',
            value: stats.conflictItems.toString(),
            color: colorScheme.secondary,
          ),
        ],
        if (stats.errorItems > 0) ...[
          const SizedBox(width: AppConfig.spacingSmall),
          _buildStatChip(
            context,
            icon: Icons.error,
            label: 'Fehler',
            value: stats.errorItems.toString(),
            color: colorScheme.error,
          ),
        ],
      ],
    );
  }

  Widget _buildStatChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacingSmall,
        vertical: AppConfig.spacingXSmall,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppConfig.opacitySubtle),
        borderRadius: BorderRadius.circular(AppConfig.cardBorderRadiusLarge),
        border: Border.all(
          color: color.withValues(alpha: AppConfig.opacityMedium),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppConfig.iconSizeXSmall, color: color),
          const SizedBox(width: AppConfig.spacingXSmall),
          Text(
            value,
            style: TextStyle(
              fontSize: AppConfig.fontSizeSmall,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

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

  Color _getStatusColor(BuildContext context, SyncOperation op) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (op.status) {
      SyncStatus.error      => colorScheme.error,
      SyncStatus.completed  => colorScheme.tertiary,
      SyncStatus.cancelled  => colorScheme.onSurfaceVariant,
      SyncStatus.connecting => colorScheme.secondary,
      _                     => colorScheme.primary,
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
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final op = _currentOperation;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Row(
        children: [
          if (op?.isActive == true)
            const SizedBox(
              width: AppConfig.iconSizeMedium,
              height: AppConfig.iconSizeMedium,
              child: CircularProgressIndicator(
                strokeWidth: AppConfig.strokeWidthMedium,
              ),
            )
          else if (op?.isCompleted == true)
            Icon(
              Icons.check_circle,
              color: colorScheme.tertiary,
              size: AppConfig.iconSizeMedium,
            )
          else if (op?.isError == true)
            Icon(
              Icons.error,
              color: colorScheme.error,
              size: AppConfig.iconSizeMedium,
            ),
          const SizedBox(width: AppConfig.spacingSmall),
          Expanded(child: Text(widget.title)),
        ],
      ),
      content: SizedBox(
        width: AppConfig.dialogContentWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (op != null) ...[
              Text(
                op.statusText,
                style: textTheme.titleSmall,
              ),
              const SizedBox(height: AppConfig.spacingLarge),
              LinearProgressIndicator(
                value: op.progress,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: AppConfig.spacingSmall),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_currentStats.processedItems}/${_currentStats.totalItems}',
                    style: textTheme.bodySmall,
                  ),
                  Text(
                    '${(op.progress * 100).toInt()}%',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
              if (op.currentItem != null) ...[
                const SizedBox(height: AppConfig.spacingSmall),
                Text(
                  op.currentItem!,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (op.message != null) ...[
                const SizedBox(height: AppConfig.spacingSmall),
                Text(
                  op.message!,
                  style: textTheme.bodySmall?.copyWith(
                    color: op.isError
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
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
    final op = operation;
    final isActive = op?.isActive == true;
    final colorScheme = Theme.of(context).colorScheme;

    return FloatingActionButton(
      onPressed: isActive ? null : onPressed,
      tooltip: tooltip,
      backgroundColor: isActive
          ? colorScheme.onSurfaceVariant
          : colorScheme.primary,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isActive)
            SizedBox(
              width: AppConfig.progressIndicatorSize,
              height: AppConfig.progressIndicatorSize,
              child: CircularProgressIndicator(
                value: op!.progress,
                strokeWidth: AppConfig.strokeWidthThick,
                valueColor: AlwaysStoppedAnimation(colorScheme.onPrimary),
                backgroundColor: colorScheme.onPrimary
                    .withValues(alpha: AppConfig.opacityMedium),
              ),
            ),
          Icon(
            isActive ? Icons.hourglass_empty : Icons.sync,
            color: colorScheme.onPrimary,
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
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sync_alt,
                  size: AppConfig.iconSizeLarge,
                  color: colorScheme.onSurface,
                ),
                const SizedBox(width: AppConfig.spacingSmall),
                Text(
                  'Synchronisationsdetails',
                  style: textTheme.titleLarge?.copyWith(
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
                        const SizedBox(height: AppConfig.spacingLarge),
                        if (widget.progressService.operationHistory
                            .isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Verlauf',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppConfig.spacingSmall),
                          ...widget
                              .progressService.operationHistory.reversed
                              .take(5)
                              .map(
                                (op) => _buildHistoryItem(context, op),
                              ),
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

  Widget _buildHistoryItem(BuildContext context, SyncOperation operation) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      leading: Icon(
        operation.isCompleted ? Icons.check_circle : Icons.error,
        color: operation.isCompleted
            ? colorScheme.tertiary
            : colorScheme.error,
      ),
      title: Text(operation.name),
      subtitle: Text(
        '${operation.statusText} • ${_formatDuration(operation.duration)}',
      ),
      trailing: Text(
        '${(operation.progress * 100).toInt()}%',
        style: textTheme.bodySmall,
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