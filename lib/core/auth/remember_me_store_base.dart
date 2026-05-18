abstract class RememberMeStore {
  Future<bool> isEnabled();
  Future<void> setEnabled(bool enabled);

  Future<String?> getUsername();
  Future<void> setUsername(String username);

  // Token-based remember me (safe for web). Token is issued by backend on login.
  Future<String?> getAuthToken();
  Future<void> setAuthToken(String token);

  Future<void> clear();
}
