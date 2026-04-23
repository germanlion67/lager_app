// lib/screens/settings_screen.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../config/app_config.dart';

import '../services/pocketbase_service.dart';
import '../services/app_log_service.dart';

import 'package:package_info_plus/package_info_plus.dart';
import '../widgets/backup_status_widget.dart';

import 'package:local_auth/local_auth.dart';

import 'settings_controller.dart';


class SettingsScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  const SettingsScreen({super.key, this.onLogout});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final SettingsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SettingsController();
    _initController();
  }

  Future<void> _initController() async {
    try {
      await _controller.init();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Einstellungen konnten nicht geladen werden: $e'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _showUnsavedChangesDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ungespeicherte Änderungen'),
        content: const Text(
          'Du hast Änderungen an der PocketBase-URL oder '
          'Artikelnummer vorgenommen, die noch nicht gespeichert '
          'wurden.\n\nMöchtest du die Änderungen verwerfen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Zurück zum Bearbeiten'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Verwerfen'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

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

  Future<void> _testPocketBaseConnection() async {
    final ok = await _controller.testPocketBaseConnection();
    if (!mounted) return;
    _showConnectionSnackBar(ok);
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
      final ok = await _controller.resetPocketBaseUrl();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler beim Zurücksetzen der URL')),
        );
      }
    }
  }

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
      final ok = await _controller.deleteDatabase();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Lokale Datenbank gelöscht – '
                    'Sie können jetzt eine neue Start-Artikelnummer festlegen'
                : 'Fehler beim Löschen der Datenbank',
          ),
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final result = await _controller.saveSettings();
    if (!mounted) return;

    final colorScheme = Theme.of(context).colorScheme;

    switch (result) {
      case SaveSettingsResult.success:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Einstellungen gespeichert')),
        );
      case SaveSettingsResult.pocketBaseUrlRejected:
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
      case SaveSettingsResult.error:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler beim Speichern')),
        );
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return PopScope(
          canPop: !_controller.hasUnsavedChanges,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final navigator = Navigator.of(context);
            final shouldLeave = await _showUnsavedChangesDialog();
            if (shouldLeave && mounted) {
              navigator.pop();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Einstellungen'),
              actions: [
                IconButton(
                  onPressed: _saveSettings,
                  icon: Icon(
                    _controller.hasUnsavedChanges
                        ? Icons.save
                        : Icons.save_outlined,
                  ),
                  tooltip: _controller.hasUnsavedChanges
                      ? 'Änderungen speichern'
                      : 'Einstellungen speichern',
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
                    if (_controller.hasUnsavedChanges)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppConfig.spacingMedium,
                        ),
                        child: _buildStatusContainer(
                          icon: Icons.edit_note,
                          message: 'Du hast ungespeicherte Änderungen. '
                              'Tippe auf 💾 zum Speichern.',
                          type: _StatusType.warning,
                        ),
                      ),
                    _buildAccountCard(),
                    const SizedBox(height: AppConfig.spacingLarge),
                    _buildPocketBaseCard(),
                    const SizedBox(height: AppConfig.spacingLarge),
                    const BackupStatusWidget(),
                    const SizedBox(height: AppConfig.spacingLarge),
                    if (!kIsWeb) _buildSecurityCard(),
                    if (!kIsWeb) const SizedBox(height: AppConfig.spacingLarge),
                    if (!kIsWeb) _buildArtikelNummerCard(),
                    if (!kIsWeb) const SizedBox(height: AppConfig.spacingLarge),
                    _buildInfoCard(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

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
                if (_controller.pbConnectionOk != null)
                  Icon(
                    _controller.pbConnectionOk!
                        ? Icons.check_circle
                        : Icons.error,
                    color: _controller.pbConnectionOk!
                        ? colorScheme.tertiary
                        : colorScheme.error,
                    size: AppConfig.iconSizeMedium,
                  ),
              ],
            ),
            const SizedBox(height: AppConfig.spacingLarge),
            TextFormField(
              controller: _controller.pocketBaseUrlController,
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
                onPressed: _controller.isCheckingConnection
                    ? null
                    : _testPocketBaseConnection,
                icon: _controller.isCheckingConnection
                    ? const SizedBox(
                        width: AppConfig.iconSizeSmall,
                        height: AppConfig.iconSizeSmall,
                        child: CircularProgressIndicator(
                          strokeWidth: AppConfig.strokeWidthMedium,
                        ),
                      )
                    : const Icon(Icons.wifi_find),
                label: Text(
                  _controller.isCheckingConnection
                      ? 'Prüfe Verbindung...'
                      : 'Verbindung testen',
                ),
              ),
            ),
            if (_controller.pbConnectionOk != null) ...[
              const SizedBox(height: AppConfig.spacingSmall),
              _buildStatusContainer(
                icon: _controller.pbConnectionOk!
                    ? Icons.check_circle
                    : Icons.error,
                message: _controller.pbConnectionOk!
                    ? 'Verbindung erfolgreich! Server ist erreichbar.'
                    : 'Server nicht erreichbar. Bitte URL und Netzwerk prüfen.',
                type: _controller.pbConnectionOk!
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
            const SizedBox(height: AppConfig.spacingMedium),
            const Divider(),
            const SizedBox(height: AppConfig.spacingXSmall),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                Icons.access_time_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
              title: const Text('Letzten Sync-Zeitstempel anzeigen'),
              subtitle: const Text(
                'Zeigt den Zeitpunkt der letzten Synchronisierung '
                'in der Titelzeile der Artikelliste an.',
              ),
              value: _controller.showLastSync,
              onChanged: (value) async {
                final ok = await _controller.setShowLastSync(value);
                if (!mounted || ok) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Einstellung konnte nicht gespeichert werden',
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

  Widget _buildAccountCard() {
    final pbService = PocketBaseService();
    final isLoggedIn = pbService.isAuthenticated;
    final userEmail = pbService.currentUserEmail;
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
              value: _controller.appLockEnabled,
              onChanged: (value) async {
                final previousValue = _controller.appLockEnabled;
                await _controller.setAppLockEnabled(value);
                if (!mounted) return;
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      value
                          ? '🔒 App-Lock aktiviert'
                          : '🔓 App-Lock deaktiviert',
                    ),
                    action: SnackBarAction(
                      label: 'Rückgängig',
                      onPressed: () async {
                        await _controller.setAppLockEnabled(previousValue);
                      },
                    ),
                  ),
                );
              },
            ),
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
              value: _controller.appLockBiometricsEnabled,
              onChanged: (value) async {
                if (value) {
                  final auth = LocalAuthentication();
                  try {
                    final canCheck = await auth.canCheckBiometrics;
                    final isSupported = await auth.isDeviceSupported();
                    if (!canCheck && !isSupported) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '❌ Biometrie auf diesem Gerät nicht '
                            'verfügbar oder nicht eingerichtet.',
                          ),
                        ),
                      );
                      return;
                    }
                    final authenticated = await auth.authenticate(
                      localizedReason: 'Biometrie-Test: Bitte bestätigen '
                          'Sie Ihre Identität',
                      biometricOnly: true,
                      sensitiveTransaction: false,
                      persistAcrossBackgrounding: false,
                    );
                    if (!authenticated) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '⚠️ Biometrie-Test nicht bestanden. '
                            'Einstellung wurde nicht aktiviert.',
                          ),
                        ),
                      );
                      return;
                    }
                  } on LocalAuthException catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '❌ Biometrie nicht verfügbar: '
                          '${e.description ?? e.code.name}',
                        ),
                      ),
                    );
                    return;
                  }
                }

                await _controller.setAppLockBiometricsEnabled(value);
                if (!mounted) return;
                if (value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Biometrie erfolgreich aktiviert'),
                    ),
                  );
                }
              },
            ),
            if (_controller.appLockEnabled) ...[
              const SizedBox(height: AppConfig.spacingSmall),
              Text(
                'Sperrzeit: ${_controller.appLockTimeoutMinutes} Minuten',
                style: textTheme.bodyMedium,
              ),
              Slider(
                value: _controller.appLockTimeoutMinutes.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                label: '${_controller.appLockTimeoutMinutes} min',
                onChanged: (value) {
                  _controller.setAppLockTimeoutPreview(value.round());
                },
                onChangeEnd: (value) async {
                  final minutes = value.round();
                  final previousMinutes = _controller.appLockTimeoutMinutes;
                  await _controller.setAppLockTimeoutMinutes(minutes);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '⏱️ Sperrzeit auf $minutes Minuten gesetzt',
                      ),
                      action: SnackBarAction(
                        label: 'Rückgängig',
                        onPressed: () async {
                          await _controller
                              .setAppLockTimeoutMinutes(previousMinutes);
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

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
              controller: _controller.artikelNummerController,
              enabled: _controller.isDatabaseEmpty,
              decoration: InputDecoration(
                labelText: 'Start-Artikelnummer',
                hintText: 'z.B. 1000',
                prefixIcon: const Icon(Icons.tag),
                helperText: _controller.isDatabaseEmpty
                    ? 'Neue Artikel erhalten eine ID ab dieser Nummer'
                    : 'Kann nur bei leerer Datenbank geändert werden',
                border: const OutlineInputBorder(),
                suffixIcon: _controller.isDatabaseEmpty
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
            if (!_controller.isDatabaseEmpty) ...[
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

  Widget _buildInfoCard() {
    final pbUrl = PocketBaseService().url;
    final textTheme = Theme.of(context).textTheme;
    final pbService = PocketBaseService();

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
              pbService.isAuthenticated
                  ? 'Angemeldet (${pbService.currentUserEmail ?? "–"})'
                  : 'Nicht angemeldet',
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
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
        borderColor =
            colorScheme.tertiary.withValues(alpha: AppConfig.opacityMedium);
        contentColor = colorScheme.onTertiaryContainer;
      case _StatusType.error:
        containerColor = colorScheme.errorContainer;
        borderColor =
            colorScheme.error.withValues(alpha: AppConfig.opacityMedium);
        contentColor = colorScheme.onErrorContainer;
      case _StatusType.warning:
        containerColor = colorScheme.secondaryContainer;
        borderColor =
            colorScheme.secondary.withValues(alpha: AppConfig.opacityMedium);
        contentColor = colorScheme.onSecondaryContainer;
      case _StatusType.info:
        containerColor = colorScheme.primaryContainer;
        borderColor =
            colorScheme.primary.withValues(alpha: AppConfig.opacityMedium);
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
              style: textTheme.bodySmall?.copyWith(color: contentColor),
            ),
          ),
        ],
      ),
    );
  }
}

enum _StatusType { success, error, warning, info }