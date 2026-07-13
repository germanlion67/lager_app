// lib/services/auth_store_factory_web.dart
//
// F-012.6: AsyncAuthStore für Web via localStorage.
// Verwendet package:web (Flutter 3.19+).

import 'package:pocketbase/pocketbase.dart';
import 'package:web/web.dart' as web;

const _storageKey = 'pb_auth';

Future<AsyncAuthStore> buildAuthStore() async {

  final stored = web.window.localStorage.getItem(_storageKey);

  return AsyncAuthStore(
    save: (data) async {
      // ignore: avoid_print
      print('[AuthStore] save → ${data.length} chars');
      web.window.localStorage.setItem(_storageKey, data);
    },
    clear: () async {
      // ignore: avoid_print
      print('[AuthStore] clear');
      web.window.localStorage.removeItem(_storageKey);
    },
    initial: stored,
  );
}