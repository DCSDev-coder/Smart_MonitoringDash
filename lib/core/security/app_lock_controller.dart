import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockController extends ChangeNotifier with WidgetsBindingObserver {
  AppLockController._();
  static final AppLockController instance = AppLockController._();
  static const String _enabledKey = 'app_lock_enabled';

  static const Duration timeout = Duration(seconds: 30);

  bool _enabled = !kIsWeb;
  bool _locked = false;
  bool _observerAttached = false;
  DateTime? _backgroundedAt;

  bool get isSupported => !kIsWeb;
  bool get isEnabled => _enabled;
  bool get isLocked => _enabled && _locked;
  String get timeoutLabel => '${timeout.inSeconds} seconds';

  Future<void> init() async {
    if (kIsWeb) {
      _enabled = false;
      _locked = false;
      _backgroundedAt = null;
      _syncObserver();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final nextEnabled = prefs.getBool(_enabledKey) ?? true;
    final changed = _enabled != nextEnabled;

    _enabled = nextEnabled;
    _syncObserver();

    if (changed) {
      notifyListeners();
    }
  }

  Future<void> setEnabled(bool value) async {
    final nextEnabled = !kIsWeb && value;
    final changed = _enabled != nextEnabled;

    _enabled = nextEnabled;
    if (!_enabled) {
      _locked = false;
      _backgroundedAt = null;
    }
    _syncObserver();

    if (!kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, nextEnabled);
    }

    if (changed) {
      notifyListeners();
    }
  }

  void prepareForHomeEntry({required bool requireImmediateUnlock}) {
    final nextLocked = _enabled && requireImmediateUnlock;
    final changed = _locked != nextLocked || _backgroundedAt != null;
    _locked = nextLocked;
    _backgroundedAt = null;
    _syncObserver();
    if (changed) {
      notifyListeners();
    }
  }

  void unlock() {
    if (!_enabled) return;
    if (_locked || _backgroundedAt != null) {
      _locked = false;
      _backgroundedAt = null;
      notifyListeners();
    }
  }

  void clear() {
    final hadState = _locked || _backgroundedAt != null;
    _locked = false;
    _backgroundedAt = null;
    _syncObserver();
    if (hadState) {
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled) return;

    switch (state) {
      case AppLifecycleState.resumed:
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (backgroundedAt == null) return;
        if (DateTime.now().difference(backgroundedAt) >= timeout) {
          if (!_locked) {
            _locked = true;
            notifyListeners();
          }
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _backgroundedAt ??= DateTime.now();
        break;
    }
  }

  void _syncObserver() {
    if (_enabled && !_observerAttached) {
      WidgetsBinding.instance.addObserver(this);
      _observerAttached = true;
      return;
    }
    if (!_enabled && _observerAttached) {
      WidgetsBinding.instance.removeObserver(this);
      _observerAttached = false;
    }
  }
}
