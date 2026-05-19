import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import './cpanel_api_service.dart';

class AdapterApiService {
  AdapterApiService._();
  static final AdapterApiService instance = AdapterApiService._();

  String get _base => AppConfig.adapterBaseUrl;

  bool get isConfigured => _base.isNotEmpty;

  String? _tokenOrNull() {
    final token = CpanelApiService.instance.getAuthTokenInMemory();
    if (token == null || token.trim().isEmpty) return null;
    return token;
  }

  Future<Map<String, dynamic>?> fetchPue({required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] Missing portal auth token in memory.');
      }
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/pue');
    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[AdapterApi] fetchPue non-200 (${res.statusCode}): ${res.body}');
        }
        return null;
      }

      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] fetchPue error: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchPowerMonth({required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] Missing portal auth token in memory.');
      }
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/power-month');
    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[AdapterApi] fetchPowerMonth non-200 (${res.statusCode}): ${res.body}');
        }
        return null;
      }

      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] fetchPowerMonth error: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchDoors({required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] Missing portal auth token in memory.');
      }
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/doors');
    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[AdapterApi] fetchDoors non-200 (${res.statusCode}): ${res.body}');
        }
        return null;
      }

      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] fetchDoors error: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchRecentAlarms({required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] Missing portal auth token in memory.');
      }
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/alarms/last5');
    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[AdapterApi] fetchRecentAlarms non-200 (${res.statusCode}): ${res.body}');
        }
        return null;
      }

      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] fetchRecentAlarms error: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchDashboardBundle({required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] Missing portal auth token in memory.');
      }
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/dashboard');
    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[AdapterApi] fetchDashboardBundle non-200 (${res.statusCode}): ${res.body}');
        }
        return null;
      }

      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] fetchDashboardBundle error: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchEnvironment({required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] Missing portal auth token in memory.');
      }
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/environment');
    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[AdapterApi] fetchEnvironment non-200 (${res.statusCode}): ${res.body}');
        }
        return null;
      }

      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] fetchEnvironment error: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchDeviceStatus({required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] Missing portal auth token in memory.');
      }
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/device-status');
    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[AdapterApi] fetchDeviceStatus non-200 (${res.statusCode}): ${res.body}');
        }
        return null;
      }

      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] fetchDeviceStatus error: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchSysInfo({required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] Missing portal auth token in memory.');
      }
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/sys-info');
    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[AdapterApi] fetchSysInfo non-200 (${res.statusCode}): ${res.body}');
        }
        return null;
      }

      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] fetchSysInfo error: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchAccessLogs({
    required int siteId,
    required int startTime,
    required int endTime,
    int page = 1,
    int pageSize = 20,
    String accessType = '1',
    int? accessId,
  }) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] Missing portal auth token in memory.');
      }
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/access-logs').replace(
      queryParameters: <String, String>{
        'pageNo': page.toString(),
        'pageSize': pageSize.toString(),
        'accessType': accessType,
        'startTime': startTime.toString(),
        'endTime': endTime.toString(),
        if (accessId != null) 'accessId': accessId.toString(),
      },
    );

    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[AdapterApi] fetchAccessLogs non-200 (${res.statusCode}): ${res.body}');
        }
        return null;
      }

      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] fetchAccessLogs error: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchReportAlarms({
    required int siteId,
    required int startTime,
    required int endTime,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] Missing portal auth token in memory.');
      }
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/report-alarms').replace(
      queryParameters: <String, String>{
        'pageNo': page.toString(),
        'pageSize': pageSize.toString(),
        'startTime': startTime.toString(),
        'endTime': endTime.toString(),
      },
    );

    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[AdapterApi] fetchReportAlarms non-200 (${res.statusCode}): ${res.body}');
        }
        return null;
      }

      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] fetchReportAlarms error: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchReportBundle({
    required int siteId,
    required int startTime,
    required int endTime,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] Missing portal auth token in memory.');
      }
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/report-bundle').replace(
      queryParameters: <String, String>{
        'pageNo': page.toString(),
        'pageSize': pageSize.toString(),
        'startTime': startTime.toString(),
        'endTime': endTime.toString(),
      },
    );

    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[AdapterApi] fetchReportBundle non-200 (${res.statusCode}): ${res.body}');
        }
        return null;
      }

      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] fetchReportBundle error: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchRange({
    required int siteId,
    required int nodeId,
    required String metricCode,
    required int startTime,
    required int endTime,
  }) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] Missing portal auth token in memory.');
      }
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/range').replace(
      queryParameters: <String, String>{
        'nodeId': nodeId.toString(),
        'metricCode': metricCode,
        'startTime': startTime.toString(),
        'endTime': endTime.toString(),
      },
    );

    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[AdapterApi] fetchRange non-200 (${res.statusCode}): ${res.body}');
        }
        return null;
      }

      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] fetchRange error: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> openCloseDoor({
    required int siteId,
    required int accessId,
    required int status,
    String accessType = '1',
  }) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] Missing portal auth token in memory.');
      }
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/doors/open-close');
    try {
      final res = await http
          .put(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'accessId': accessId,
              'status': status,
              'accessType': accessType,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[AdapterApi] openCloseDoor non-200 (${res.statusCode}): ${res.body}');
        }
        return null;
      }

      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] openCloseDoor error: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> writeNodeMetric({
    required int siteId,
    required int nodeId,
    required String metricTypeLibCode,
    required Object value,
  }) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] Missing portal auth token in memory.');
      }
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/control/write-metric');
    try {
      final res = await http
          .put(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'nodeId': nodeId,
              'metricTypeLibCode': metricTypeLibCode,
              'value': value,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[AdapterApi] writeNodeMetric non-200 (${res.statusCode}): ${res.body}');
        }
        return null;
      }

      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] writeNodeMetric error: $e');
      }
      return null;
    }
  }
}
