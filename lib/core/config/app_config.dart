class AppConfig {
  AppConfig._();

  static const String appVariant = String.fromEnvironment(
    'APP_VARIANT',
    defaultValue: 'main',
  );

  static bool get isRackConsoleBuild =>
      appVariant.trim().toLowerCase() == 'rack_console';

  static String get appTitle =>
      isRackConsoleBuild ? 'DCS Rack Console' : 'DCS Dashboard';

  static const String _demoModeRaw = String.fromEnvironment(
    'DEMO_MODE',
    defaultValue: 'false',
  );

  static bool get isDemoMode {
    final v = _demoModeRaw.trim().toLowerCase();
    return v == '1' || v == 'true' || v == 'yes';
  }

  static const String _demoScenarioRotationRaw = String.fromEnvironment(
    'DEMO_SCENARIO_ROTATION',
    defaultValue: 'true',
  );

  static bool get demoScenarioRotationEnabled {
    final v = _demoScenarioRotationRaw.trim().toLowerCase();
    return v == '1' || v == 'true' || v == 'yes';
  }

  static const int demoScenarioSeconds = int.fromEnvironment(
    'DEMO_SCENARIO_SECONDS',
    defaultValue: 45,
  );

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

  // Adapter backend (proxy + normalizer)
  // flutter run --dart-define=ADAPTER_BASE_URL="https://api.example.com"
  static const String _adapterBaseUrlRaw = String.fromEnvironment(
    'ADAPTER_BASE_URL',
    defaultValue: '',
  );

  static String get adapterBaseUrl {
    final v = _adapterBaseUrlRaw.trim();
    if (v.isEmpty) return '';
    return v.endsWith('/') ? v.substring(0, v.length - 1) : v;
  }
}
