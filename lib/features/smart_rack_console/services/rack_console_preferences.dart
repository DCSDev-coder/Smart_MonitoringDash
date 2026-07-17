import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RackConsolePreferences extends ChangeNotifier {
  RackConsolePreferences._() {
    _load();
  }

  static final RackConsolePreferences instance = RackConsolePreferences._();

  static const String _use24HourKey = 'rack_console_use_24_hour_time';

  bool _use24HourTime = true;
  bool _loaded = false;

  bool get use24HourTime => _use24HourTime;
  bool get loaded => _loaded;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _use24HourTime = prefs.getBool(_use24HourKey) ?? true;
    } catch (_) {
      _use24HourTime = true;
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setUse24HourTime(bool value) async {
    if (_use24HourTime == value && _loaded) return;
    _use24HourTime = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_use24HourKey, value);
    } catch (_) {
      // Keep the in-memory selection even if persistence fails.
    }
  }

  String formatClock(DateTime dateTime) {
    final pattern = _use24HourTime ? 'HH:mm:ss' : 'hh:mm:ss a';
    return DateFormat(pattern).format(dateTime);
  }

  String formatTrendLabel(String stamp) {
    final trimmed = stamp.trim();
    if (trimmed.isEmpty) return '';

    final parsed = _tryParseDateTime(trimmed);
    if (parsed != null) {
      final pattern = _use24HourTime ? 'HH:mm' : 'hh:mm a';
      return DateFormat(pattern).format(parsed);
    }

    final match = RegExp(r'(\d{1,2}):(\d{2})(?::(\d{2}))?').firstMatch(trimmed);
    if (match != null) {
      final hour = int.tryParse(match.group(1) ?? '');
      final minute = int.tryParse(match.group(2) ?? '');
      final second = int.tryParse(match.group(3) ?? '0') ?? 0;
      if (hour != null && minute != null) {
        final date = DateTime(2000, 1, 1, hour, minute, second);
        final pattern = _use24HourTime ? 'HH:mm' : 'hh:mm a';
        return DateFormat(pattern).format(date);
      }
    }

    return trimmed.length > 5 ? trimmed.substring(trimmed.length - 5) : trimmed;
  }

  DateTime? _tryParseDateTime(String value) {
    final normalized = value.contains(' ') && !value.contains('T')
        ? value.replaceFirst(' ', 'T')
        : value;
    return DateTime.tryParse(normalized);
  }
}
