// lib/screens/settings_state.dart

import 'package:flutter/foundation.dart';

const String showLastSyncPrefsKey = 'show_last_sync';
const bool defaultShowLastSync = true;

final ValueNotifier<bool> showLastSyncNotifier =
    ValueNotifier<bool>(defaultShowLastSync);