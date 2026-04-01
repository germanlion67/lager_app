// lib/screens/conflict_resolution_screen.dart
//
// O-004 Batch 2: Alle hardcodierten Farben durch colorScheme ersetzt,
// alle Magic-Number-Abstände/Radien durch AppConfig-Tokens.

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/artikel_model.dart';
import '../services/sync_service.dart';
import '../services/app_log_service.dart';

// ─────────────────────────────────────────────
// ConflictData
// ─────────────────────────────────────────────

/// Repräsentiert einen Sync-Konflikt zwischen lokaler und Remote-Version
class ConflictData {
  final Artikel localVersion;
  final Artikel remoteVersion;
  final String conflictReason;
  final DateTime detectedAt;

  const ConflictData({
    required this.localVersion,
    required this.remoteVersion,
    required this.conflictReason,
    required this.detectedAt,
  });
}

// ─────────────────────────────────────────────
// ConflictResolution Enum
// ─────────────────────────────────────────────

/// Enum für die möglichen Konfliktlösungen
enum ConflictResolution { useLocal, useRemote, merge, skip }

// ─────────────────────────────────────────────
// ConflictResolutionScreen
// ─────────────────────────────────────────────

class ConflictResolutionScreen extends StatefulWidget {
  final List<ConflictData> conflicts;
  final SyncService syncService;

  const ConflictResolutionScreen({
    super.key,
    required this.conflicts,
    required this.syncService,
  });

