class AppConfig {
  AppConfig._();

  // Override via:
  // flutter run --dart-define=CPANEL_BASE_URL="https://example.com/api/index.php"
  // flutter run --dart-define=CPANEL_ASSET_BASE_URL="https://example.com/"
  static const String cpanelBaseUrl = String.fromEnvironment(
    'CPANEL_BASE_URL',
    defaultValue: 'https://dcstack.my/api/index.php',
  );

  static const String _cpanelAssetBaseUrlRaw = String.fromEnvironment(
    'CPANEL_ASSET_BASE_URL',
    defaultValue: 'https://dcstack.my/',
  );

  static String get cpanelAssetBaseUrl {
    final v = _cpanelAssetBaseUrlRaw.trim();
    if (v.isEmpty) return 'https://dcstack.my/';
    return v.endsWith('/') ? v : '$v/';
  }
}

