import 'package:shared_preferences/shared_preferences.dart';
import 'remember_me_store_base.dart';

class WebRememberMeStore implements RememberMeStore {
  static const _kEnabled = 'remember_me_enabled';
  static const _kUsername = 'remember_me_username';
  static const _kAuthToken = 'remember_me_auth_token';
  static const _kLegacyPassword = 'remember_me_password';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  @override
  Future<bool> isEnabled() async => (await _prefs).getBool(_kEnabled) ?? false;

  @override
  Future<void> setEnabled(bool enabled) async => (await _prefs).setBool(_kEnabled, enabled);

  @override
  Future<String?> getUsername() async => (await _prefs).getString(_kUsername);

  @override
  Future<void> setUsername(String username) async =>
      (await _prefs).setString(_kUsername, username);

  @override
  Future<String?> getAuthToken() async => (await _prefs).getString(_kAuthToken);

  @override
  Future<void> setAuthToken(String token) async =>
      (await _prefs).setString(_kAuthToken, token);

  @override
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_kEnabled);
    await prefs.remove(_kUsername);
    await prefs.remove(_kAuthToken);
    // Clean up any legacy password storage.
    await prefs.remove(_kLegacyPassword);
  }
}

RememberMeStore createRememberMeStore() => WebRememberMeStore();
