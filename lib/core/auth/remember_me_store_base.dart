abstract class RememberMeStore {
  Future<bool> isEnabled();
  Future<void> setEnabled(bool enabled);

  Future<String?> getUsername();
  Future<void> setUsername(String username);

  Future<String?> getAuthToken();
  Future<void> setAuthToken(String token);

  Future<void> clear();
}
