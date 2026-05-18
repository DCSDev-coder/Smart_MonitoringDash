import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'cctv_config_store_base.dart';

class MobileCctvConfigStore implements CctvConfigStore {
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> getString(String key) => _storage.read(key: key);

  @override
  Future<int?> getInt(String key) async {
    final value = await _storage.read(key: key);
    return value == null ? null : int.tryParse(value);
  }

  @override
  Future<bool?> getBool(String key) async {
    final value = await _storage.read(key: key);
    if (value == null) return null;
    return value == 'true';
  }

  @override
  Future<void> setString(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> setInt(String key, int value) => _storage.write(key: key, value: value.toString());

  @override
  Future<void> setBool(String key, bool value) => _storage.write(key: key, value: value.toString());

  @override
  Future<void> remove(String key) => _storage.delete(key: key);
}

CctvConfigStore createPlatformCctvConfigStore() => MobileCctvConfigStore();
