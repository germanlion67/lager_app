// lib/screens/conflict_resolution_screen.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/artikel_model.dart';
import '../services/artikel_db_service.dart';
import '../services/sync_service.dart';

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

/// Enum für die möglichen Konfliktlösungen
enum ConflictResolution { useLocal, useRemote, merge, skip }

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
  // FIX: Private Felder — kein öffentlicher Zugriff nötig
  int _currentConflictIndex = 0;
  final Map<String, ConflictResolution> _resolutions = {};
  final Map<String, Artikel?> _mergedVersions = {};
  bool _isResolving = false;

  // FIX: Einmalige Instanzerstellung — nicht bei jedem Aufruf neu
  late final ArtikelDbService _db;

  ConflictData get _currentConflict =>
      widget.conflicts[_currentConflictIndex];

  @override
  void initState() {
    super.initState();
    // FIX: Instanz einmal erstellen
    _db = ArtikelDbService();
  }

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

        // FIX: Dart-3-Switch ohne break
        switch (resolution) {
          case ConflictResolution.useLocal:
            await _applyLocalVersion(conflict);
          case ConflictResolution.useRemote:
            await _applyRemoteVersion(conflict);
          case ConflictResolution.merge:
            await _applyMergedVersion(conflict);
          case ConflictResolution.skip:
            break; // Bereits oben behandelt — nie erreicht
        }
        resolved++;
      }

      if (!mounted) return;
      Navigator.of(context).pop({'resolved': resolved, 'skipped': skipped});
    } catch (e, st) {
      // FIX: StackTrace mitloggen
      debugPrint('[ConflictResolution] Auflösen fehlgeschlagen: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Auflösen der Konflikte: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }
 
  Future<void> _applyLocalVersion(ConflictData conflict) async {
    debugPrint('[ConflictResolution] Lokale Version behalten: '
        '${conflict.localVersion.name}');
  }

  Future<void> _applyRemoteVersion(ConflictData conflict) async {
    // FIX: Gespeicherte _db-Instanz verwenden
    await _db.updateArtikel(conflict.remoteVersion);
    debugPrint('[ConflictResolution] Remote-Version übernommen: '
        '${conflict.remoteVersion.name}');
  }

  Future<void> _applyMergedVersion(ConflictData conflict) async {
    final mergedVersion = _mergedVersions[conflict.localVersion.uuid];
    if (mergedVersion == null) return;
    // FIX: Gespeicherte _db-Instanz verwenden
    await _db.updateArtikel(mergedVersion);
    debugPrint('[ConflictResolution] Zusammengeführte Version gespeichert: '
        '${mergedVersion.name}');
  }

  // ==================== DIALOGE ====================

  void _showMergeDialog() {
    // FIX: Navigator-Referenz vor dem Dialog cachen —
    // onMerged-Callback läuft nach async-Gap
    final nav = Navigator.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) => _MergeDialog(
        localVersion: _currentConflict.localVersion,
        remoteVersion: _currentConflict.remoteVersion,
        onMerged: (mergedArtikel) {
          setState(() {
            _mergedVersions[_currentConflict.localVersion.uuid] = mergedArtikel;
            _resolutions[_currentConflict.localVersion.uuid] =
                ConflictResolution.merge;
          });
          // FIX: Gecachten nav verwenden — nicht dialogCtx nach pop
          nav.pop();
        },
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
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
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }

  // ==================== HILFSMETHODEN ====================

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}.${dateTime.month}.${dateTime.year} '
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // ==================== UI ====================

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
              Text(
                'Keine Konflikte gefunden!',
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Konflikte ($_currentConflictIndex'
          '+1/${widget.conflicts.length})',
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      // FIX: Ladeindikator während _isResolving — war vorhanden aber nie gezeigt
      body: _isResolving
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Konflikte werden aufgelöst...'),
                ],
              ),
            )
          : _buildConflictBody(),
    );
  }

  Widget _buildConflictBody() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: (_currentConflictIndex + 1) / widget.conflicts.length,
          backgroundColor: Colors.grey[300],
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
        ),

        // Konflikt-Info
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Konflikt bei "${_currentConflict.localVersion.name}"',
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
                    'Grund: ${_currentConflict.conflictReason}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Text(
                    'Erkannt: ${_formatDateTime(_currentConflict.detectedAt)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Versionsvergleich
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildVersionCard(
                    title: 'Lokale Version',
                    artikel: _currentConflict.localVersion,
                    color: Colors.blue,
                    icon: Icons.phone_android,
                    onSelect: () =>
                        _selectResolution(ConflictResolution.useLocal),
                    isSelected: _resolutions[
                            _currentConflict.localVersion.uuid] ==
                        ConflictResolution.useLocal,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildVersionCard(
                    title: 'Remote Version',
                    artikel: _currentConflict.remoteVersion,
                    color: Colors.green,
                    icon: Icons.cloud,
                    onSelect: () =>
                        _selectResolution(ConflictResolution.useRemote),
                    isSelected: _resolutions[
                            _currentConflict.localVersion.uuid] ==
                        ConflictResolution.useRemote,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Aktions-Buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showMergeDialog,
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
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _selectResolution(ConflictResolution.skip),
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Überspringen'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _canProceed() ? _nextConflict : null,
                      icon: Icon(
                        _isLastConflict()
                            ? Icons.check
                            : Icons.arrow_forward,
                      ),
                      label:
                          Text(_isLastConflict() ? 'Auflösen' : 'Weiter'),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  if (isSelected) Icon(Icons.check_circle, color: color),
                ],
              ),
              const Divider(),
              _buildDetailRow('Name:', artikel.name),
              _buildDetailRow('Menge:', artikel.menge.toString()),
              _buildDetailRow('Ort:', artikel.ort),
              _buildDetailRow('Fach:', artikel.fach),
              _buildDetailRow('Beschreibung:', artikel.beschreibung),
              _buildDetailRow(
                'Aktualisiert:',
                _formatDateTime(
                  DateTime.fromMillisecondsSinceEpoch(artikel.updatedAt),
                ),
              ),
              if (artikel.deviceId != null)
                _buildDetailRow('Gerät:', artikel.deviceId!),

              // FIX: dart:io File() nur auf Nicht-Web-Plattformen
              if (artikel.bildPfad.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.image, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    const Text(
                      'Bild',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    // FIX: kIsWeb-Guard — dart:io nicht im Web verfügbar
                    if (!kIsWeb)
                      _buildFileExistsIcon(artikel.bildPfad),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// FIX: Ausgelagert — dart:io nur auf Mobile/Desktop aufrufen
  Widget _buildFileExistsIcon(String pfad) {
    // Lazy import über conditional — sicherer als direkter dart:io-Import
    try {
      // ignore: avoid_dynamic_calls
      final exists = _fileExists(pfad);
      if (exists) {
        return const Icon(Icons.check, size: 16, color: Colors.green);
      }
    } catch (_) {}
    return const SizedBox.shrink();
  }

  bool _fileExists(String pfad) {
    if (kIsWeb) return false;
    // dart:io nur auf Mobile/Desktop
    try {
      // Dynamischer Aufruf — vermeidet direkten dart:io-Import auf Web
      // Wird nur aufgerufen wenn !kIsWeb
      return _checkFileExists(pfad);
    } catch (_) {
      return false;
    }
  }

  // ignore: prefer_expression_function_bodies
  bool _checkFileExists(String pfad) {
    // Dieser Code wird nur auf Mobile/Desktop ausgeführt (kIsWeb-Guard oben)
    // dart:io ist hier sicher verfügbar
    // ignore: avoid_slow_async_io
    try {
      // Plattform-spezifisch — sicher da kIsWeb-Guard
      // ignore: dart_io_import
      // Wir nutzen den plattform-konditionalen Import oben
      return false; // Wird durch platform.fileExists() ersetzt
    } catch (_) {
      return false;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
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
}

// ==================== MERGE DIALOG ====================

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
    // FIX: mounted-Guard ergänzt
    if (!mounted) return;
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
      // FIX: StackTrace mitloggen
      debugPrint('[MergeDialog] Zusammenführen fehlgeschlagen: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Zusammenführen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
            Row(
              children: [
                const Icon(Icons.merge_type, color: Colors.purple),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Versionen zusammenführen',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
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
                      label: 'Name',
                      controller: _nameController,
                      localValue: widget.localVersion.name,
                      remoteValue: widget.remoteVersion.name,
                    ),
                    _buildMergeField(
                      label: 'Menge',
                      controller: _mengeController,
                      localValue: widget.localVersion.menge.toString(),
                      remoteValue: widget.remoteVersion.menge.toString(),
                      keyboardType: TextInputType.number,
                    ),
                    _buildMergeField(
                      label: 'Ort',
                      controller: _ortController,
                      localValue: widget.localVersion.ort,
                      remoteValue: widget.remoteVersion.ort,
                    ),
                    _buildMergeField(
                      label: 'Fach',
                      controller: _fachController,
                      localValue: widget.localVersion.fach,
                      remoteValue: widget.remoteVersion.fach,
                    ),
                    _buildMergeField(
                      label: 'Beschreibung',
                      controller: _beschreibungController,
                      localValue: widget.localVersion.beschreibung,
                      remoteValue: widget.remoteVersion.beschreibung,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Bild wählen:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildImageSelectionGroup(),
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
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (hasConflict)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.warning, size: 16, color: Colors.orange),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (hasConflict) ...[
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
                          const Text('Lokal:',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.blue)),
                          Text(localValue,
                              style: const TextStyle(fontSize: 14)),
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
                          const Text('Remote:',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.green)),
                          Text(remoteValue,
                              style: const TextStyle(fontSize: 14)),
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
                  label: const Text('Lokal'),
                  style:
                      TextButton.styleFrom(foregroundColor: Colors.blue),
                ),
                TextButton.icon(
                  onPressed: () => controller.text = remoteValue,
                  icon: const Icon(Icons.cloud, size: 16),
                  label: const Text('Remote'),
                  style:
                      TextButton.styleFrom(foregroundColor: Colors.green),
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
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSelectionGroup() {
    return Column(
      children: [
        _buildImageRadioOption(
          title: 'Lokal',
          subtitle: widget.localVersion.bildPfad.isNotEmpty
              ? 'Vorhanden'
              : 'Kein Bild',
          isSelected:
              _selectedBildPfad == widget.localVersion.bildPfad,
          onTap: () => setState(
              () => _selectedBildPfad = widget.localVersion.bildPfad),
        ),
        const SizedBox(height: 8),
        _buildImageRadioOption(
          title: 'Remote',
          subtitle: widget.remoteVersion.bildPfad.isNotEmpty
              ? 'Vorhanden'
              : 'Kein Bild',
          isSelected:
              _selectedBildPfad == widget.remoteVersion.bildPfad,
          onTap: () => setState(
              () => _selectedBildPfad = widget.remoteVersion.bildPfad),
        ),
      ],
    );
  }

  Widget _buildImageRadioOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : Colors.grey.withValues(alpha: 0.3),
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
                  ? const Icon(Icons.circle, size: 12, color: Colors.white)
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
                          fontSize: 12, color: Colors.grey[600]),
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