  @override
  State<ConflictResolutionScreen> createState() =>
      _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState extends State<ConflictResolutionScreen> {
  int _currentConflictIndex = 0;
  final Map<String, ConflictResolution> _resolutions = {};
  final Map<String, Artikel?> _mergedVersions = {};
  bool _isResolving = false;

  ConflictData get _currentConflict =>
      widget.conflicts[_currentConflictIndex];

  // ==================== LOGIK ====================

  void _selectResolution(ConflictResolution resolution) {
    setState(() {
      _resolutions[_currentConflict.localVersion.uuid] = resolution;
      if (resolution == ConflictResolution.merge) {
        _mergedVersions[_currentConflict.localVersion.uuid] =
            _currentConflict.localVersion;
      }
    });
  }

  bool _canProceed() =>
      _resolutions.containsKey(_currentConflict.localVersion.uuid);

  bool _isLastConflict() =>
      _currentConflictIndex == widget.conflicts.length - 1;

  void _nextConflict() {
    if (_isLastConflict()) {
      _resolveAllConflicts();
    } else {
      setState(() => _currentConflictIndex++);
    }
  }

  Future<void> _resolveAllConflicts() async {
    setState(() => _isResolving = true);

    try {
      int resolved = 0;
      int skipped = 0;

      for (final conflict in widget.conflicts) {
        final resolution = _resolutions[conflict.localVersion.uuid];

        if (resolution == null || resolution == ConflictResolution.skip) {
          skipped++;
          continue;
        }

        switch (resolution) {
          case ConflictResolution.useLocal:
            await widget.syncService.applyConflictResolution(
              conflict,
              ConflictResolution.useLocal,
            );
          case ConflictResolution.useRemote:
            await widget.syncService.applyConflictResolution(
              conflict,
              ConflictResolution.useRemote,
            );
          case ConflictResolution.merge:
            final mergedVersion =
                _mergedVersions[conflict.localVersion.uuid];
            await widget.syncService.applyConflictResolution(
              conflict,
              ConflictResolution.merge,
              mergedVersion: mergedVersion,
            );
          case ConflictResolution.skip:
            break;
        }
        resolved++;
      }

      if (!mounted) return;
      Navigator.of(context).pop({'resolved': resolved, 'skipped': skipped});
    } catch (e, st) {
      AppLogService.logger
          .e('Auflösen fehlgeschlagen', error: e, stackTrace: st);
      if (!mounted) return;
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Auflösen der Konflikte: $e'),
          backgroundColor: colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  // ==================== DIALOGE ====================

  void _showMergeDialog() {
    final nav = Navigator.of(context);

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => _MergeDialog(
        localVersion: _currentConflict.localVersion,
        remoteVersion: _currentConflict.remoteVersion,
        onMerged: (mergedArtikel) {
          setState(() {
            _mergedVersions[_currentConflict.localVersion.uuid] =
                mergedArtikel;
            _resolutions[_currentConflict.localVersion.uuid] =
                ConflictResolution.merge;
          });
          nav.pop();
        },
      ),
    );
  }

  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Konfliktauflösung Hilfe'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Konfliktarten:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: AppConfig.spacingSmall),
              Text('• Gleichzeitige Bearbeitung auf verschiedenen Geräten'),
              Text('• Unterschiedliche Zeitstempel bei ähnlichen Änderungen'),
              Text('• Netzwerkfehler während der Synchronisation'),
              SizedBox(height: AppConfig.spacingLarge),
              Text(
                'Lösungsoptionen:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: AppConfig.spacingSmall),
              Text('• Lokale Version: Behält Ihre lokalen Änderungen'),
              Text('• Remote Version: Übernimmt die Server-Version'),
              Text('• Zusammenführen: Kombiniert beide Versionen manuell'),
              Text('• Überspringen: Behält den Konflikt für später'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }

  // ==================== HILFSMETHODEN ====================

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}'
        '.${dateTime.month.toString().padLeft(2, '0')}'
        '.${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}'
        ':${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (widget.conflicts.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Konflikte'),
        ),
        body: Center(
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
                'Keine Konflikte gefunden!',
                style: textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Konflikte (${_currentConflictIndex + 1}/${widget.conflicts.length})',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: _isResolving
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: AppConfig.spacingLarge),
                  Text('Konflikte werden aufgelöst...'),
                ],
              ),
            )
          : _buildConflictBody(context),
    );
  }

  Widget _buildConflictBody(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        LinearProgressIndicator(
          value: (_currentConflictIndex + 1) / widget.conflicts.length,
          backgroundColor: colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.secondary),
        ),
        Padding(
          padding: const EdgeInsets.all(AppConfig.spacingLarge),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConfig.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: colorScheme.secondary),
                      const SizedBox(width: AppConfig.spacingSmall),
                      Expanded(
                        child: Text(
                          'Konflikt bei '
                          '"${_currentConflict.localVersion.name}"',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConfig.spacingSmall),
                  Text(
                    'Grund: ${_currentConflict.conflictReason}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Erkannt: ${_formatDateTime(_currentConflict.detectedAt)}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConfig.spacingLarge,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildVersionCard(
                    context,
                    title: 'Lokale Version',
                    artikel: _currentConflict.localVersion,
                    accentColor: colorScheme.primary,
                    icon: Icons.phone_android,
                    onSelect: () =>
                        _selectResolution(ConflictResolution.useLocal),
                    isSelected:
                        _resolutions[_currentConflict.localVersion.uuid] ==
                            ConflictResolution.useLocal,
                  ),
                ),
                const SizedBox(width: AppConfig.spacingLarge),
                Expanded(
                  child: _buildVersionCard(
                    context,
                    title: 'Remote Version',
                    artikel: _currentConflict.remoteVersion,
                    accentColor: colorScheme.tertiary,
                    icon: Icons.cloud,
                    onSelect: () =>
                        _selectResolution(ConflictResolution.useRemote),
                    isSelected:
                        _resolutions[_currentConflict.localVersion.uuid] ==
                            ConflictResolution.useRemote,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppConfig.spacingLarge),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showMergeDialog,
                  icon: const Icon(Icons.merge_type),
                  label: const Text('Manuell zusammenführen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.tertiary,
                    foregroundColor: colorScheme.onTertiary,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppConfig.buttonPaddingVertical,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppConfig.spacingSmall),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _selectResolution(ConflictResolution.skip),
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Überspringen'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppConfig.buttonPaddingVertical,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConfig.spacingLarge),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _canProceed() ? _nextConflict : null,
                      icon: Icon(
                        _isLastConflict()
                            ? Icons.check
                            : Icons.arrow_forward,
                      ),
                      label: Text(
                        _isLastConflict() ? 'Auflösen' : 'Weiter',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.secondary,
                        foregroundColor: colorScheme.onSecondary,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppConfig.buttonPaddingVertical,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVersionCard(
    BuildContext context, {
    required String title,
    required Artikel artikel,
    required Color accentColor,
    required IconData icon,
    required VoidCallback onSelect,
    required bool isSelected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: isSelected ? 8 : 2,
      color: isSelected
          ? accentColor.withValues(alpha: AppConfig.opacitySubtle)
          : null,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(AppConfig.cardBorderRadiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppConfig.spacingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: accentColor,
                    size: AppConfig.iconSizeMedium,
                  ),
                  const SizedBox(width: AppConfig.spacingSmall),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: accentColor),
                ],
              ),
              const Divider(),
              _buildDetailRow(context, 'Name:', artikel.name),
              _buildDetailRow(context, 'Menge:', artikel.menge.toString()),
              _buildDetailRow(context, 'Ort:', artikel.ort),
              _buildDetailRow(context, 'Fach:', artikel.fach),
              _buildDetailRow(context, 'Beschreibung:', artikel.beschreibung),
              _buildDetailRow(
                context,
                'Aktualisiert:',
                _formatDateTime(
                  DateTime.fromMillisecondsSinceEpoch(artikel.updatedAt),
                ),
              ),
              if (artikel.deviceId != null)
                _buildDetailRow(context, 'Gerät:', artikel.deviceId!),
              if (artikel.bildPfad.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.image,
                      size: AppConfig.iconSizeSmall,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppConfig.spacingXSmall),
                    Text(
                      'Bild vorhanden',
                      style: TextStyle(
                        fontSize: AppConfig.fontSizeSmall,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppConfig.spacingXSmall / 2,
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
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _MergeDialog
// ─────────────────────────────────────────────

class _MergeDialog extends StatefulWidget {
  final Artikel localVersion;
  final Artikel remoteVersion;
  final void Function(Artikel) onMerged;

  const _MergeDialog({
    required this.localVersion,
    required this.remoteVersion,
    required this.onMerged,
  });

  @override
  State<_MergeDialog> createState() => _MergeDialogState();
}

class _MergeDialogState extends State<_MergeDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _mengeController;
  late final TextEditingController _ortController;
  late final TextEditingController _fachController;
  late final TextEditingController _beschreibungController;
  String _selectedBildPfad = '';

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.localVersion.name);
    _mengeController =
        TextEditingController(text: widget.localVersion.menge.toString());
    _ortController =
        TextEditingController(text: widget.localVersion.ort);
    _fachController =
        TextEditingController(text: widget.localVersion.fach);
    _beschreibungController =
        TextEditingController(text: widget.localVersion.beschreibung);
    _selectedBildPfad = widget.localVersion.bildPfad;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mengeController.dispose();
    _ortController.dispose();
    _fachController.dispose();
    _beschreibungController.dispose();
    super.dispose();
  }

  void _saveMergedVersion() {
    try {
      final mergedArtikel = widget.localVersion.copyWith(
        name: _nameController.text.trim(),
        menge: int.tryParse(_mengeController.text) ??
            widget.localVersion.menge,
        ort: _ortController.text.trim(),
        fach: _fachController.text.trim(),
        beschreibung: _beschreibungController.text.trim(),
        bildPfad: _selectedBildPfad,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      widget.onMerged(mergedArtikel);
    } catch (e, st) {
      AppLogService.logger
          .e('Zusammenführen fehlgeschlagen', error: e, stackTrace: st);
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Zusammenführen: $e'),
          backgroundColor: colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(AppConfig.spacingLarge),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.merge_type, color: colorScheme.tertiary),
                const SizedBox(width: AppConfig.spacingSmall),
                Expanded(
                  child: Text(
                    'Versionen zusammenführen',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildMergeField(
                      context,
                      label: 'Name',
                      controller: _nameController,
                      localValue: widget.localVersion.name,
                      remoteValue: widget.remoteVersion.name,
                    ),
                    _buildMergeField(
                      context,
                      label: 'Menge',
                      controller: _mengeController,
                      localValue: widget.localVersion.menge.toString(),
                      remoteValue: widget.remoteVersion.menge.toString(),
                      keyboardType: TextInputType.number,
                    ),
                    _buildMergeField(
                      context,
                      label: 'Ort',
                      controller: _ortController,
                      localValue: widget.localVersion.ort,
                      remoteValue: widget.remoteVersion.ort,
                    ),
                    _buildMergeField(
                      context,
                      label: 'Fach',
                      controller: _fachController,
                      localValue: widget.localVersion.fach,
                      remoteValue: widget.remoteVersion.fach,
                    ),
                    _buildMergeField(
                      context,
                      label: 'Beschreibung',
                      controller: _beschreibungController,
                      localValue: widget.localVersion.beschreibung,
                      remoteValue: widget.remoteVersion.beschreibung,
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppConfig.spacingLarge),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Bild wählen:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: AppConfig.spacingSmall),
                    _buildImageSelectionGroup(context),
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                const SizedBox(width: AppConfig.spacingSmall),
                ElevatedButton(
                  onPressed: _saveMergedVersion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.tertiary,
                    foregroundColor: colorScheme.onTertiary,
                  ),
                  child: const Text('Zusammenführen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMergeField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required String localValue,
    required String remoteValue,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool hasConflict = localValue != remoteValue;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConfig.spacingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (hasConflict)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppConfig.spacingXSmall,
                  ),
                  child: Icon(
                    Icons.warning,
                    size: AppConfig.iconSizeSmall,
                    color: colorScheme.secondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppConfig.spacingXSmall),
          if (hasConflict) ...[
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(AppConfig.spacingSmall),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lokal:',
                            style: TextStyle(
                              fontSize: AppConfig.fontSizeSmall,
                              color: colorScheme.primary,
                            ),
                          ),
                          Text(
                            localValue,
                            style: const TextStyle(
                              fontSize: AppConfig.fontSizeMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppConfig.spacingSmall),
                Expanded(
                  child: Card(
                    color: colorScheme.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(AppConfig.spacingSmall),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Remote:',
                            style: TextStyle(
                              fontSize: AppConfig.fontSizeSmall,
                              color: colorScheme.tertiary,
                            ),
                          ),
                          Text(
                            remoteValue,
                            style: const TextStyle(
                              fontSize: AppConfig.fontSizeMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConfig.spacingSmall),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => controller.text = localValue,
                  icon: const Icon(
                    Icons.phone_android,
                    size: AppConfig.iconSizeSmall,
                  ),
                  label: const Text('Lokal'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => controller.text = remoteValue,
                  icon: const Icon(
                    Icons.cloud,
                    size: AppConfig.iconSizeSmall,
                  ),
                  label: const Text('Remote'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ],
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Bearbeiten oder Version wählen',
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppConfig.spacingMedium,
                vertical: AppConfig.spacingSmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSelectionGroup(BuildContext context) {
    return Column(
      children: [
        _buildImageRadioOption(
          context,
          title: 'Lokal',
          subtitle: widget.localVersion.bildPfad.isNotEmpty
              ? 'Vorhanden'
              : 'Kein Bild',
          isSelected: _selectedBildPfad == widget.localVersion.bildPfad,
          onTap: () => setState(
            () => _selectedBildPfad = widget.localVersion.bildPfad,
          ),
        ),
        const SizedBox(height: AppConfig.spacingSmall),
        _buildImageRadioOption(
          context,
          title: 'Remote',
          subtitle: widget.remoteVersion.bildPfad.isNotEmpty
              ? 'Vorhanden'
              : 'Kein Bild',
          isSelected: _selectedBildPfad == widget.remoteVersion.bildPfad,
          onTap: () => setState(
            () => _selectedBildPfad = widget.remoteVersion.bildPfad,
          ),
        ),
      ],
    );
  }

  Widget _buildImageRadioOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConfig.borderRadiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConfig.spacingLarge,
          vertical: AppConfig.spacingMedium,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: isSelected
                ? AppConfig.strokeWidthMedium
                : AppConfig.strokeWidthThin,
          ),
          borderRadius: BorderRadius.circular(AppConfig.borderRadiusMedium),
          color: isSelected
              ? colorScheme.primary
                  .withValues(alpha: AppConfig.opacitySubtle)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: AppConfig.iconSizeMedium,
              height: AppConfig.iconSizeMedium,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  width: AppConfig.strokeWidthMedium,
                ),
                color: isSelected
                    ? colorScheme.primary
                    : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(
                      Icons.circle,
                      size: AppConfig.fontSizeSmall,
                      color: colorScheme.onPrimary,
                    )
                  : null,
            ),
            const SizedBox(width: AppConfig.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isSelected ? colorScheme.primary : null,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: AppConfig.fontSizeSmall,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}