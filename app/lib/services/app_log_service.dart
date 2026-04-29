// lib/services/app_log_service.dart
//
// Stellt den globalen Logger + In-App Log-Viewer bereit.
//
// CHANGES:
//   F-006 — Log-Level-Filter: FilterChip-Reihe durch DropdownButton<Level>
//            ersetzt. Default: Level.error (vorher: Level.trace).
//            Passt auf S20 (360dp) ohne horizontales Scrollen.
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

import '../config/app_config.dart';
import '../config/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Interner Puffer — max. 500 Events im RAM
// ─────────────────────────────────────────────────────────────────────────────
final MemoryOutput _memoryOutput = MemoryOutput(bufferSize: 500);

// ANSI-Escape-Sequenzen entfernen (z.B. \x1B[38;5;12m → '')
// Wird nur für den In-App-Viewer benötigt — ConsoleOutput bekommt
// weiterhin den vollen PrettyPrinter-Output mit Farben.
final _ansiEscape = RegExp(r'\x1B\[[0-9;]*m');

/// Output-Adapter: schreibt in _memoryOutput, aber ohne ANSI-Codes.
class _CleanMemoryOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    final cleanLines = event.lines
        .map((l) => l.replaceAll(_ansiEscape, ''))
        .toList();
    _memoryOutput.output(
      OutputEvent(event.origin, cleanLines),  // ← LogEvent korrekt
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppLogService
// ─────────────────────────────────────────────────────────────────────────────
abstract final class AppLogService {
  static final Logger logger = Logger(
    level: kReleaseMode ? Level.warning : Level.debug,
    output: MultiOutput([ConsoleOutput(), _CleanMemoryOutput()]),
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 8,
      lineLength: 80,
      colors: true,       // Terminal bekommt weiterhin Farben
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      noBoxingByDefault: true, // ← Fix LOG-001
    ),
  );

  static MemoryOutput get memoryOutput => _memoryOutput;

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
  Level.trace:   ('TRACE',   AppTheme.greyNeutral600, '🔍'),
  Level.debug:   ('DEBUG',   AppTheme.infoColor,      '🐛'),
  Level.info:    ('INFO',    AppTheme.successColor,   'ℹ️'),
  Level.warning: ('WARNING', AppTheme.warningColor,   '⚠️'),
  Level.error:   ('ERROR',   AppTheme.errorColor,     '❌'),
  Level.fatal:   ('FATAL',   Color(0xFF9C27B0),       '💀'),
};

String _label(Level l) => _levelMeta[l]?.$1 ?? l.name.toUpperCase();
Color  _color(Level l) => _levelMeta[l]?.$2 ?? AppTheme.greyNeutral600;
String _emoji(Level l) => _levelMeta[l]?.$3 ?? '';

// ─────────────────────────────────────────────────────────────────────────────
// Log-Viewer Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _LogViewerDialog extends StatefulWidget {
  const _LogViewerDialog();

  @override
  State<_LogViewerDialog> createState() => _LogViewerDialogState();
}

