// lib/screens/settings_screen.dart
//
// O-004: Alle hardcodierten Farben durch colorScheme ersetzt,
// alle Magic-Number-Abstände/Radien durch AppConfig-Tokens.
// Semantische Status-Container nutzen jetzt colorScheme.*Container-Farben.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../services/app_lock_service.dart';
import '../services/artikel_db_service.dart';
import '../services/pocketbase_service.dart';
import '../services/app_log_service.dart';

import 'package:package_info_plus/package_info_plus.dart';
import '../widgets/backup_status_widget.dart';

class SettingsScreen extends StatefulWidget {
  /// ── M-009: Callback für Logout — wird von AuthGate in main.dart
  /// übergeben, um den App-Zustand zurückzusetzen.
  final VoidCallback? onLogout;

  const SettingsScreen({super.key, this.onLogout});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _artikelNummerController = TextEditingController();
  final _pocketBaseUrlController = TextEditingController();

  // FIX: Einmalige Instanzerstellung — nicht bei jedem Aufruf neu
  late final PocketBaseService _pbService;
  late final ArtikelDbService _db;

  bool _isDatabaseEmpty = true;
  bool _isCheckingConnection = false;
  bool? _pbConnectionOk;

  // ── Sicherheits-Einstellungen ─────────────────────────────────────────────
  bool _appLockEnabled = false;
  bool _appLockBiometricsEnabled = true;
  int _appLockTimeoutMinutes = 5;

  @override
  void initState() {
    super.initState();
    _pbService = PocketBaseService();
    _db = ArtikelDbService();

    _loadSettings();
    if (!kIsWeb) {
      _checkDatabaseStatus();
    }
  }

  @override
  void dispose() {
    _artikelNummerController.dispose();
    _pocketBaseUrlController.dispose();
    super.dispose();
  }

