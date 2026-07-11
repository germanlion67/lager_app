// lib/services/auth_store_factory_native.dart
//
// F-012.6: AsyncAuthStore für Mobile/Desktop via SharedPreferences.

import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storageKey = 'pb_auth';

Future<AsyncAuthStore> buildAuthStore() async {
  // TODO: Nach Bestätigung des Fixes entfernen
  // ignore: avoid_print
  print('[AuthStore] ⚠️ Native-Implementierung aktiv (SharedPreferences)');

  final prefs = await SharedPreferences.getInstance();

  return AsyncAuthStore(
    save: (data) async {
      await prefs.setString(_storageKey, data);
    },
    clear: () async {
      await prefs.remove(_storageKey);
    },
    initial: prefs.getString(_storageKey),
  );
}