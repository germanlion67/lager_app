// lib/screens/settings_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_controller.dart';
import 'settings_state.dart';

/// O-021 Schritt 4: Der [SettingsController] lebt im Provider statt im
/// Widget-State. `autoDispose` gibt ihn (inkl. TextEditingControllern) frei,
/// sobald kein Listener mehr aktiv ist.
final settingsControllerProvider =
    ChangeNotifierProvider.autoDispose<SettingsController>((ref) {
  return SettingsController(
    onShowLastSyncChanged: (value) =>
        ref.read(showLastSyncProvider.notifier).state = value,
  );
});
