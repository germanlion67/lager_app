// lib/screens/conflict_resolution_screen.dart

import 'package:flutter/material.dart';
import '../models/artikel_model.dart';
import '../services/sync_service.dart';
import '../services/artikel_db_service.dart';
import 'dart:io';

/// Repräsentiert einen Sync-Konflikt zwischen lokaler und Remote-Version
class ConflictData {
  final Artikel localVersion;
  final Artikel remoteVersion;
  final String conflictReason;
  final DateTime detectedAt;

  ConflictData({
    required this.localVersion,
    required this.remoteVersion,
    required this.conflictReason,
    required this.detectedAt,
  });
}

/// Enum für die möglichen Konfliktlösungen
enum ConflictResolution {
  useLocal,
  useRemote,
  merge,
  skip
}

class ConflictResolutionScreen extends StatefulWidget {
  final List<ConflictData> conflicts;
  final SyncService syncService;

  const ConflictResolutionScreen({
    super.key,
    required this.conflicts,
    required this.syncService,
  });

  @override
  State<ConflictResolutionScreen> createState() => _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState extends State<ConflictResolutionScreen> {
  int currentConflictIndex = 0;
  Map<String, ConflictResolution> resolutions = {};
  Map<String, Artikel?> mergedVersions = {};
  bool isResolving = false;

  ConflictData get currentConflict => widget.conflicts[currentConflictIndex];
  
  @override
  Widget build(BuildContext context) {
    if (widget.conflicts.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Konflikte'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 64, color: Colors.green),
              SizedBox(height: 16),
              Text('Keine Konflikte gefunden!', style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Konflikte (${currentConflictIndex + 1}/${widget.conflicts.length})'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress Indicator
          LinearProgressIndicator(
            value: (currentConflictIndex + 1) / widget.conflicts.length,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
          
          // Conflict Info Card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Konflikt bei "${currentConflict.localVersion.name}"',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Grund: ${currentConflict.conflictReason}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      'Erkannt: ${_formatDateTime(currentConflict.detectedAt)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Version Comparison
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  // Local Version
                  Expanded(
                    child: _buildVersionCard(
                      title: 'Lokale Version',
                      artikel: currentConflict.localVersion,
                      color: Colors.blue,
                      icon: Icons.phone_android,
                      onSelect: () => _selectResolution(ConflictResolution.useLocal),
                      isSelected: resolutions[currentConflict.localVersion.uuid] == ConflictResolution.useLocal,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Remote Version
                  Expanded(
                    child: _buildVersionCard(
                      title: 'Remote Version',
                      artikel: currentConflict.remoteVersion,
                      color: Colors.green,
                      icon: Icons.cloud,
                      onSelect: () => _selectResolution(ConflictResolution.useRemote),
                      isSelected: resolutions[currentConflict.localVersion.uuid] == ConflictResolution.useRemote,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Merge Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showMergeDialog(),
                    icon: const Icon(Icons.merge_type),
                    label: const Text('Manuell zusammenführen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    // Skip Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _selectResolution(ConflictResolution.skip),
                        icon: const Icon(Icons.skip_next),
                        label: const Text('Überspringen'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Next/Resolve Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _canProceed() ? _nextConflict : null,
                        icon: Icon(_isLastConflict() ? Icons.check : Icons.arrow_forward),
                        label: Text(_isLastConflict() ? 'Auflösen' : 'Weiter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionCard({
    required String title,
    required Artikel artikel,
    required Color color,
    required IconData icon,
    required VoidCallback onSelect,
    required bool isSelected,
  }) {
    return Card(
      elevation: isSelected ? 8 : 2,
        color: isSelected ? color.withValues(alpha: 0.1) : null,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: color),
                ],
              ),
              const Divider(),
              
              // Article Details
              _buildDetailRow('Name:', artikel.name),
              _buildDetailRow('Menge:', artikel.menge.toString()),
              _buildDetailRow('Ort:', artikel.ort),
              _buildDetailRow('Fach:', artikel.fach),
              _buildDetailRow('Beschreibung:', artikel.beschreibung),
              _buildDetailRow('Aktualisiert:', _formatDateTime(DateTime.fromMillisecondsSinceEpoch(artikel.updatedAt))),
              if (artikel.deviceId != null)
                _buildDetailRow('Gerät:', artikel.deviceId!),
              
              // Image Info
              if (artikel.bildPfad.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.image, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    const Text('Bild', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    if (artikel.bildPfad.isNotEmpty && File(artikel.bildPfad).existsSync())
                      const Icon(Icons.check, size: 16, color: Colors.green),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _selectResolution(ConflictResolution resolution) {
    setState(() {
      resolutions[currentConflict.localVersion.uuid] = resolution;
      if (resolution == ConflictResolution.merge) {
        // Initialize merged version with local as base
        mergedVersions[currentConflict.localVersion.uuid] = currentConflict.localVersion;
      }
    });
  }

  bool _canProceed() {
    return resolutions.containsKey(currentConflict.localVersion.uuid);
  }

  bool _isLastConflict() {
    return currentConflictIndex == widget.conflicts.length - 1;
  }

  void _nextConflict() {
    if (_isLastConflict()) {
      _resolveAllConflicts();
    } else {
      setState(() {
        currentConflictIndex++;
      });
    }
  }

  Future<void> _resolveAllConflicts() async {
    setState(() {
      isResolving = true;
    });

    try {
      int resolved = 0;
      int skipped = 0;

      for (final conflict in widget.conflicts) {
        final resolution = resolutions[conflict.localVersion.uuid];
        
        if (resolution == null || resolution == ConflictResolution.skip) {
          skipped++;
          continue;
        }

        switch (resolution) {
          case ConflictResolution.useLocal:
            await _applyLocalVersion(conflict);
            break;
          case ConflictResolution.useRemote:
            await _applyRemoteVersion(conflict);
            break;
          case ConflictResolution.merge:
            await _applyMergedVersion(conflict);
            break;
          case ConflictResolution.skip:
            // Already handled above
            break;
        }
        resolved++;
      }

      if (mounted) {
        Navigator.of(context).pop({
          'resolved': resolved,
          'skipped': skipped,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Auflösen der Konflikte: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isResolving = false;
        });
      }
    }
  }

  Future<void> _applyLocalVersion(ConflictData conflict) async {
    // Force push local version to remote
    // Implementation depends on your sync service
    // For now, just log
    debugPrint('Applying local version for ${conflict.localVersion.name}');
  }

  Future<void> _applyRemoteVersion(ConflictData conflict) async {
    // Apply remote version to local database
    final dbService = ArtikelDbService();
    await dbService.updateArtikel(conflict.remoteVersion);
    debugPrint('Applied remote version for ${conflict.remoteVersion.name}');
  }

  Future<void> _applyMergedVersion(ConflictData conflict) async {
    final mergedVersion = mergedVersions[conflict.localVersion.uuid];
    if (mergedVersion != null) {
      final dbService = ArtikelDbService();
      await dbService.updateArtikel(mergedVersion);
      debugPrint('Applied merged version for ${mergedVersion.name}');
    }
  }

  void _showMergeDialog() {
    showDialog(
      context: context,
      builder: (context) => _MergeDialog(
        localVersion: currentConflict.localVersion,
        remoteVersion: currentConflict.remoteVersion,
        onMerged: (mergedArtikel) {
          setState(() {
            mergedVersions[currentConflict.localVersion.uuid] = mergedArtikel;
            resolutions[currentConflict.localVersion.uuid] = ConflictResolution.merge;
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              SizedBox(height: 8),
              Text('• Gleichzeitige Bearbeitung auf verschiedenen Geräten'),
              Text('• Unterschiedliche Zeitstempel bei ähnlichen Änderungen'),
              Text('• Netzwerkfehler während der Synchronisation'),
              SizedBox(height: 16),
              Text(
                'Lösungsoptionen:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Lokale Version: Behält Ihre lokalen Änderungen'),
              Text('• Remote Version: Übernimmt die Server-Version'),
              Text('• Zusammenführen: Kombiniert beide Versionen manuell'),
              Text('• Überspringen: Behält den Konflikt für später'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}.${dateTime.month}.${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _MergeDialog extends StatefulWidget {
  final Artikel localVersion;
  final Artikel remoteVersion;
  final Function(Artikel) onMerged;

  const _MergeDialog({
    required this.localVersion,
    required this.remoteVersion,
    required this.onMerged,
  });

  @override
  State<_MergeDialog> createState() => _MergeDialogState();
}

class _MergeDialogState extends State<_MergeDialog> {
  late TextEditingController nameController;
  late TextEditingController mengeController;
  late TextEditingController ortController;
  late TextEditingController fachController;
  late TextEditingController beschreibungController;
  String selectedBildPfad = '';

  @override
  void initState() {
    super.initState();
    // Initialize with local version as base
    nameController = TextEditingController(text: widget.localVersion.name);
    mengeController = TextEditingController(text: widget.localVersion.menge.toString());
    ortController = TextEditingController(text: widget.localVersion.ort);
    fachController = TextEditingController(text: widget.localVersion.fach);
    beschreibungController = TextEditingController(text: widget.localVersion.beschreibung);
    selectedBildPfad = widget.localVersion.bildPfad;
  }

  @override
  void dispose() {
    nameController.dispose();
    mengeController.dispose();
    ortController.dispose();
    fachController.dispose();
    beschreibungController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.merge_type, color: Colors.purple),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Versionen zusammenführen',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            
            // Form Fields
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildMergeField(
                      label: 'Name',
                      controller: nameController,
                      localValue: widget.localVersion.name,
                      remoteValue: widget.remoteVersion.name,
                    ),
                    _buildMergeField(
                      label: 'Menge',
                      controller: mengeController,
                      localValue: widget.localVersion.menge.toString(),
                      remoteValue: widget.remoteVersion.menge.toString(),
                      keyboardType: TextInputType.number,
                    ),
                    _buildMergeField(
                      label: 'Ort',
                      controller: ortController,
                      localValue: widget.localVersion.ort,
                      remoteValue: widget.remoteVersion.ort,
                    ),
                    _buildMergeField(
                      label: 'Fach',
                      controller: fachController,
                      localValue: widget.localVersion.fach,
                      remoteValue: widget.remoteVersion.fach,
                    ),
                    _buildMergeField(
                      label: 'Beschreibung',
                      controller: beschreibungController,
                      localValue: widget.localVersion.beschreibung,
                      remoteValue: widget.remoteVersion.beschreibung,
                      maxLines: 3,
                    ),
                    
                    // Image Selection
                    const SizedBox(height: 16),
                    const Text('Bild wählen:', style: TextStyle(fontWeight: FontWeight.bold)),
                    _buildImageSelectionGroup(),
                  ],
                ),
              ),
            ),
            
            // Action Buttons
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveMergedVersion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
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

  Widget _buildMergeField({
    required String label,
    required TextEditingController controller,
    required String localValue,
    required String remoteValue,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    final bool hasConflict = localValue != remoteValue;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
                const Icon(Icons.warning, size: 16, color: Colors.orange),
            ],
          ),
          const SizedBox(height: 4),
          
          if (hasConflict) ...[
            // Show both versions for comparison
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.blue.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Lokal:', style: TextStyle(fontSize: 12, color: Colors.blue)),
                          Text(localValue, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    color: Colors.green.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Remote:', style: TextStyle(fontSize: 12, color: Colors.green)),
                          Text(remoteValue, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => controller.text = localValue,
                  icon: const Icon(Icons.phone_android, size: 16),
                  label: const Text('Lokal übernehmen'),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                ),
                TextButton.icon(
                  onPressed: () => controller.text = remoteValue,
                  icon: const Icon(Icons.cloud, size: 16),
                  label: const Text('Remote übernehmen'),
                  style: TextButton.styleFrom(foregroundColor: Colors.green),
                ),
              ],
            ),
          ],
          
          // Editable field
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'Bearbeiten Sie den Wert oder wählen Sie eine Version aus',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  void _saveMergedVersion() {
    try {
      final mergedArtikel = widget.localVersion.copyWith(
        name: nameController.text.trim(),
        menge: int.tryParse(mengeController.text) ?? widget.localVersion.menge,
        ort: ortController.text.trim(),
        fach: fachController.text.trim(),
        beschreibung: beschreibungController.text.trim(),
        bildPfad: selectedBildPfad,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      widget.onMerged(mergedArtikel);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Zusammenführen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Erstellt die Bildauswahl-Gruppe ohne deprecated RadioListTile
  Widget _buildImageSelectionGroup() {
    return Column(
      children: [
        _buildImageRadioOption(
          title: 'Lokal',
          subtitle: widget.localVersion.bildPfad.isNotEmpty ? 'Vorhanden' : 'Kein Bild',
          value: widget.localVersion.bildPfad,
          isSelected: selectedBildPfad == widget.localVersion.bildPfad,
          onTap: () => setState(() => selectedBildPfad = widget.localVersion.bildPfad),
        ),
        _buildImageRadioOption(
          title: 'Remote',
          subtitle: widget.remoteVersion.bildPfad.isNotEmpty ? 'Vorhanden' : 'Kein Bild',
          value: widget.remoteVersion.bildPfad,
          isSelected: selectedBildPfad == widget.remoteVersion.bildPfad,
          onTap: () => setState(() => selectedBildPfad = widget.remoteVersion.bildPfad),
        ),
      ],
    );
  }

  /// Erstellt eine einzelne Radio-Option für Bildauswahl
  Widget _buildImageRadioOption({
    required String title,
    required String subtitle,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey,
                  width: 2,
                ),
                color: isSelected ? Colors.blue : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.circle,
                      size: 12,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.blue : null,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
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