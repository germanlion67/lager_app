//lib/services/nextcloud_credentials.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NextcloudCredentials {
  final Uri server;
  final String user;
  final String appPw;
  final String baseFolder;

  const NextcloudCredentials({
    required this.server,
    required this.user,
    required this.appPw,
    required this.baseFolder,
  });
}

class NextcloudCredentialsStore {
  static const _storage = FlutterSecureStorage();

  static const _kServer = 'nc_server';
  static const _kUser = 'nc_username';
  static const _kAppPw = 'nc_apppw';
  static const _kBaseFolder = 'nc_basefolder';

  Future<void> save({
    required String serverBaseUrl, // z. B. https://cloud.example.com
    required String username,
    required String appPassword,
    String baseRemoteFolder = 'Apps/Artikel',
  }) async {
    await _storage.write(key: _kServer, value: serverBaseUrl);
    await _storage.write(key: _kUser, value: username);
    await _storage.write(key: _kAppPw, value: appPassword);
    await _storage.write(key: _kBaseFolder, value: baseRemoteFolder);
  }

  Future<NextcloudCredentials?> read() async {
    final s = await _storage.read(key: _kServer);
    final u = await _storage.read(key: _kUser);
    final p = await _storage.read(key: _kAppPw);
    final b = await _storage.read(key: _kBaseFolder) ?? 'Apps/Artikel';
    if (s == null || u == null || p == null) return null;
    return NextcloudCredentials(
      server: Uri.parse(s),
      user: u,
      appPw: p,
      baseFolder: b,
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _kServer);
    await _storage.delete(key: _kUser);
    await _storage.delete(key: _kAppPw);
    await _storage.delete(key: _kBaseFolder);
  }
}
