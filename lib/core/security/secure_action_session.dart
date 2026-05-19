class SecureActionSession {
  SecureActionSession._();
  static final SecureActionSession instance = SecureActionSession._();

  DateTime? _validUntil;

  bool get isValid {
    final until = _validUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  void grant({Duration ttl = const Duration(seconds: 30)}) {
    _validUntil = DateTime.now().add(ttl);
  }

  void clear() {
    _validUntil = null;
  }
}
