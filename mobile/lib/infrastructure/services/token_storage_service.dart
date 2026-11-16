import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../commons/constants/storage_constants.dart';

/// Login tokens. Kept in the phone's secure storage (Keychain / Android Keystore), cached in memory.
abstract class ITokenStorage {
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> save(String access, String refresh);
  Future<void> clear();
}

class SecureTokenStorage implements ITokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  String? _access;
  String? _refresh;
  bool _loaded = false;

  Future<void> _load() async {
    if (_loaded) return;
    _access = await _storage.read(key: StorageConstants.accessToken);
    _refresh = await _storage.read(key: StorageConstants.refreshToken);
    _loaded = true;
  }

  @override
  Future<String?> readAccess() async {
    await _load();
    return _access;
  }

  @override
  Future<String?> readRefresh() async {
    await _load();
    return _refresh;
  }

  @override
  Future<void> save(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
    _loaded = true;
    await _storage.write(key: StorageConstants.accessToken, value: access);
    await _storage.write(key: StorageConstants.refreshToken, value: refresh);
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _loaded = true;
    await _storage.delete(key: StorageConstants.accessToken);
    await _storage.delete(key: StorageConstants.refreshToken);
  }
}
