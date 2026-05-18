import 'package:flutter/foundation.dart';
import 'dart:convert';

/// Minimal app-wide logger.
///
/// Why this exists:
/// - Avoid leaking operational details / URLs / tokens in release builds.
/// - Keep debug noise manageable on device logs.
///
/// Use `AppLog.d(...)` for debug-only logs. In release, it becomes a no-op.
/// Use `AppLog.w(...)` for warning logs that are still safe to emit in release.
/// Use `AppLog.e(...)` for error logs; keep messages high-level and never log
/// credentials or tokens.
class AppLog {
  AppLog._();

  static void d(
    String message, {
    String tag = 'APP',
    Map<String, Object?>? fields,
  }) {
    if (!kDebugMode) return;
    _emit('D', tag, message, fields: fields);
  }

  static void i(
    String message, {
    String tag = 'APP',
    Map<String, Object?>? fields,
  }) {
    _emit('I', tag, message, fields: fields);
  }

  static void w(
    String message, {
    String tag = 'APP',
    Map<String, Object?>? fields,
    Object? error,
  }) {
    _emit('W', tag, message, fields: fields, error: error);
  }

  static void e(
    String message, {
    String tag = 'APP',
    Map<String, Object?>? fields,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _emit('E', tag, message, fields: fields, error: error, stackTrace: stackTrace);
  }

  static void _emit(
    String level,
    String tag,
    String message, {
    Map<String, Object?>? fields,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Keep logs single-line and grep-friendly.
    final ts = DateTime.now().toUtc().toIso8601String();
    final safeTag = tag.replaceAll(RegExp(r'\\s+'), '_');

    String suffix = '';
    if (fields != null && fields.isNotEmpty) {
      // Avoid throwing on non-JSON-able objects.
      final jsonSafe = <String, Object?>{};
      fields.forEach((k, v) {
        jsonSafe[k] = _jsonSafe(v);
      });
      suffix = ' ${jsonEncode(jsonSafe)}';
    }

    // ignore: avoid_print
    print('$ts [$level] $safeTag: $message$suffix');

    if (kDebugMode && error != null) {
      // ignore: avoid_print
      print('  error=${error.runtimeType}: $error');
    }
    if (kDebugMode && stackTrace != null) {
      // ignore: avoid_print
      print(stackTrace);
    }
  }

  static Object? _jsonSafe(Object? v) {
    if (v == null) return null;
    if (v is num || v is bool || v is String) return v;
    if (v is DateTime) return v.toIso8601String();
    if (v is Duration) return v.inMilliseconds;
    if (v is Uri) return '${v.scheme}://${v.host}${v.path}';
    if (v is List) return v.map(_jsonSafe).toList();
    if (v is Map) {
      final out = <String, Object?>{};
      v.forEach((k, val) => out['$k'] = _jsonSafe(val));
      return out;
    }
    return v.toString();
  }
}
