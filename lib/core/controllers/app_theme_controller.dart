import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central theme-mode source of truth.
///
/// We keep this small and synchronous for UI usage:
/// - call [init] during app boot (best-effort)
/// - widgets read [themeMode] and listen for changes
class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();

  static const _prefKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get loaded => _loaded;

  Future<void> init() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      _themeMode = _decode(raw) ?? ThemeMode.dark;
    } catch (_) {
      _themeMode = ThemeMode.dark;
    } finally {
      _loaded = true;
    }
  }

  Future<void> setThemeMode(ThemeMode next) async {
    if (_themeMode == next) return;
    _themeMode = next;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, _encode(next));
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> toggleDarkMode(bool dark) =>
      setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);

  static ThemeMode? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final v in ThemeMode.values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  static String _encode(ThemeMode m) => m.name;
}
