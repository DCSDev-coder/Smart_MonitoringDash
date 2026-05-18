import 'package:shared_preferences/shared_preferences.dart';
import 'cctv_config_store_base.dart';

class WebCctvConfigStore implements CctvConfigStore {
  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  @override
  Future<String?> getString(String key) async => (await _prefs).getString(key);

  @override
  Future<int?> getInt(String key) async => (await _prefs).getInt(key);

  @override
  Future<bool?> getBool(String key) async => (await _prefs).getBool(key);

  @override
  Future<void> setString(String key, String value) async =>
      (await _prefs).setString(key, value);

  @override
  Future<void> setInt(String key, int value) async => (await _prefs).setInt(key, value);

  @override
  Future<void> setBool(String key, bool value) async => (await _prefs).setBool(key, value);

  @override
  Future<void> remove(String key) async => (await _prefs).remove(key);
}

CctvConfigStore createPlatformCctvConfigStore() => WebCctvConfigStore();
