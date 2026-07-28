// lib/screens/settings_state.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

const String showLastSyncPrefsKey = 'show_last_sync';
const bool defaultShowLastSync = true;

final showLastSyncProvider = StateProvider<bool>((ref) => defaultShowLastSync);