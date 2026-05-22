import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../utils/app_log.dart';

/// Handles all HTTP communication with the Dahua eCTRL-IS backend.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final _storage = <String, String>{};
  final _client = http.Client();
  String? _baseUrl;
  int _rid = 0;
  final Map<String, String> _pueRegionIdByCabinetId = {};

  static const String _keyBaseUrl = 'server_ip';

  String? get token => _storage[AppConstants.keyAccessToken];
  String? get baseUrl => _baseUrl;

  /// Call this on app startup to load the last used IP.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_keyBaseUrl);
  }

  Future<bool> login(String username, String password, {String? ip}) async {
    // If an IP is provided (from the UI), update and persist it.
    if (ip != null && ip.isNotEmpty) {
      await updateBaseUrl(ip);
    }

    final target = _baseUrl ?? AppConstants.defaultBaseUrl;
    // Strip protocol if present for Uri.http
    final cleanIp = target.replaceFirst(RegExp(r'https?://'), '');
    final url = Uri.http(cleanIp, AppConstants.loginPath);
    final rid = ++_rid;

    try {
      final sw = Stopwatch()..start();
      AppLog.i('login request', tag: 'NET', fields: {
        'rid': rid,
        'host': cleanIp,
        'path': AppConstants.loginPath,
      });
      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'password': password,
              'checkKey': '',
              'remember_me': false,
            }),
          )
          .timeout(const Duration(seconds: 10));

      sw.stop();
      AppLog.i('login response', tag: 'NET', fields: {
        'rid': rid,
        'status': response.statusCode,
        'ms': sw.elapsedMilliseconds,
      });

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          final result = body['result'] as Map<String, dynamic>?;
          final token = result?['token'] as String?;
          if (token != null) {
            _storage[AppConstants.keyAccessToken] = token;
            _storage[AppConstants.keyUsername] = username;
            return true;
          }
        }
      }
      return false;
    } on TimeoutException catch (e, st) {
      AppLog.e('login timeout', tag: 'NET', error: e, stackTrace: st, fields: {
        'rid': rid,
        'host': cleanIp,
        'path': AppConstants.loginPath,
        'timeout_s': 10,
      });
      return false;
    } catch (e, st) {
      AppLog.e('login failed', tag: 'NET', error: e, stackTrace: st, fields: {
        'rid': rid,
        'host': cleanIp,
        'path': AppConstants.loginPath,
      });
      return false;
    }
  }

  Future<void> updateBaseUrl(String ip) async {
    _baseUrl = ip;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, ip);
  }

  static String _xSign(String path, Map<String, String>? query) {
    final q = query ?? {};
    if (path.contains('getPower')) {
      return q['powerType'] == '1'
          ? AppConstants.xSignGetPowerMonth
          : AppConstants.xSignGetPowerToday;
    }
    if (path.contains('byTypeForStatus') && q['rangeType'] == '1') {
      return 'B586C31039FA8A0754B01646A7BBD8E5';
    }
    if (path.contains('forAlarmByRange')) {
      return 'D296867CEFAC1B142215D23D3B27548B';
    }
    if (path.contains('last5WithCabinet')) {
      return '701B6581FCDC535F9B0EE55A4A5F73EA';
    }
    if (path.contains('checkPue')) {
      return 'ABBA792021B709D79854FA9503D1FF30';
    }
    if (path.contains('getCurrentPue')) {
      return 'BDEE34CCCAD55816BDE344758457B5C1';
    }
    if (path.contains('pueRegion/getAll')) {
      return '9C85FCC34A7ACF3B7D909D1EB45E3507';
    }
    if (path.contains('cabinet/tree')) {
      return '461CBDA413089067DADD90FF81C5693E';
    }
    if (path.contains('cabinetEnv')) {
      return 'E0D73B3F9CED2EEBC298A9D267FE987E';
    }
    if (path.contains('dataTest/range')) {
      return '2947F38FA23FF1AFDE874541533E092C';
    }
    if (q.containsKey('powerEnv')) {
      return '2947F38FA23FF1AFDE874541533E092C';
    }

    if (path.contains('sysInfo')) {
      return 'E19D6243CB1945AB4F7202A1B00F77D5';
    }
    if (path.contains('actuator/redis/info')) {
      return 'E19D6243CB1945AB4F7202A1B00F77D5';
    }
    if (path.contains('actuator/redis/memoryInfo')) {
      return 'E19D6243CB1945AB4F7202A1B00F77D5';
    }
    if (path.contains('gate/listByLocationId')) {
      return '31DAD80CDF8CE1A1A6E172DB9A43C0A3';
    }
    if (path.contains('cabinet/mangeListByLocationId')) {
      return 'C515065BEAC6599D80BF3BF1246B3330';
    }
    if (path.contains('log/openClose') ||
        path.contains('log/query') ||
        path.contains('log/list') ||
        path.contains('log/page')) {
      return '1480D6E26ECFAF81F66498F8152EFB38';
    }
    if (path.contains('camera/forCabinet')) {
      return '31DAD80CDF8CE1A1A6E172DB9A43C0A3';
    }
    if (path.contains('cameraGroup/list')) {
      return '31DAD80CDF8CE1A1A6E172DB9A43C0A3';
    }

    // Fallback for PUE/Power if specific ones above didn't match or failed
    if (path.contains('pueRegion') || path.contains('getPower')) {
      return 'E19D6243CB1945AB4F7202A1B00F77D5';
    }

    return 'E19D6243CB1945AB4F7202A1B00F77D5';
  }

  Future<void> logout() async => _storage.clear();

  Future<String?> get _token async => _storage[AppConstants.keyAccessToken];
  Future<String?> getUsername() async => _storage[AppConstants.keyUsername];

  Future<Map<String, String>> _buildHeaders(String path,
      {Map<String, String>? query}) async {
    final token = await _token ?? '';
    final now = DateTime.now().toUtc();
    final ts = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    return {
      'Accept': 'application/json, text/plain, */*',
      'X-Access-Token': token,
      'X-TIMESTAMP': ts,
      'X-Sign': _xSign(path, query),
    };
  }

  Future<Map<String, dynamic>?> _get(String path,
      {Map<String, String>? query}) async {
    final t = AppConstants.timestamp();
    final params = {'_t': t, ...?query};
    final target = _baseUrl ?? AppConstants.defaultBaseUrl;
    final cleanIp = target.replaceFirst(RegExp(r'https?://'), '');
    final rid = ++_rid;

    final url = Uri.http(cleanIp, path, params);
    try {
      final sw = Stopwatch()..start();
      final headers = await _buildHeaders(path, query: query);
      AppLog.d('GET start', tag: 'NET', fields: {
        'rid': rid,
        'host': cleanIp,
        'path': path,
        // Query values are generally non-sensitive (ids, paging, ranges) and are
        // essential for debugging mismatched "id" semantics across endpoints.
        // Login uses POST and is logged separately without credentials.
        'q': query ?? const <String, String>{},
      });
      final response = await _client
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 8));
      sw.stop();

      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          AppLog.d('GET ok', tag: 'NET', fields: {
            'rid': rid,
            'path': path,
            'status': response.statusCode,
            'ms': sw.elapsedMilliseconds,
            'bytes': response.bodyBytes.length,
            'q': query ?? const <String, String>{},
          });
          return decoded;
        } catch (e, st) {
          AppLog.e('GET json decode failed',
              tag: 'NET',
              error: e,
              stackTrace: st,
              fields: {
                'rid': rid,
                'path': path,
                'status': response.statusCode,
                'ms': sw.elapsedMilliseconds,
                'bytes': response.bodyBytes.length,
              });
          return null;
        }
      } else {
        AppLog.w('GET non-200', tag: 'NET', fields: {
          'rid': rid,
          'path': path,
          'status': response.statusCode,
          'ms': sw.elapsedMilliseconds,
          'bytes': response.bodyBytes.length,
          'q': query ?? const <String, String>{},
        });
        if (kDebugMode) {
          final body = response.body;
          final snippet =
              body.length > 180 ? '${body.substring(0, 180)}...' : body;
          AppLog.d('GET non-200 body', tag: 'NET', fields: {
            'rid': rid,
            'path': path,
            'snippet': snippet,
          });
        }
      }
    } on TimeoutException catch (e, st) {
      AppLog.w('GET timeout', tag: 'NET', error: e, fields: {
        'rid': rid,
        'path': path,
        'timeout_s': 8,
        'host': cleanIp,
      });
      if (kDebugMode) {
        AppLog.e('GET timeout stack',
            tag: 'NET',
            error: e,
            stackTrace: st,
            fields: {'rid': rid, 'path': path});
      }
    } catch (e, st) {
      AppLog.e('GET failed', tag: 'NET', error: e, stackTrace: st, fields: {
        'rid': rid,
        'path': path,
        'host': cleanIp,
      });
    }
    return null;
  }

  Future<String?> _resolvePueRegionIdForCabinet(String cabinetId) async {
    final cached = _pueRegionIdByCabinetId[cabinetId];
    if (cached != null && cached.isNotEmpty) return cached;

    final res = await _get(
      AppConstants.pueRegionAllPath,
      // Matches the web UI request shape seen in the office HAR.
      query: const {'notCabinet': 'false', 'started': 'false'},
    );

    final list = res?['result'];
    if (list is! List) return null;

    String norm(String v) => v.trim().toLowerCase();

    Map<String, dynamic>? pick;
    for (final it in list) {
      if (it is Map<String, dynamic>) {
        final cId = it['cabinetId'];
        final cCode = it['cabinetCode'] ?? it['cabinetNo'] ?? it['cabinetSN'];
        if (cId != null && cId.toString() == cabinetId) {
          pick = it;
          break;
        }
        if (cCode != null && norm(cCode.toString()) == norm(cabinetId)) {
          pick = it;
          break;
        }
      }
    }
    // If there's no cabinet match, do NOT silently pick the first entry.
    // Different deployments map sites/cabinets to different pueRegion ids; a
    // wrong id often yields sentinel PUE values like -1/0.
    if (pick == null) return null;

    final regionId = pick['id']?.toString();
    if (regionId != null && regionId.isNotEmpty) {
      _pueRegionIdByCabinetId[cabinetId] = regionId;
    }
    return regionId;
  }

  Future<Map<String, dynamic>?> _put(String path, Map<String, dynamic> body,
      {Map<String, String>? query}) async {
    final t = AppConstants.timestamp();
    final params = {'_t': t, ...?query};
    final target = _baseUrl ?? AppConstants.defaultBaseUrl;
    final cleanIp = target.replaceFirst(RegExp(r'https?://'), '');
    final rid = ++_rid;

    final url = Uri.http(cleanIp, path, params);
    try {
      final sw = Stopwatch()..start();
      final headers = await _buildHeaders(path, query: query);
      headers['Content-Type'] = 'application/json';
      AppLog.d('PUT start', tag: 'NET', fields: {
        'rid': rid,
        'host': cleanIp,
        'path': path,
        'q': (query ?? {}).keys.toList(),
      });
      final response = await _client
          .put(url, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));
      sw.stop();
      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          AppLog.d('PUT ok', tag: 'NET', fields: {
            'rid': rid,
            'path': path,
            'status': response.statusCode,
            'ms': sw.elapsedMilliseconds,
            'bytes': response.bodyBytes.length,
            'q': (query ?? {}).keys.toList(),
          });
          return decoded;
        } catch (e, st) {
          AppLog.e('PUT json decode failed',
              tag: 'NET',
              error: e,
              stackTrace: st,
              fields: {
                'rid': rid,
                'path': path,
                'status': response.statusCode,
                'ms': sw.elapsedMilliseconds,
                'bytes': response.bodyBytes.length,
              });
          return null;
        }
      } else {
        AppLog.w('PUT non-200', tag: 'NET', fields: {
          'rid': rid,
          'path': path,
          'status': response.statusCode,
          'ms': sw.elapsedMilliseconds,
          'bytes': response.bodyBytes.length,
          'q': (query ?? {}).keys.toList(),
        });
        if (kDebugMode) {
          final body = response.body;
          final snippet =
              body.length > 180 ? '${body.substring(0, 180)}...' : body;
          AppLog.d('PUT non-200 body', tag: 'NET', fields: {
            'rid': rid,
            'path': path,
            'snippet': snippet,
          });
        }
      }
    } on TimeoutException catch (e, st) {
      AppLog.w('PUT timeout', tag: 'NET', error: e, fields: {
        'rid': rid,
        'path': path,
        'timeout_s': 10,
        'host': cleanIp,
      });
      if (kDebugMode) {
        AppLog.e('PUT timeout stack',
            tag: 'NET',
            error: e,
            stackTrace: st,
            fields: {'rid': rid, 'path': path});
      }
    } catch (e, st) {
      AppLog.e('PUT failed', tag: 'NET', error: e, stackTrace: st, fields: {
        'rid': rid,
        'path': path,
        'host': cleanIp,
      });
    }
    return null;
  }

  // -------------------- Data endpoints --------------------
  Future<Map<String, dynamic>?> fetchTempHumTopN() =>
      _get(AppConstants.tempHumTopNPath);
  Future<Map<String, dynamic>?> fetchCabinetEnv() =>
      _get(AppConstants.cabinetEnvPath,
          query: {'deviceTypeCodes': 'temperature,somking,flooding'});
  Future<Map<String, dynamic>?> fetchEnvironment() =>
      _get(AppConstants.environmentPath);
  Future<Map<String, dynamic>?> fetchDeviceStatus() =>
      _get(AppConstants.deviceStatusPath,
          query: {'powerEnv': 'true', 'rangeType': '1'});
  Future<Map<String, dynamic>?> fetchAlarmsByLevel() =>
      _get(AppConstants.alarmByLevelPath, query: {'powerEnv': 'true'});
  Future<Map<String, dynamic>?> fetchAlarmRecovery() =>
      _get(AppConstants.alarmRecoveryPath, query: {'powerEnv': 'true'});
  Future<Map<String, dynamic>?> fetchRecentAlarms() =>
      _get(AppConstants.alarmLastNPath,
          query: {'powerEnv': 'true', 'rangeType': '0', 'lastN': '20'});
  Future<Map<String, dynamic>?> fetchCabinetStats() =>
      _get(AppConstants.cabinetStatsPath, query: {'powerEnv': 'true'});
  Future<Map<String, dynamic>?> fetchSysInfo() =>
      _get(AppConstants.sysInfoPath);
  Future<Map<String, dynamic>?> fetchRedisInfo() =>
      _get(AppConstants.redisInfoPath);
  Future<Map<String, dynamic>?> fetchRedisMemory() =>
      _get(AppConstants.redisMemoryPath);
  Future<Map<String, dynamic>?> fetchGates() => _get(AppConstants.gateListPath,
      query: {'locationId': '1', 'locationType': '1'});
  Future<Map<String, dynamic>?> fetchMonitorData({int cabinetId = 1}) =>
      _get(AppConstants.findMonitorDataPath, query: {
        'powerEnv': 'true',
        'rangeType': '1',
        'cabinetId': cabinetId.toString(),
      });

  /// Fetches ALL metrics for a node in one call from the verified production endpoint.
  /// Response: { result: { id, name, metrics: [{ code, value, codeUnit, ... }] } }
  Future<Map<String, dynamic>?> fetchNodeWithMetric(int nodeId) => _get(
        AppConstants.getWithMetricPath,
        query: {'id': nodeId.toString()},
      );

  /// Fetches paginated metrics for a node. Use page=1 for the first set.
  /// Response: { result: { records: [{ code, value, codeUnit, ... }], total, pages } }
  Future<Map<String, dynamic>?> fetchNodeMetrics(int nodeId, {int page = 1}) =>
      _get(
        AppConstants.listMetricPath,
        query: {
          'pageNo': page.toString(),
          'pageSize': '100', // Large size to get all in one page
          'id': nodeId.toString(),
          'view': 'true',
        },
      );

  /// Writes a control metric to a node (e.g. PDU outlet on/off).
  ///
  /// Verified from vendor HAR:
  /// PUT /itom/monitor/collectControlNode/writeMetric
  /// body: { "value": <num|string>, "metricTypeLibCode": "<code>", "id": <nodeId> }
  Future<Map<String, dynamic>?> writeNodeMetric({
    required int nodeId,
    required String metricTypeLibCode,
    required Object value,
  }) =>
      _put(AppConstants.writeMetricPath, {
        'value': value,
        'metricTypeLibCode': metricTypeLibCode,
        'id': nodeId,
      });

  /// Lists Power Environment nodes (vendor "view/listPowerEnv" page).
  /// Used to discover AC / environment devices shown in the control center.
  Future<Map<String, dynamic>?> fetchPowerEnvNodes({
    int page = 1,
    int pageSize = 10,
    String? name,
  }) =>
      _get(
        AppConstants.listPowerEnvPath,
        query: {
          'pageNo': page.toString(),
          'pageSize': pageSize.toString(),
          if (name != null && name.isNotEmpty) 'name': name,
        },
      );

  Future<Map<String, dynamic>?> fetchHistoricalData({
    required int nodeId,
    required String metricCode,
    required int startTime,
    required int endTime,
  }) =>
      _get(AppConstants.rangeDataPath, query: {
        'collectControlNodeId': nodeId.toString(),
        'metricTypeLibCode': metricCode,
        'startTime': startTime.toString(),
        'endTime': endTime.toString(),
      });

  Future<Map<String, dynamic>?> fetchReportAlarms({
    required int startTime,
    required int endTime,
    int page = 1,
  }) =>
      _get('/itom/monitor/alarm/listForReport', query: {
        'pageNo': page.toString(),
        'pageSize': '20',
        'startTime': startTime.toString(),
        'endTime': endTime.toString(),
        'powerEnv': 'true',
      });

  Future<Map<String, dynamic>?> fetchCabinetDoors({int cabinetId = 1}) =>
      _get(AppConstants.cabinetDoorListPath,
          query: {'cabinetId': cabinetId.toString()});
  Future<Map<String, dynamic>?> openCloseDoor(int accessId, int status,
          {bool isCabinet = true}) =>
      _put(AppConstants.openCloseDoorPath, {
        "accessId": accessId,
        "accessType": isCabinet ? "1" : "0",
        "status": status
      });

  Future<Map<String, dynamic>?> fetchDoorAccessLogs({
    required int startTime,
    required int endTime,
    int page = 1,
    int pageSize = 20,
    int? accessId,
    String accessType = '1',
    int cabinetId = 1,
    int locationId = 1,
  }) {
    final startDt = DateTime.fromMillisecondsSinceEpoch(startTime);
    final endDt = DateTime.fromMillisecondsSinceEpoch(endTime);

    String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    final query = <String, String>{
      'pageNo': page.toString(),
      'pageSize': pageSize.toString(),
      'accessType': accessType,
      'opTime_begin': ymd(startDt),
      'opTime_end': ymd(endDt),
      'column': 'opTime',
      'order': 'desc',
      if (accessType == '1') 'cabinetId': cabinetId.toString(),
      if (accessType == '0') 'locationId': locationId.toString(),
      if (accessType == '0') 'locationType': '1',
      if (accessId != null) 'accessId': accessId.toString(),
    };

    return _get(AppConstants.accessLogPath, query: query);
  }

  Future<Map<String, dynamic>?> fetchPowerToday() =>
      _get(AppConstants.getPowerPath,
          query: {'powerType': '0', 'id': '1', 'all': 'true'});
  Future<Map<String, dynamic>?> fetchPowerMonth({String? id}) =>
      _get(AppConstants.getPowerPath, query: {
        'powerType': '1',
        'id': id ?? '1',
        'all': 'true',
      });

  /// Fetch current PUE value.
  ///
  /// The web UI (and office HAR) uses `pueRegion/getCurrentPue?id=...`, which
  /// returns `{ result: { pue: <num>, power: <num> } }`.
  ///
  /// `checkPue` can legitimately return `result=false` even when PUE exists,
  /// so we prefer `getCurrentPue` for the dashboard indicator.
  Future<Map<String, dynamic>?> fetchPue({String? id}) async {
    // IMPORTANT: In the web UI, `getCurrentPue` expects the *pueRegion id*,
    // while the app has historically used "siteId"/"cabinetId" semantics.
    // We treat the incoming `id` as cabinetId and resolve pueRegion id via
    // `pueRegion/getAll`.
    final cabinetId = (id == null || id.isEmpty) ? '1' : id;
    final resolved = await _resolvePueRegionIdForCabinet(cabinetId);
    final regionId =
        (resolved == null || resolved.isEmpty) ? cabinetId : resolved;
    if (kDebugMode && resolved == null) {
      AppLog.w('PUE region id not found via getAll; falling back to cabinetId',
          tag: 'NET',
          fields: {
            'cabinetId': cabinetId,
            'fallbackRegionId': regionId,
          });
    }
    final res =
        await _get(AppConstants.pueCurrentPath, query: {'id': regionId});

    // Some deployments respond with { success: true, result: null } for unknown
    // ids (e.g. when given a cabinet code like "CAB-01" instead of a region id).
    // If we couldn't resolve a region id and got a null result, retry a common
    // single-site fallback id=1 as best-effort.
    if ((resolved == null || resolved.isEmpty) &&
        res is Map<String, dynamic> &&
        res['result'] == null &&
        cabinetId != '1') {
      AppLog.w('PUE null result; retrying with id=1 fallback',
          tag: 'NET',
          fields: {
            'cabinetId': cabinetId,
            'attemptedId': regionId,
          });
      return _get(AppConstants.pueCurrentPath, query: const {'id': '1'});
    }

    if (kDebugMode && res != null && res['result'] == false) {
      AppLog.d('PUE getCurrentPue returned result=false', tag: 'NET', fields: {
        'path': AppConstants.pueCurrentPath,
        'q': {'id': regionId, 'cabinetId': cabinetId},
        'resp': res,
      });
    }
    return res;
  }

  /// Fetch whether PUE is "enabled" per backend. Useful for diagnostics only.
  Future<Map<String, dynamic>?> fetchPueAvailability({String? id}) =>
      _get(AppConstants.pueCheckPath, query: id != null ? {'id': id} : null);
  Future<Map<String, dynamic>?> fetchCameras({int cabinetId = 1}) =>
      _get(AppConstants.cameraListPath,
          query: {'cabinetId': cabinetId.toString()});
  Future<Map<String, dynamic>?> fetchCameraGroups() =>
      _get(AppConstants.cameraGroupPath);
  Future<Map<String, dynamic>?> restartCamera(int cameraId) =>
      _put(AppConstants.cameraRestartPath, {"id": cameraId});
}
