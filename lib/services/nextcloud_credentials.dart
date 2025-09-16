//lib/services/nextcloud_credentials.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NextcloudCredentials {
  final Uri server;
  final String user;
  final String appPw;
  final String baseFolder;
  final int checkIntervalMinutes;

  const NextcloudCredentials({
    required this.server,
    required this.user,
    required this.appPw,
    required this.baseFolder,
    this.checkIntervalMinutes = 10,
  });
}

class NextcloudCredentialsStore {
  static const _storage = FlutterSecureStorage();

  static const _kServer = 'nc_server';
  static const _kUser = 'nc_username';
  static const _kAppPw = 'nc_apppw';
  static const _kBaseFolder = 'nc_basefolder';
  static const _kCheckInterval = 'nc_check_interval';

  Future<void> save({
    required String serverBaseUrl, // z. B. https://cloud.example.com
    required String username,
    required String appPassword,
    String baseRemoteFolder = 'Apps/Artikel',
    int checkIntervalMinutes = 10,
  }) async {
    await _storage.write(key: _kServer, value: serverBaseUrl);
    await _storage.write(key: _kUser, value: username);
    await _storage.write(key: _kAppPw, value: appPassword);
    await _storage.write(key: _kBaseFolder, value: baseRemoteFolder);
    await _storage.write(key: _kCheckInterval, value: checkIntervalMinutes.toString());
  }

  Future<NextcloudCredentials?> read() async {
    final s = await _storage.read(key: _kServer);
    final u = await _storage.read(key: _kUser);
    final p = await _storage.read(key: _kAppPw);
    final b = await _storage.read(key: _kBaseFolder) ?? 'Apps/Artikel';
    final i = await _storage.read(key: _kCheckInterval);
    final checkInterval = int.tryParse(i ?? '10') ?? 10;
    
    if (s == null || u == null || p == null) return null;
    return NextcloudCredentials(
      server: Uri.parse(s),
      user: u,
      appPw: p,
      baseFolder: b,
      checkIntervalMinutes: checkInterval,
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _kServer);
    await _storage.delete(key: _kUser);
    await _storage.delete(key: _kAppPw);
    await _storage.delete(key: _kBaseFolder);
    await _storage.delete(key: _kCheckInterval);
  }
}
