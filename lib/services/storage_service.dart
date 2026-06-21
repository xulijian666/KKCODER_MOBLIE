import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _tokenKey = 'auth_token';
  static const _serverHostKey = 'server_host';
  static const _serverPortKey = 'server_port';
  static const _deviceNameKey = 'device_name';
  static const _httpsKey = 'use_https';

  final _storage = const FlutterSecureStorage();

  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  Future<String> getServerHost() async =>
      await _storage.read(key: _serverHostKey) ?? '';
  Future<void> saveServerHost(String host) =>
      _storage.write(key: _serverHostKey, value: host);

  Future<int?> getServerPort() async =>
      int.tryParse(await _storage.read(key: _serverPortKey) ?? '');
  Future<void> saveServerPort(int port) =>
      _storage.write(key: _serverPortKey, value: port.toString());

  Future<String> getDeviceName() async =>
      await _storage.read(key: _deviceNameKey) ?? 'Android Device';
  Future<void> saveDeviceName(String name) =>
      _storage.write(key: _deviceNameKey, value: name);

  Future<bool> getUseHttps() async =>
      await _storage.read(key: _httpsKey) == 'true';
  Future<void> saveUseHttps(bool value) =>
      _storage.write(key: _httpsKey, value: value.toString());
}