class _LogViewerDialogState extends State<_LogViewerDialog> {
  // F-006: Default Level.error statt Level.trace —
  // zeigt sofort das Relevante, reduziert initialen Log-Rausch.
  Level _selectedLevel = Level.error;

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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(AppConfig.spacingMedium),
      child: SizedBox(
        width: screenSize.width,
        height: screenSize.height * 0.85,
        child: Column(
          children: [
            // ── Titelzeile ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConfig.spacingLarge,
                AppConfig.spacingMedium,
                AppConfig.spacingSmall,
                0,
              ),
              child: Row(
                children: [
                  const Icon(Icons.article_outlined),
                  const SizedBox(width: AppConfig.spacingSmall),
                  Text(
                    'Log-Ansicht',
                    style: textTheme.titleLarge?.copyWith(
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

            const Divider(height: AppConfig.spacingSmall),

            // ── F-006: Level-Filter als Dropdown ────────────────────────
            // Ersetzt die horizontale FilterChip-Reihe.
            // Passt auf S20 (360dp) ohne horizontales Scrollen.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConfig.spacingLarge,
                vertical: AppConfig.spacingXSmall,
              ),
              child: Row(
                children: [
                  // Label
                  Icon(
                    Icons.filter_list,
                    size: AppConfig.iconSizeMedium,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppConfig.spacingSmall),
                  Text(
                    'Mindest-Level:',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppConfig.spacingSmall),

                  // Dropdown
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConfig.spacingSmall,
                        vertical: AppConfig.spacingXSmall,
                      ),
                      decoration: BoxDecoration(
                        color: _color(_selectedLevel)
                            .withValues(alpha: AppConfig.opacitySubtle),
                        borderRadius: BorderRadius.circular(
                          AppConfig.borderRadiusMedium,
                        ),
                        border: Border.all(
                          color: _color(_selectedLevel)
                              .withValues(alpha: AppConfig.opacityMedium),
                        ),
                      ),
                      child: DropdownButton<Level>(
                        value: _selectedLevel,
                        isExpanded: true,
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        icon: Icon(
                          Icons.expand_more,
                          color: _color(_selectedLevel),
                          size: AppConfig.iconSizeMedium,
                        ),
                        // Dropdown-Einträge: alle 6 Level mit Emoji + Label
                        items: _levelMeta.entries.map((entry) {
                          final level = entry.key;
                          final label = entry.value.$1;
                          final color = entry.value.$2;
                          final emoji = entry.value.$3;
                          final isSelected = _selectedLevel == level;

                          return DropdownMenuItem<Level>(
                            value: level,
                            child: Row(
                              children: [
                                Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(
                                  width: AppConfig.spacingXSmall,
                                ),
                                Text(
                                  label,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: color,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (Level? newLevel) {
                          if (newLevel != null) {
                            setState(() => _selectedLevel = newLevel);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Zähler ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConfig.spacingLarge,
                vertical: AppConfig.spacingXSmall,
              ),
              child: Row(
                children: [
                  Text(
                    '${events.length} Einträge',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  // Aktiver Filter als farbiger Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConfig.spacingSmall,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _color(_selectedLevel)
                          .withValues(alpha: AppConfig.opacitySubtle),
                      borderRadius: BorderRadius.circular(
                        AppConfig.borderRadiusXSmall,
                      ),
                      border: Border.all(
                        color: _color(_selectedLevel)
                            .withValues(alpha: AppConfig.opacityMedium),
                      ),
                    ),
                    child: Text(
                      'ab ${_emoji(_selectedLevel)} ${_label(_selectedLevel)}',
                      style: textTheme.labelSmall?.copyWith(
                        color: _color(_selectedLevel),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: AppConfig.spacingXSmall),

            // ── Log-Liste ────────────────────────────────────────────────
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: AppConfig.iconSizeXLarge,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: AppConfig.spacingMedium),
                          Text(
                            'Keine Einträge auf '
                            '${_emoji(_selectedLevel)} '
                            '${_label(_selectedLevel)} oder höher.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppConfig.spacingSmall),
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: AppConfig.spacingSmall,
                        endIndent: AppConfig.spacingSmall,
                      ),
                      itemBuilder: (context, index) {
                        final event = events[index];
                        final color = _color(event.level);
                        final emoji = _emoji(event.level);
                        final label = _label(event.level);

                        return ExpansionTile(
                          dense: true,
                          leading: Container(
                            width: AppConfig.strokeWidthThick,
                            height: AppConfig.spacingXXLarge,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(
                                AppConfig.borderRadiusXXSmall,
                              ),
                            ),
                          ),
                          title: Text(
                            '$emoji  ${event.lines.first}',
                            style: textTheme.bodySmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            label,
                            style: textTheme.labelSmall?.copyWith(
                              color: color,
                            ),
                          ),
                          // Stack-Trace & weitere Zeilen aufklappbar
                          children: event.lines.skip(1).map((line) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppConfig.spacingLarge,
                                0,
                                AppConfig.spacingLarge,
                                AppConfig.spacingXSmall,
                              ),
                              child: SelectableText(
                                line,
                                style: textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  fontSize: AppConfig.fontSizeXSmall,
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