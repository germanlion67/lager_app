// lib/services/app_log_service.dart
//
// Stellt den globalen Logger + In-App Log-Viewer bereit.
//
// VERWENDUNG:
//   import '../services/app_log_service.dart';
//   final Logger _logger = AppLogService.logger;
//
// LOG-LEVEL REFERENZ:
//   _logger.t('Trace')   → Sehr detailliert, z.B. jeden HTTP-Header
//   _logger.d('Debug')   → Normales Debugging, Methodenaufrufe
//   _logger.i('Info')    → Wichtige Ereignisse, z.B. "Artikel gespeichert"
//   _logger.w('Warning') → Unerwartet, aber kein Absturz
//   _logger.e('Error')   → Fehler in catch-Blöcken, immer mit error+stackTrace
//   _logger.f('Fatal')   → Kritisch, App kann nicht weiterlaufen

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Interner Puffer — max. 500 Events im RAM
//
// Bewusste Entscheidung:
//   500 Events ≈ ~200 KB RAM bei ausführlichen Logs — vertretbar.
//   Bei langen Sessions (z.B. Dauerbetrieb im Lager) können älteste
//   Logs verloren gehen. Für Crash-Diagnose ist das akzeptabel,
//   da kritische Fehler (Level.error / Level.fatal) selten sind.
//   Anpassen auf z.B. 1000 falls nötig.
// ─────────────────────────────────────────────────────────────────────────────
final MemoryOutput _memoryOutput = MemoryOutput(bufferSize: 500);

// ─────────────────────────────────────────────────────────────────────────────
// AppLogService
// ─────────────────────────────────────────────────────────────────────────────
abstract final class AppLogService {
  /// Globale Logger-Instanz — in jeder Datei direkt verwenden.
  static final Logger logger = Logger(
    level: kReleaseMode ? Level.warning : Level.debug,
    output: MultiOutput([ConsoleOutput(), _memoryOutput]),
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 8,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  // Öffentlicher Getter — ermöglicht externen Zugriff auf den Puffer falls nötig.
  static MemoryOutput get memoryOutput => _memoryOutput;

  /// Öffnet den In-App Log-Viewer als Dialog.
  static Future<void> showLogDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const _LogViewerDialog(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Level-Metadaten
// ─────────────────────────────────────────────────────────────────────────────
const _levelMeta = <Level, (String label, Color color, String emoji)>{
  Level.trace:   ('TRACE',   Color(0xFF9E9E9E), '🔍'),
  Level.debug:   ('DEBUG',   Color(0xFF2196F3), '🐛'),
  Level.info:    ('INFO',    Color(0xFF4CAF50), 'ℹ️'),
  Level.warning: ('WARNING', Color(0xFFFF9800), '⚠️'),
  Level.error:   ('ERROR',   Color(0xFFF44336), '❌'),
  Level.fatal:   ('FATAL',   Color(0xFF9C27B0), '💀'),
};

String _label(Level l) => _levelMeta[l]?.$1 ?? l.name.toUpperCase();
Color  _color(Level l) => _levelMeta[l]?.$2 ?? const Color(0xFF9E9E9E);
String _emoji(Level l) => _levelMeta[l]?.$3 ?? '';

// ─────────────────────────────────────────────────────────────────────────────
// Log-Viewer Dialog (privat — nur via AppLogService.showLogDialog erreichbar)
// ─────────────────────────────────────────────────────────────────────────────
class _LogViewerDialog extends StatefulWidget {
  const _LogViewerDialog();

  @override
  State<_LogViewerDialog> createState() => _LogViewerDialogState();
}

class _LogViewerDialogState extends State<_LogViewerDialog> {
  Level _selectedLevel = Level.trace; // standardmäßig alles anzeigen

  List<OutputEvent> get _filtered => _memoryOutput.buffer
      .where((e) => e.level.index >= _selectedLevel.index)
      .toList()
      .reversed
      .toList(); // neueste zuerst

  void _copyAll() {
    final text = _filtered.map((e) => e.lines.join('\n')).join('\n---\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs in Zwischenablage kopiert')),
    );
  }

  void _clearLogs() {
    _memoryOutput.buffer.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final events = _filtered;
    final screenSize = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: SizedBox(
        width: screenSize.width,
        height: screenSize.height * 0.85,
        child: Column(
          children: [
            // ── Titelzeile ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.article_outlined),
                  const SizedBox(width: 8),
                  const Text(
                    'Log-Ansicht',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined),
                    tooltip: 'Alle sichtbaren Logs kopieren',
                    onPressed: _copyAll,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Logs löschen',
                    onPressed: _clearLogs,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Schließen',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 8),

            // ── Filter-Chips ─────────────────────────────────────────
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: _levelMeta.entries.map((entry) {
                  final isSelected = _selectedLevel == entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        '${entry.value.$3} ${entry.value.$1}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : entry.value.$2,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: entry.value.$2,
                      checkmarkColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) =>
                          setState(() => _selectedLevel = entry.key),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ── Zähler ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  Text(
                    '${events.length} Einträge',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    'ab ${_label(_selectedLevel)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            const Divider(height: 4),

            // ── Log-Liste ────────────────────────────────────────────
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Text(
                        'Keine Logs auf diesem Level.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: 8,
                        endIndent: 8,
                      ),
                      itemBuilder: (context, index) {
                        final event = events[index];
                        final color = _color(event.level);
                        final emoji = _emoji(event.level);
                        final label = _label(event.level);

                        return ExpansionTile(
                          dense: true,
                          leading: Container(
                            width: 4,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          title: Text(
                            '$emoji  ${event.lines.first}',
                            style: TextStyle(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            label,
                            style: TextStyle(fontSize: 10, color: color),
                          ),
                          // Stack-Trace & weitere Zeilen aufklappbar
                          children: event.lines.skip(1).map((line) {
                            return Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 4),
                              child: SelectableText(
                                line,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}