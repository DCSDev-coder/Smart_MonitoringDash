import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'remember_me_store_base.dart';

class MobileRememberMeStore implements RememberMeStore {
  static const _storage = FlutterSecureStorage();

  static const _kEnabled = 'remember_me_enabled';
  static const _kUsername = 'remember_me_username';
  static const _kAuthToken = 'remember_me_auth_token';
  static const _kLegacyPassword = 'remember_me_password';

  @override
  Future<bool> isEnabled() async => (await _storage.read(key: _kEnabled)) == 'true';

  @override
  Future<void> setEnabled(bool enabled) =>
      _storage.write(key: _kEnabled, value: enabled.toString());

  @override
  Future<String?> getUsername() => _storage.read(key: _kUsername);

  @override
  Future<void> setUsername(String username) => _storage.write(key: _kUsername, value: username);

  @override
  Future<String?> getAuthToken() => _storage.read(key: _kAuthToken);

  @override
  Future<void> setAuthToken(String token) => _storage.write(key: _kAuthToken, value: token);

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kEnabled);
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kAuthToken);
    // Clean up any legacy password storage.
    await _storage.delete(key: _kLegacyPassword);
  }
}

RememberMeStore createRememberMeStore() => MobileRememberMeStore();