  // ==================== LADEN ====================

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_pbService.isInitialized) {
        await _pbService.initialize();
      }
      if (!mounted) return;
      setState(() {
        _artikelNummerController.text =
            (prefs.getInt('artikel_start_nummer') ?? 1000).toString();
        _pocketBaseUrlController.text = _pbService.url;
        if (!kIsWeb) {
          _appLockEnabled = AppLockService().isEnabled;
          _appLockBiometricsEnabled = AppLockService().isBiometricsEnabled;
          _appLockTimeoutMinutes =
              (AppLockService().timeoutSeconds / 60).round().clamp(1, 30);
        }
      });
    } catch (e, st) {
      AppLogService.logger.e('Laden fehlgeschlagen', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Einstellungen konnten nicht geladen werden: $e'),
        ),
      );
    }
  }

  Future<void> _checkDatabaseStatus() async {
    if (kIsWeb) return;
    try {
      final isEmpty = await _db.isDatabaseEmpty();
      if (!mounted) return;
      setState(() => _isDatabaseEmpty = isEmpty);
    } catch (e, st) {
      AppLogService.logger
          .e('DB-Status prüfen fehlgeschlagen', error: e, stackTrace: st);
    }
  }

  // ==================== POCKETBASE ====================

  Future<void> _testPocketBaseConnection() async {
    setState(() {
      _isCheckingConnection = true;
      _pbConnectionOk = null;
    });

    try {
      final testUrl = _pocketBaseUrlController.text.trim();

      if (testUrl.isNotEmpty && testUrl != _pbService.url) {
        final ok = await _pbService.updateUrl(testUrl);

        if (!mounted) return;
        setState(() => _pbConnectionOk = ok);

        _showConnectionSnackBar(ok);
      } else {
        final ok = await _pbService.checkHealth();

        if (!mounted) return;
        setState(() => _pbConnectionOk = ok);

        _showConnectionSnackBar(ok);
      }
    } catch (e, st) {
      AppLogService.logger
          .e('PocketBase-Test fehlgeschlagen', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _pbConnectionOk = false);
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verbindungsfehler: $e'),
          backgroundColor: colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCheckingConnection = false);
    }
  }

  /// Zeigt eine SnackBar mit Verbindungsstatus an.
  /// Farben werden aus dem colorScheme bezogen.
  void _showConnectionSnackBar(bool ok) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '✅ Verbindung zu PocketBase erfolgreich!'
              : '❌ PocketBase nicht erreichbar',
        ),
        backgroundColor: ok ? colorScheme.tertiary : colorScheme.error,
      ),
    );
  }

  Future<void> _resetPocketBaseUrl() async {
    final currentDefault = PocketBaseService.defaultUrl;
    final hasDefault = currentDefault.isNotEmpty &&
        !currentDefault.contains('your-production-server.com') &&
        !currentDefault.contains('192.168.178.XX');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('URL zurücksetzen?'),
        content: Text(
          hasDefault
              ? 'Die PocketBase-URL wird auf den Standard zurückgesetzt:\n\n'
                  '$currentDefault'
              : 'Die gespeicherte URL wird gelöscht.\n\n'
                  'Es ist kein Build-Default konfiguriert. '
                  'Du musst danach eine neue URL eingeben.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirm == true) {
      try {
        await _pbService.resetToDefault();
        if (!mounted) return;
        setState(() {
          _pocketBaseUrlController.text = _pbService.url;
          _pbConnectionOk = null;
        });
      } catch (e, st) {
        AppLogService.logger
            .e('URL-Reset fehlgeschlagen', error: e, stackTrace: st);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Zurücksetzen: $e')),
        );
      }
    }
  }

  // ==================== DATENBANK ====================

  Future<void> _deleteDatabase() async {
    if (kIsWeb) return;

    final colorScheme = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Datenbank löschen'),
        content: const Text(
          'Möchten Sie die komplette lokale Datenbank löschen? '
          'Alle lokal gespeicherten Artikel gehen verloren!\n\n'
          'Daten in PocketBase bleiben erhalten und können neu '
          'synchronisiert werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirm == true) {
      try {
        await _db.resetDatabase();
        await _checkDatabaseStatus();
        await _loadSettings();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Lokale Datenbank gelöscht – '
              'Sie können jetzt eine neue Start-Artikelnummer festlegen',
            ),
          ),
        );
      } catch (e, st) {
        AppLogService.logger
            .e('DB-Löschen fehlgeschlagen', error: e, stackTrace: st);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Löschen: $e')),
        );
      }
    }
  }

  // ==================== SPEICHERN ====================

  Future<void> _saveSettings() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      final newUrl = _pocketBaseUrlController.text.trim();
      if (newUrl.isNotEmpty) {
        final urlUpdated = await _pbService.updateUrl(newUrl);
        if (!urlUpdated) {
          if (!mounted) return;
          final colorScheme = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '⚠️ PocketBase URL konnte nicht gesetzt werden – '
                'Server nicht erreichbar oder URL ungültig. '
                'Bestehende URL bleibt aktiv.',
              ),
              backgroundColor: colorScheme.secondary,
            ),
          );
          setState(() {
            _pocketBaseUrlController.text = _pbService.url;
          });
          return;
        }
      }

      if (!kIsWeb && _isDatabaseEmpty) {
        final artikelNummer =
            int.tryParse(_artikelNummerController.text.trim()) ?? 1000;
        await prefs.setInt('artikel_start_nummer', artikelNummer);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Einstellungen gespeichert')),
      );
    } catch (e, st) {
      AppLogService.logger
          .e('Speichern fehlgeschlagen', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Speichern: $e')),
      );
    }
  }

  // ==================== M-009: LOGOUT ====================

  Future<void> _handleLogout() async {
    final colorScheme = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abmelden'),
        content: const Text(
          'Möchtest du dich wirklich abmelden?\n\n'
          'Du musst dich beim nächsten Start erneut anmelden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirm == true) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      widget.onLogout?.call();
    }
  }



  // ==================== M-009: ACCOUNT CARD ====================

  Widget _buildAccountCard() {
    final isLoggedIn = _pbService.isAuthenticated;
    final userEmail = _pbService.currentUserEmail;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isLoggedIn ? Icons.person : Icons.person_off,
                  color: isLoggedIn
                      ? colorScheme.tertiary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppConfig.spacingSmall),
                Text(
                  'Benutzerkonto',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (isLoggedIn)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConfig.spacingSmall,
                      vertical: AppConfig.spacingXSmall,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(
                        AppConfig.cardBorderRadiusLarge,
                      ),
                      border: Border.all(
                        color: colorScheme.tertiary
                            .withValues(alpha: AppConfig.opacityMedium),
                      ),
                    ),
                    child: Text(
                      'Angemeldet',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppConfig.spacingLarge),

            // Benutzer-Info
            if (isLoggedIn && userEmail != null) ...[
              Container(
                padding: const EdgeInsets.all(AppConfig.spacingMedium),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(
                    AppConfig.borderRadiusMedium,
                  ),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: AppConfig.avatarRadiusSmall,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        userEmail.isNotEmpty
                            ? userEmail[0].toUpperCase()
                            : '?',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConfig.spacingMedium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Angemeldet als',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppConfig.spacingXSmall),
                          Text(
                            userEmail,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConfig.spacingMedium),
            ] else ...[
              _buildStatusContainer(
                icon: Icons.warning_amber,
                message: 'Nicht angemeldet. Einige Funktionen sind '
                    'möglicherweise eingeschränkt.',
                type: _StatusType.warning,
              ),
              const SizedBox(height: AppConfig.spacingMedium),
            ],

            // Logout-Button
            if (isLoggedIn && widget.onLogout != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleLogout,
                  icon: Icon(Icons.logout, color: colorScheme.error),
                  label: const Text('Abmelden'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==================== POCKETBASE CARD ====================

  Widget _buildPocketBaseCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dns, color: colorScheme.primary),
                const SizedBox(width: AppConfig.spacingSmall),
                Text(
                  'PocketBase Server',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_pbConnectionOk != null)
                  Icon(
                    _pbConnectionOk! ? Icons.check_circle : Icons.error,
                    color: _pbConnectionOk!
                        ? colorScheme.tertiary
                        : colorScheme.error,
                    size: AppConfig.iconSizeMedium,
                  ),
              ],
            ),
            const SizedBox(height: AppConfig.spacingLarge),
            TextFormField(
              controller: _pocketBaseUrlController,
              decoration: InputDecoration(
                labelText: 'PocketBase URL',
                hintText: 'http://192.168.1.100:8080',
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(),
                helperText: 'Standard: ${PocketBaseService.defaultUrl}',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.undo),
                  tooltip: 'Auf Standard zurücksetzen',
                  onPressed: _resetPocketBaseUrl,
                ),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bitte eine URL eingeben';
                }
                final url = value.trim();
                if (!url.startsWith('http://') &&
                    !url.startsWith('https://')) {
                  return 'URL muss mit http:// oder https:// beginnen';
                }
                return null;
              },
            ),
            const SizedBox(height: AppConfig.spacingMedium),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _isCheckingConnection ? null : _testPocketBaseConnection,
                icon: _isCheckingConnection
                    ? const SizedBox(
                        width: AppConfig.iconSizeSmall,
                        height: AppConfig.iconSizeSmall,
                        child: CircularProgressIndicator(
                          strokeWidth: AppConfig.strokeWidthMedium,
                        ),
                      )
                    : const Icon(Icons.wifi_find),
                label: Text(
                  _isCheckingConnection
                      ? 'Prüfe Verbindung...'
                      : 'Verbindung testen',
                ),
              ),
            ),
            if (_pbConnectionOk != null) ...[
              const SizedBox(height: AppConfig.spacingSmall),
              _buildStatusContainer(
                icon: _pbConnectionOk! ? Icons.check_circle : Icons.error,
                message: _pbConnectionOk!
                    ? 'Verbindung erfolgreich! Server ist erreichbar.'
                    : 'Server nicht erreichbar. Bitte URL und Netzwerk prüfen.',
                type: _pbConnectionOk!
                    ? _StatusType.success
                    : _StatusType.error,
              ),
            ],
            if (kIsWeb) ...[
              const SizedBox(height: AppConfig.spacingMedium),
              _buildStatusContainer(
                icon: Icons.info_outline,
                message: 'Im Web-Modus wird die API über den Reverse Proxy '
                    'bereitgestellt. Die Standard-URL (/api) sollte '
                    'normalerweise nicht geändert werden.',
                type: _StatusType.info,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        actions: [
          IconButton(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            tooltip: 'Einstellungen speichern',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConfig.spacingLarge),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAccountCard(),
              const SizedBox(height: AppConfig.spacingLarge),
              _buildPocketBaseCard(),
              const SizedBox(height: AppConfig.spacingLarge),
              const BackupStatusWidget(),                          // ← NEU
              const SizedBox(height: AppConfig.spacingLarge),      // ← NEU
              if (!kIsWeb) _buildSecurityCard(),
              if (!kIsWeb) const SizedBox(height: AppConfig.spacingLarge),
              if (!kIsWeb) _buildArtikelNummerCard(),
              if (!kIsWeb) const SizedBox(height: AppConfig.spacingLarge),
              _buildInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== SICHERHEIT CARD ====================

  Widget _buildSecurityCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: colorScheme.primary),
                const SizedBox(width: AppConfig.spacingSmall),
                Text(
                  'Sicherheit',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConfig.spacingMedium),

            // App-Lock Toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('App-Lock aktivieren'),
              subtitle: const Text(
                'App nach Inaktivität automatisch sperren',
              ),
              secondary: Icon(
                Icons.lock_outline,
                color: colorScheme.onSurfaceVariant,
              ),
              value: _appLockEnabled,
              onChanged: (value) async {
                setState(() => _appLockEnabled = value);
                await AppLockService().setEnabled(value);
              },
            ),

            // Biometrie Toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Biometrie verwenden'),
              subtitle: const Text(
                'Fingerabdruck / Gesichtserkennung zum Entsperren',
              ),
              secondary: Icon(
                Icons.fingerprint,
                color: colorScheme.onSurfaceVariant,
              ),
              value: _appLockBiometricsEnabled,
              onChanged: (value) async {
                setState(() => _appLockBiometricsEnabled = value);
                await AppLockService().setBiometricsEnabled(value);
              },
            ),

            // Timeout Slider — nur sichtbar wenn App-Lock aktiv
            if (_appLockEnabled) ...[
              const SizedBox(height: AppConfig.spacingSmall),
              Text(
                'Sperrzeit: $_appLockTimeoutMinutes Minuten',
                style: textTheme.bodyMedium,
              ),
              Slider(
                value: _appLockTimeoutMinutes.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                label: '$_appLockTimeoutMinutes min',
                onChanged: (value) {
                  setState(() => _appLockTimeoutMinutes = value.round());
                },
                onChangeEnd: (value) async {
                  final minutes = value.round();
                  setState(() => _appLockTimeoutMinutes = minutes);
                  await AppLockService().setTimeoutSeconds(minutes * 60);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== ARTIKELNUMMER CARD ====================

  Widget _buildArtikelNummerCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Artikelnummer-Einstellungen',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConfig.spacingLarge),
            TextFormField(
              controller: _artikelNummerController,
              enabled: _isDatabaseEmpty,
              decoration: InputDecoration(
                labelText: 'Start-Artikelnummer',
                hintText: 'z.B. 1000',
                prefixIcon: const Icon(Icons.tag),
                helperText: _isDatabaseEmpty
                    ? 'Neue Artikel erhalten eine ID ab dieser Nummer'
                    : 'Kann nur bei leerer Datenbank geändert werden',
                border: const OutlineInputBorder(),
                suffixIcon: _isDatabaseEmpty
                    ? null
                    : Icon(
                        Icons.lock,
                        color: colorScheme.onSurfaceVariant,
                      ),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bitte eine Artikelnummer eingeben';
                }
                final nummer = int.tryParse(value.trim());
                if (nummer == null) return 'Bitte eine gültige Zahl eingeben';
                if (nummer < 1) return 'Mindestens 1';
                if (nummer > 999999) return 'Maximal 999999';
                return null;
              },
            ),
            if (!_isDatabaseEmpty) ...[
              const SizedBox(height: AppConfig.spacingMedium),
              _buildStatusContainer(
                icon: Icons.info_outline,
                message: 'Die Start-Artikelnummer kann nur geändert werden, '
                    'wenn die lokale Datenbank leer ist. '
                    'Daten in PocketBase bleiben erhalten.',
                type: _StatusType.warning,
              ),
              const SizedBox(height: AppConfig.spacingMedium),
              OutlinedButton.icon(
                onPressed: _deleteDatabase,
                icon: Icon(Icons.delete_forever, color: colorScheme.error),
                label: const Text('Lokale Datenbank löschen'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== INFO CARD ====================

  Widget _buildInfoCard() {
    final pbUrl = _pbService.url;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App-Information',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConfig.spacingMedium),
            FutureBuilder<String>(
              future: _getAppVersion(),
              builder: (context, snapshot) {
                final version = snapshot.data ?? 'Laden...';
                return _infoRow('Version', version);
              },
            ),
            _infoRow('Plattform', kIsWeb ? 'Web' : 'Mobile/Desktop'),
            _infoRow(
              'Datenbank',
              kIsWeb
                  ? 'PocketBase (direkt)'
                  : 'SQLite (lokal) + PocketBase Sync',
            ),
            _infoRow('PocketBase URL', pbUrl),
            _infoRow(
              'Auth-Status',
              _pbService.isAuthenticated
                  ? 'Angemeldet (${_pbService.currentUserEmail ?? "–"})'
                  : 'Nicht angemeldet',
            ),
          ],
        ),
      ),
    );
  }

  // ==================== VERSION LADEN ====================

  Future<String> _getAppVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (e, st) {
      AppLogService.logger
          .e('Fehler beim Laden der App-Version', error: e, stackTrace: st);
      return 'Unbekannt';
    }
  }

  Widget _infoRow(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConfig.spacingXSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppConfig.infoLabelWidth,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SHARED STATUS CONTAINER ====================
  // O-004: Wiederverwendbarer Status-Container ersetzt die vielen
  // duplizierten Container mit Colors.green.shade50, Colors.red.shade50 etc.
  // Nutzt jetzt semantische colorScheme-Farben.

  Widget _buildStatusContainer({
    required IconData icon,
    required String message,
    required _StatusType type,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final Color containerColor;
    final Color borderColor;
    final Color contentColor;

    switch (type) {
      case _StatusType.success:
        containerColor = colorScheme.tertiaryContainer;
        borderColor = colorScheme.tertiary
            .withValues(alpha: AppConfig.opacityMedium);
        contentColor = colorScheme.onTertiaryContainer;
      case _StatusType.error:
        containerColor = colorScheme.errorContainer;
        borderColor = colorScheme.error
            .withValues(alpha: AppConfig.opacityMedium);
        contentColor = colorScheme.onErrorContainer;
      case _StatusType.warning:
        containerColor = colorScheme.secondaryContainer;
        borderColor = colorScheme.secondary
            .withValues(alpha: AppConfig.opacityMedium);
        contentColor = colorScheme.onSecondaryContainer;
      case _StatusType.info:
        containerColor = colorScheme.primaryContainer;
        borderColor = colorScheme.primary
            .withValues(alpha: AppConfig.opacityMedium);
        contentColor = colorScheme.onPrimaryContainer;
    }

    return Container(
      padding: const EdgeInsets.all(AppConfig.spacingMedium),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(AppConfig.borderRadiusMedium),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: contentColor),
          const SizedBox(width: AppConfig.spacingSmall),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(
                color: contentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Interne Enum für Status-Container-Typen.
/// Nicht exportiert — nur innerhalb von settings_screen.dart verwendet.
enum _StatusType { success, error, warning, info }