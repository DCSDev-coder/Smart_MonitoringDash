import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-configurable polling policy for unknown device/network specs.
///
/// This drives the *normal* (non-emergency) interval for [GlobalStatusPoller].
/// During emergencies, the poller still overrides to a fast interval regardless
/// of the chosen mode.
enum SmartPollingMode {
  auto,
  balanced,
  lowData,
  performance,
}

class SmartPollingSettings extends ChangeNotifier {
  SmartPollingSettings._();

  static final SmartPollingSettings instance = SmartPollingSettings._();

  static const _prefKey = 'smart_polling_mode';

  SmartPollingMode _mode = SmartPollingMode.auto;
  bool _loaded = false;

  SmartPollingMode get mode => _mode;
  bool get loaded => _loaded;

  Future<void> init() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      _mode = _decode(raw) ?? SmartPollingMode.auto;
    } catch (_) {
      _mode = SmartPollingMode.auto;
    } finally {
      _loaded = true;
    }
  }

  Future<void> setMode(SmartPollingMode next) async {
    if (_mode == next) return;
    _mode = next;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, _encode(next));
    } catch (_) {
      // Best-effort. Keep in-memory value even if persistence fails.
    }
  }

  Duration normalInterval() {
    switch (_mode) {
      case SmartPollingMode.auto:
        // Heuristic default:
        // - Web/desktop typically has stable power + network => faster.
        // - Mobile devices vary a lot => slightly slower by default.
        if (kIsWeb) return const Duration(seconds: 10);
        switch (defaultTargetPlatform) {
          case TargetPlatform.windows:
          case TargetPlatform.macOS:
          case TargetPlatform.linux:
            return const Duration(seconds: 10);
          case TargetPlatform.android:
          case TargetPlatform.iOS:
          case TargetPlatform.fuchsia:
            return const Duration(seconds: 15);
        }
      case SmartPollingMode.balanced:
        return const Duration(seconds: 15);
      case SmartPollingMode.lowData:
        return const Duration(seconds: 30);
      case SmartPollingMode.performance:
        return const Duration(seconds: 10);
    }
  }

  static SmartPollingMode? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final v in SmartPollingMode.values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  static String _encode(SmartPollingMode m) => m.name;
}

