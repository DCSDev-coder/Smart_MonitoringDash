import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import './cpanel_api_service.dart';
import '../utils/app_log.dart';

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

  void _logMissingPortalTokenIfNeeded() {
    if (AppConfig.isDemoMode) return;
    AppLog.d(
      'Adapter call skipped: portal auth token missing',
      tag: 'AdapterApi',
    );
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

  Map<String, dynamic>? _decodeErrorMap(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  Map<String, dynamic>? _decodeMap(http.Response res) {
    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<bool> registerPushToken(
      {required int siteId,
      required String deviceToken,
      required String platform}) async {
    if (!isConfigured) return false;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return false;
    }

    final url = Uri.parse('$_base/v1/user/push-token');
    try {
      final res = await http
          .post(
            url,
            headers: {
              ..._headers(token),
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'site_id': siteId,
              'device_token': deviceToken,
              'platform': platform,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        AppLog.w('registerPushToken non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
          'body': res.body,
        });
        return false;
      }

      return true;
    } catch (e) {
      AppLog.w('registerPushToken error', tag: 'AdapterApi', error: e);
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchPue({required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/pue');
    try {
      final res = await http
          .get(url, headers: _headers(token))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        AppLog.w('fetchPue non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchPue error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchAppConfig({required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/app-config');
    try {
      final res = await http
          .get(url, headers: _headers(token))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        AppLog.w('fetchAppConfig non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchAppConfig error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchPowerMonth({required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/power-month');
    try {
      final res = await http
          .get(url, headers: _headers(token))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        AppLog.w('fetchPowerMonth non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchPowerMonth error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchCabinetStats({required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/cabinet-stats');
    try {
      final res = await http
          .get(url, headers: _headers(token))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        AppLog.w('fetchCabinetStats non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchCabinetStats error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchRedisMemory({required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/redis-memory');
    try {
      final res = await http
          .get(url, headers: _headers(token))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        AppLog.w('fetchRedisMemory non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchRedisMemory error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchOurPueHourly({
    required int siteId,
    int hours = 24,
  }) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/our-pue-hourly').replace(
      queryParameters: <String, String>{
        'hours': hours.toString(),
      },
    );

    try {
      final res = await http
          .get(url, headers: _headers(token))
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        AppLog.w('fetchOurPueHourly non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchOurPueHourly error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchDoors({required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/doors');
    try {
      final res = await http
          .get(url, headers: _headers(token))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        AppLog.w('fetchDoors non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchDoors error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchRecentAlarms({required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/alarms/last5');
    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        AppLog.w('fetchRecentAlarms non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchRecentAlarms error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchTempHumTopN({required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/temp-hum-top-n');
    try {
      final res = await http
          .get(url, headers: _headers(token))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        AppLog.w('fetchTempHumTopN non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchTempHumTopN error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchItDeviceInterfaces(
      {required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url =
        Uri.parse('$_base/v1/sites/$siteId/it-device-interfaces-last-for-part');
    try {
      final res = await http
          .get(url, headers: _headers(token))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        AppLog.w('fetchItDeviceInterfaces non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchItDeviceInterfaces error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchItDeviceTopMetrics(
      {required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/it-device-top-metrics-last');
    try {
      final res = await http
          .get(url, headers: _headers(token))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        AppLog.w('fetchItDeviceTopMetrics non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchItDeviceTopMetrics error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchDashboardBundle(
      {required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/dashboard');
    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        AppLog.w('fetchDashboardBundle non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchDashboardBundle error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchEnvironment({required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/environment');
    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        AppLog.w('fetchEnvironment non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchEnvironment error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchDeviceStatus({required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/device-status');
    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        AppLog.w('fetchDeviceStatus non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchDeviceStatus error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchSysInfo({required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/sys-info');
    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        AppLog.w('fetchSysInfo non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchSysInfo error', tag: 'AdapterApi', error: e);
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
      _logMissingPortalTokenIfNeeded();
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
        AppLog.w('fetchAccessLogs non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchAccessLogs error', tag: 'AdapterApi', error: e);
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
      _logMissingPortalTokenIfNeeded();
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
        AppLog.w('fetchReportAlarms non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchReportAlarms error', tag: 'AdapterApi', error: e);
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
      _logMissingPortalTokenIfNeeded();
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
        AppLog.w('fetchReportBundle non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchReportBundle error', tag: 'AdapterApi', error: e);
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
      _logMissingPortalTokenIfNeeded();
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
        AppLog.w('fetchRange non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchRange error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchRackTelemetry(
      {required int siteId}) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/rack-telemetry');
    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        AppLog.w('fetchRackTelemetry non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchRackTelemetry error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchNodeWithMetric({
    required int siteId,
    required int nodeId,
  }) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/node-with-metric').replace(
      queryParameters: <String, String>{
        'nodeId': nodeId.toString(),
      },
    );
    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        AppLog.w('fetchNodeWithMetric non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('fetchNodeWithMetric error', tag: 'AdapterApi', error: e);
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
      _logMissingPortalTokenIfNeeded();
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
        AppLog.w('openCloseDoor non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('openCloseDoor error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> unlockWithPin({
    required int siteId,
    required int accessId,
    required String pin,
  }) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/doors/unlock-with-pin');
    try {
      final res = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'accessId': accessId,
              'pin': pin,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        final errorMap = _decodeErrorMap(res);
        AppLog.w('unlockWithPin non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return errorMap ??
            {
              'success': false,
              'message': 'Failed to unlock door.',
            };
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('unlockWithPin error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> unlockWithUserPin({
    required int siteId,
    required int accessId,
    required String pin,
  }) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/doors/unlock-with-user-pin');
    try {
      final res = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'accessId': accessId,
              'pin': pin,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        final errorMap = _decodeErrorMap(res);
        AppLog.w('unlockWithUserPin non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return errorMap ??
            {
              'success': false,
              'message': 'Failed to unlock door.',
            };
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('unlockWithUserPin error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<bool> setPin(String pin) async {
    if (!isConfigured) return false;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return false;
    }

    final url = Uri.parse('$_base/v1/user/set-pin');
    try {
      final res = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'pin': pin,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return res.statusCode == 200;
    } catch (e) {
      AppLog.w('setPin error', tag: 'AdapterApi', error: e);
      return false;
    }
  }

  Future<Map<String, dynamic>?> verifyPin(String pin) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url = Uri.parse('$_base/v1/user/verify-pin');
    try {
      final res = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'pin': pin,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        AppLog.w('verifyPin non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('verifyPin error', tag: 'AdapterApi', error: e);
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
      _logMissingPortalTokenIfNeeded();
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
        AppLog.w('writeNodeMetric non-200', tag: 'AdapterApi', fields: {
          'status': res.statusCode,
        });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('writeNodeMetric error', tag: 'AdapterApi', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> writeNodeMetricWithUserPin({
    required int siteId,
    required int nodeId,
    required String metricTypeLibCode,
    required Object value,
    required String pin,
  }) async {
    if (!isConfigured) return null;

    final token = _tokenOrNull();
    if (token == null) {
      _logMissingPortalTokenIfNeeded();
      return null;
    }

    final url =
        Uri.parse('$_base/v1/sites/$siteId/control/write-metric-with-user-pin');
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
              'pin': pin,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        AppLog.w('writeNodeMetricWithUserPin non-200',
            tag: 'AdapterApi',
            fields: {
              'status': res.statusCode,
            });
        return null;
      }

      return _decodeMap(res);
    } catch (e) {
      AppLog.w('writeNodeMetricWithUserPin error', tag: 'AdapterApi', error: e);
      return null;
    }
  }
}
