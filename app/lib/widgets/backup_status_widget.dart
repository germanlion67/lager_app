// lib/widgets/backup_status_widget.dart
//
// M-008: Zeigt den Backup-Status als Card im Settings-Screen.
// Farbcodierung: Grün (<24h), Gelb (1-3 Tage), Rot (>3 Tage/Fehler).

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/backup_status_service.dart';

class BackupStatusWidget extends StatefulWidget {
  const BackupStatusWidget({super.key});

  @override
  State<BackupStatusWidget> createState() => _BackupStatusWidgetState();
}

class _BackupStatusWidgetState extends State<BackupStatusWidget> {
  BackupStatus _status = BackupStatus.unknown;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final status = await BackupStatusService.fetchStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.backup, color: colorScheme.primary),
                const SizedBox(width: AppConfig.spacingSmall),
                Text(
                  'Backup-Status',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _isLoading ? null : _loadStatus,
                  icon: _isLoading
                      ? SizedBox(
                          width: AppConfig.iconSizeSmall,
                          height: AppConfig.iconSizeSmall,
                          child: CircularProgressIndicator(
                            strokeWidth: AppConfig.strokeWidthMedium,
                            color: colorScheme.primary,
                          ),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: 'Status aktualisieren',
                  iconSize: AppConfig.iconSizeMedium,
                ),
              ],
            ),
            const SizedBox(height: AppConfig.spacingMedium),

            // Inhalt
            if (_isLoading)
              _buildLoadingState(colorScheme)
            else if (_errorMessage != null)
              _buildErrorState(colorScheme, textTheme)
            else if (_status.status == 'unknown')
              _buildUnknownState(colorScheme, textTheme)
            else
              _buildStatusContent(colorScheme, textTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(AppConfig.spacingMedium),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConfig.borderRadiusMedium),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: AppConfig.iconSizeSmall,
            height: AppConfig.iconSizeSmall,
            child: CircularProgressIndicator(
              strokeWidth: AppConfig.strokeWidthMedium,
            ),
          ),
          SizedBox(width: AppConfig.spacingSmall),
          Text('Lade Backup-Status...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(AppConfig.spacingMedium),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppConfig.borderRadiusMedium),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: AppConfig.opacityMedium),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: AppConfig.spacingSmall),
          Expanded(
            child: Text(
              'Backup-Status konnte nicht geladen werden',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnknownState(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(AppConfig.spacingMedium),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppConfig.borderRadiusMedium),
        border: Border.all(
          color: colorScheme.secondary
              .withValues(alpha: AppConfig.opacityMedium),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppConfig.spacingSmall),
          Expanded(
            child: Text(
              'Kein Backup-Status verfügbar.\n'
              'Stelle sicher, dass der Backup-Container läuft und '
              'last_backup.json in pb_public erreichbar ist.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusContent(ColorScheme colorScheme, TextTheme textTheme) {
    final Color statusBgColor;
    final Color statusBorderColor;
    final Color statusContentColor;
    final IconData statusIcon;
    final String statusLabel;

    switch (_status.ageCategory) {
      case BackupAge.fresh:
        statusBgColor = colorScheme.tertiaryContainer;
        statusBorderColor = colorScheme.tertiary
            .withValues(alpha: AppConfig.opacityMedium);
        statusContentColor = colorScheme.onTertiaryContainer;
        statusIcon = Icons.check_circle;
        statusLabel = 'Backup aktuell';
      case BackupAge.aging:
        statusBgColor = colorScheme.secondaryContainer;
        statusBorderColor = colorScheme.secondary
            .withValues(alpha: AppConfig.opacityMedium);
        statusContentColor = colorScheme.onSecondaryContainer;
        statusIcon = Icons.warning_amber;
        statusLabel = 'Backup wird älter';
      case BackupAge.critical:
        statusBgColor = colorScheme.errorContainer;
        statusBorderColor = colorScheme.error
            .withValues(alpha: AppConfig.opacityMedium);
        statusContentColor = colorScheme.onErrorContainer;
        statusIcon = Icons.error;
        statusLabel = _status.isError ? 'Backup fehlgeschlagen' : 'Backup veraltet';
    }

    return Column(
      children: [
        // Status-Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppConfig.spacingMedium),
          decoration: BoxDecoration(
            color: statusBgColor,
            borderRadius: BorderRadius.circular(AppConfig.borderRadiusMedium),
            border: Border.all(color: statusBorderColor),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: statusContentColor),
              const SizedBox(width: AppConfig.spacingSmall),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabel,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusContentColor,
                      ),
                    ),
                    Text(
                      'Letztes Backup: ${_status.ageText}',
                      style: textTheme.bodySmall?.copyWith(
                        color: statusContentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppConfig.spacingMedium),

        // Detail-Zeilen
        _buildDetailRow(textTheme, colorScheme, 'Zeitpunkt', _status.timestamp),
        _buildDetailRow(textTheme, colorScheme, 'Datei', _status.file),
        _buildDetailRow(textTheme, colorScheme, 'Größe', _status.size),
        _buildDetailRow(
          textTheme,
          colorScheme,
          'Backups',
          '${_status.backupCount} vorhanden (${_status.keepDays} Tage Rotation)',
        ),

        // Fehler-Details
        if (_status.isError && _status.error.isNotEmpty) ...[
          const SizedBox(height: AppConfig.spacingSmall),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConfig.spacingSmall),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius:
                  BorderRadius.circular(AppConfig.borderRadiusMedium),
            ),
            child: Text(
              'Fehler: ${_status.error}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(
    TextTheme textTheme,
    ColorScheme colorScheme,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppConfig.spacingXSmall,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppConfig.infoLabelWidthSmall,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}