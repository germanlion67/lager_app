// lib/screens/login_screen.dart

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/pocketbase_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pbService = PocketBaseService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final success = await _pbService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (success) {
        widget.onLoginSuccess();
      } else {
        setState(() {
          _errorMessage =
              'Anmeldung fehlgeschlagen. Bitte prüfe deine Zugangsdaten.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Verbindungsfehler: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConfig.spacingXXLarge,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppConfig.loginFormMaxWidth,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- App-Logo / Titel ---
                  Icon(
                    Icons.warehouse_rounded,
                    size: AppConfig.loginLogoSize,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: AppConfig.spacingLarge),
                  Text(
                    'Lager-App',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppConfig.spacingSmall),
                  Text(
                    'Bitte melde dich an, um fortzufahren.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppConfig.spacingXXLarge + AppConfig.spacingSmall),

                  // --- Fehlermeldung ---
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppConfig.spacingMedium),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(
                          AppConfig.borderRadiusMedium,
                        ),
                        border: Border.all(
                          color: colorScheme.error
                              .withValues(alpha: AppConfig.opacityMedium),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: colorScheme.onErrorContainer,
                            size: AppConfig.iconSizeMedium,
                          ),
                          const SizedBox(width: AppConfig.spacingSmall),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppConfig.spacingLarge),
                  ],

                  // --- E-Mail-Feld ---
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'E-Mail',
                      hintText: 'user@lager.app',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Bitte E-Mail eingeben';
                      }
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(value.trim())) {
                        return 'Bitte gültige E-Mail eingeben';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppConfig.spacingLarge),

                  // --- Passwort-Feld ---
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _handleLogin(),
                    decoration: InputDecoration(
                      labelText: 'Passwort',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(
                              () => _obscurePassword = !_obscurePassword,);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Bitte Passwort eingeben';
                      }
                      if (value.length < 6) {
                        return 'Passwort muss mindestens 6 Zeichen haben';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppConfig.spacingXLarge),

                  // --- Anmelden-Button ---
                  SizedBox(
                    height: AppConfig.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const SizedBox(
                              height: AppConfig.progressIndicatorSizeSmall,
                              width: AppConfig.progressIndicatorSizeSmall,
                              child: CircularProgressIndicator(
                                strokeWidth: AppConfig.strokeWidthMedium,
                              ),
                            )
                          : Text(
                              'Anmelden',
                              style: textTheme.titleMedium,
                            ),
                    ),
                  ),
                  const SizedBox(height: AppConfig.spacingLarge),

                  // --- Passwort vergessen ---
                  TextButton(
                    onPressed: () => _showPasswordResetDialog(context),
                    child: const Text('Passwort vergessen?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Dialog für Passwort-Reset via PocketBase
  void _showPasswordResetDialog(BuildContext context) {
    final resetEmailController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Passwort zurücksetzen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Gib deine E-Mail-Adresse ein. '
              'Du erhältst einen Link zum Zurücksetzen.',
            ),
            const SizedBox(height: AppConfig.spacingLarge),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-Mail',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty) return;

              try {
                await _pbService.requestPasswordReset(email);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Falls die E-Mail existiert, wurde ein '
                        'Reset-Link gesendet.',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fehler: ${e.toString()}'),
                    ),
                  );
                }
              }
            },
            child: const Text('Absenden'),
          ),
        ],
      ),
    );
  }
}