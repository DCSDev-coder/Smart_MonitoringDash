import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import '../utils/app_log.dart';
import '../config/app_config.dart';

class CpanelApiService extends ChangeNotifier {
  CpanelApiService._();
  static final CpanelApiService instance = CpanelApiService._();

  static String get baseUrl => AppConfig.cpanelBaseUrl;
  static String get baseAssetUrl => AppConfig.cpanelAssetBaseUrl;
  static const String _keyPortalUsername = 'cpanel_username';
  static const String _keyPortalUserId = 'cpanel_user_id';

  Map<String, dynamic>? currentSite;
  Map<String, dynamic>? currentAppConfig;
  Map<String, dynamic>? currentUser;

  String? _portalUsername;
  int? _portalUserId;
  // In-memory only (cleared on logout/app restart). Used to avoid re-prompting
  // the admin for routine actions within the same session.
  String? _portalPasswordInMemory;
  // API auth token (short-lived for normal sessions; long-lived when remember_me=true).
  // Stored in-memory only; persistence is handled by RememberMeStore.
  String? _portalAuthToken;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _portalUsername = prefs.getString(_keyPortalUsername);
    _portalUserId = prefs.getInt(_keyPortalUserId);
  }

  Future<void> _persistPortalSession({
    required String username,
    required int? userId,
  }) async {
    _portalUsername = username;
    _portalUserId = userId;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPortalUsername, username);

    if (userId != null) {
      await prefs.setInt(_keyPortalUserId, userId);
    } else {
      await prefs.remove(_keyPortalUserId);
    }
  }

  Future<void> clearSession() async {
    _portalUsername = null;
    _portalUserId = null;
    _portalPasswordInMemory = null;
    _portalAuthToken = null;
    currentSite = null;
    currentAppConfig = null;
    currentUser = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPortalUsername);
    await prefs.remove(_keyPortalUserId);
  }

  String? getPortalPasswordInMemory() => _portalPasswordInMemory;
  String? getAuthTokenInMemory() => _portalAuthToken;

  void setAuthTokenInMemory(String? token) {
    _portalAuthToken = token;
  }

  Map<String, String> _authHeaders({Map<String, String>? extra}) {
    final h = <String, String>{};
    if (_portalAuthToken != null && _portalAuthToken!.isNotEmpty) {
      // Primary: standard Bearer auth.
      h['Authorization'] = 'Bearer $_portalAuthToken';
      // Fallback: some shared-hosting Apache/PHP configs strip Authorization.
      // Backend accepts these as a backup path.
      h['X-Auth-Token'] = _portalAuthToken!;
    }
    if (extra != null) h.addAll(extra);
    return h;
  }

  bool isTruthyFlag(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;

    final normalized = value.toString().trim().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }

  bool isAdminRoleValue(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'admin' ||
        normalized == 'site_admin' ||
        normalized == 'site admin';
  }

  bool isCurrentUserSiteOwner({
    Map<String, dynamic>? site,
    int? portalUserId,
  }) {
    final target = site ?? currentSite;
    if (target == null) return false;

    final effectiveUserId = portalUserId ?? _portalUserId;
    final ownerId = int.tryParse(
      (target['owner_user_id'] ?? target['owner_id'] ?? target['user_id'])
              ?.toString() ??
          '',
    );

    return effectiveUserId != null &&
        ownerId != null &&
        effectiveUserId == ownerId;
  }

  bool currentSiteHasAdminRole({Map<String, dynamic>? site}) {
    final target = site ?? currentSite;
    if (target == null) return false;

    return isAdminRoleValue(target['role']) ||
        isAdminRoleValue(target['site_role']) ||
        isAdminRoleValue(target['member_role']) ||
        isAdminRoleValue(currentUser?['role']);
  }

  bool canCurrentSiteChangeSettings({
    Map<String, dynamic>? site,
    int? portalUserId,
  }) {
    final target = site ?? currentSite;
    if (target == null) return false;

    return isCurrentUserSiteOwner(site: target, portalUserId: portalUserId) ||
        currentSiteHasAdminRole(site: target) ||
        isTruthyFlag(target['can_change_settings']);
  }

  String? currentCompanyLogoUrl([Map<String, dynamic>? site]) {
    final target = site ?? currentSite;
    if (target == null) return null;

    final rawLogo = target['company_logo_path']?.toString().trim() ?? '';
    if (rawLogo.isEmpty) return null;

    final resolved =
        rawLogo.startsWith('http://') || rawLogo.startsWith('https://')
            ? rawLogo
            : '$baseAssetUrl$rawLogo';

    final revision = target['_company_logo_cache_buster']?.toString().trim();
    if (revision == null || revision.isEmpty) return resolved;

    final separator = resolved.contains('?') ? '&' : '?';
    return '$resolved${separator}v=$revision';
  }

  void updateCurrentSiteLogo(String logoPathOrUrl) {
    final site = currentSite;
    if (site == null) return;

    site['company_logo_path'] = logoPathOrUrl;
    site['_company_logo_cache_buster'] =
        DateTime.now().millisecondsSinceEpoch.toString();
    notifyListeners();
  }

  bool isCurrentSiteKiosk([Map<String, dynamic>? site]) {
    final target = site ?? currentSite;
    return isTruthyFlag(target?['is_kiosk']);
  }

  bool isCurrentSiteRackConsole([Map<String, dynamic>? site]) {
    return isCurrentSiteKiosk(site);
  }

  bool get hasPin {
    if (currentUser == null) {
      return true; // Default true to avoid false positives
    }
    final hasPinFlag = currentUser!['has_pin'];
    final pinSetupFlag = currentUser!['pin_setup'];
    final pinValue = currentUser!['pin'];

    if (hasPinFlag != null) return isTruthyFlag(hasPinFlag);
    if (pinSetupFlag != null) return isTruthyFlag(pinSetupFlag);
    if (pinValue != null && pinValue.toString().trim().isNotEmpty) return true;

    return false;
  }

  Future<String?> getUsername() async {
    if (_portalUsername != null && _portalUsername!.isNotEmpty) {
      return _portalUsername;
    }

    final prefs = await SharedPreferences.getInstance();
    _portalUsername = prefs.getString(_keyPortalUsername);
    return _portalUsername;
  }

  Future<int?> getUserId() async {
    if (_portalUserId != null) {
      return _portalUserId;
    }

    final prefs = await SharedPreferences.getInstance();
    _portalUserId = prefs.getInt(_keyPortalUserId);
    return _portalUserId;
  }

  Future<Map<String, dynamic>?> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    // Production auth path only.
    // ──────────────────────────────────────────────────────────────────

    try {
      if (kDebugMode) {
        AppLog.d('[CpanelApi] Attempting login for: $username');
      }
      // ... existing code ...
      final response = await http.post(
        Uri.parse("$baseUrl?action=login"),
        // Use form-encoded body for maximum compatibility with PHP/cPanel
        // backends (which often read `$_POST` rather than JSON input).
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: <String, String>{
          "action": "login",
          "username": username,
          "password": password,
          // Many PHP backends treat this as a truthy "1"/"0" string.
          "remember_me": rememberMe ? "1" : "0",
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'success') {
          _portalPasswordInMemory = password;
          final token = data['auth_token']?.toString().trim();
          if (token != null && token.isNotEmpty) {
            _portalAuthToken = token;
            if (kDebugMode) {
              final prefix =
                  token.length <= 16 ? token : token.substring(0, 16);
              AppLog.d(
                '[CpanelApi] Portal token set (masked)',
                fields: {'prefix': prefix, 'length': token.length},
              );
            }
          }
          final user = data['user'];
          if (user is Map<String, dynamic>) {
            currentUser = user;
            notifyListeners();
          }
          final portalUsername = (user is Map<String, dynamic>)
              ? (user['username']?.toString() ?? username)
              : username;
          final portalUserId = (user is Map<String, dynamic>)
              ? int.tryParse(user['id']?.toString() ?? '')
              : null;
          await _persistPortalSession(
            username: portalUsername,
            userId: portalUserId,
          );
        }
        return data;
      } else {
        // If not 200, try to parse the body anyway to get the error message.
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return data;
        } catch (_) {
          return {
            "status": "error",
            "message": "Server returned status ${response.statusCode}"
          };
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLog.d('[CpanelApi] Login exception: $e');
      }
      return {
        "status": "error",
        "message": _friendlyConnectionError(e, url: "$baseUrl?action=login"),
      };
    }
  }

  Future<Map<String, dynamic>?> _postJson(
    String action, {
    required Map<String, dynamic> fields,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final response = await http
        .post(
          Uri.parse("$baseUrl?action=$action"),
          headers: <String, String>{
            "Content-Type": "application/json",
            "Accept": "application/json",
            ...?headers,
          },
          body: jsonEncode({
            "action": action,
            ...fields,
          }),
        )
        .timeout(timeout);

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return null;
  }

  Future<Map<String, dynamic>?> verifyPin(String pin) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl?action=verify_pin"),
            headers: _authHeaders(extra: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            }),
            body: jsonEncode({
              "action": "verify_pin",
              "pin": pin,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is Map<String, dynamic> ? data : null;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('verifyPin error', tag: 'CpanelApi', error: e);
      }
      return null;
    }
  }

  Future<bool> setPin(String pin) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl?action=set_pin"),
            headers: _authHeaders(extra: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            }),
            body: jsonEncode({
              "action": "set_pin",
              "pin": pin,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is Map<String, dynamic> && data['status'] == 'success';
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('setPin error', tag: 'CpanelApi', error: e);
      }
      return false;
    }
  }

  String _friendlyConnectionError(Object error, {required String url}) {
    final msg = error.toString();
    if (msg.contains('Failed host lookup')) {
      return 'Connection Error: Unable to resolve server hostname. Please verify your internet connection.';
    }
    if (error is SocketException) {
      return 'Connection Error: Unable to reach the server. Please verify your network connection.';
    }
    if (msg.contains('timed out') || msg.contains('TimeoutException')) {
      return 'Connection Error: The request timed out. The server might be busy or offline.';
    }
    return 'Connection Error: An unexpected network error occurred.';
  }

  Future<List<dynamic>> fetchUserSites() async {
    // Production site lookup only.
    // DERIVED IDENTITY: The backend now enforces Bearer token auth.
    // We no longer send user_id in the query string to prevent identity spoofing.
    // ──────────────────────────────────────────────────────────────────

    try {
      if (kDebugMode) {
        AppLog.d('[CpanelApi] Fetching sites via token identity');
      }

      // If this is null/empty, the backend will return 401 and the UI used to
      // incorrectly show "No Racks found". Make it explicit.
      if (_portalAuthToken == null || _portalAuthToken!.isEmpty) {
        throw 'Portal session token is missing. Please sign in again.';
      }

      final url = Uri.parse("$baseUrl?action=get_sites");
      final response = await http
          .get(
            url,
            headers: _authHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        AppLog.d('[CpanelApi] GET sites status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        if (kDebugMode) {
          AppLog.d('[CpanelApi] get_sites RAW: ${response.body}');
        }
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final status = decoded['status']?.toString();
          if (status != 'success') {
            final msg =
                decoded['message']?.toString() ?? 'Failed to fetch sites.';
            throw msg;
          }
          final sites = decoded['sites'];
          if (kDebugMode) {
            AppLog.d(
                '[CpanelApi] Sites Count: ${sites is List ? sites.length : 0}');
          }
          return sites is List ? sites : <dynamic>[];
        }
        throw 'Invalid response from server.';
      }

      if (kDebugMode) {
        AppLog.d('[CpanelApi] Non-200 Response: ${response.body}');
      }
      throw 'Failed to fetch sites (HTTP ${response.statusCode}).';
    } catch (e) {
      if (kDebugMode) {
        AppLog.d('[CpanelApi] Fetch sites error: $e');
      }
      rethrow;
    }
  }

  Future<bool> changePassword({
    required String username,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      if (kDebugMode) {
        AppLog.d('[CpanelApi] Changing password for: $username');
      }
      final data = await _postJson(
        "change_password",
        headers: _authHeaders(),
        fields: <String, dynamic>{
          "username": username,
          "current_password": currentPassword,
          "new_password": newPassword,
        },
      );

      if (data != null) {
        final ok = data['status'] == 'success';
        if (ok) {
          // Keep in-memory password in sync for the current session.
          _portalPasswordInMemory = newPassword;
        }
        return ok;
      }
    } catch (e) {
      if (kDebugMode) {
        AppLog.d('[CpanelApi] Change password error: $e');
      }
    }
    return false;
  }

  Future<void> logout() async {
    try {
      if (_portalAuthToken != null && _portalAuthToken!.isNotEmpty) {
        await http
            .post(
              Uri.parse("$baseUrl?action=logout"),
              headers:
                  _authHeaders(extra: {"Content-Type": "application/json"}),
              body: jsonEncode({"action": "logout"}),
            )
            .timeout(const Duration(seconds: 10));
      }
    } catch (_) {
      // Ignore logout network errors; local session will still be cleared.
    } finally {
      await clearSession();
    }
  }

  Future<Map<String, dynamic>?> authMe({required String token}) async {
    try {
      // Only persist the token in memory after the backend accepts it.
      final response = await http.get(
        Uri.parse("$baseUrl?action=auth_me"),
        headers: <String, String>{
          ..._authHeaders(extra: const {"Accept": "application/json"}),
          if ((_portalAuthToken == null || _portalAuthToken!.isEmpty))
            'Authorization': 'Bearer $token',
          if ((_portalAuthToken == null || _portalAuthToken!.isEmpty))
            'X-Auth-Token': token,
        },
      ).timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['status'] == 'success') {
        _portalAuthToken = token.trim();
        final user = decoded['user'];
        if (user is Map<String, dynamic>) {
          currentUser = user;
          notifyListeners();
        }
        final portalUsername = (user is Map<String, dynamic>)
            ? (user['username']?.toString())
            : null;
        final portalUserId = (user is Map<String, dynamic>)
            ? int.tryParse(user['id']?.toString() ?? '')
            : null;
        if (portalUsername != null) {
          await _persistPortalSession(
              username: portalUsername, userId: portalUserId);
        }
        return decoded;
      }
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('auth_me error', tag: 'CpanelApi', error: e);
      }
    }

    // Ensure we don't keep a bad/expired token in memory after failure.
    if (_portalAuthToken == token) {
      _portalAuthToken = null;
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchAppConfig({
    required int siteId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl?action=app_config&site_id=$siteId"),
            headers: _authHeaders(extra: {"Content-Type": "application/json"}),
            body: jsonEncode({
              "action": "app_config",
              "site_id": siteId,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final status = (decoded['status'] ?? '').toString().toLowerCase();
      if (status.isNotEmpty && status != 'success') return null;
      return decoded;
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('Fetch app config error', tag: 'CpanelApi', error: e);
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchSiteControlPresets({
    required int siteId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl?action=get_site_control_presets"),
            headers: _authHeaders(extra: {"Content-Type": "application/json"}),
            body: jsonEncode({
              "action": "get_site_control_presets",
              "site_id": siteId,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('Fetch site control presets error',
            tag: 'CpanelApi', error: e);
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> saveSiteControlPreset({
    required int siteId,
    required String presetKey,
    required String adminPassword,
    required List<Map<String, dynamic>> values,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl?action=save_site_control_preset"),
            headers: _authHeaders(extra: {"Content-Type": "application/json"}),
            body: jsonEncode({
              "action": "save_site_control_preset",
              "site_id": siteId,
              "preset_key": presetKey,
              "admin_password": adminPassword,
              "values": values,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('Save site control preset error', tag: 'CpanelApi', error: e);
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> setDefaultSiteControlPreset({
    required int siteId,
    required String presetKey,
    required String adminPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl?action=set_default_site_control_preset"),
            headers: _authHeaders(extra: {"Content-Type": "application/json"}),
            body: jsonEncode({
              "action": "set_default_site_control_preset",
              "site_id": siteId,
              "preset_key": presetKey,
              "admin_password": adminPassword,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('Set default site control preset error',
            tag: 'CpanelApi', error: e);
      }
    }
    return null;
  }

  Map<String, dynamic> mergeSiteWithAppConfig(
    Map<String, dynamic> site,
    Map<String, dynamic>? appConfigEnvelope,
  ) {
    if (appConfigEnvelope == null) return Map<String, dynamic>.from(site);

    final cfgRaw = appConfigEnvelope['config'] ??
        appConfigEnvelope['result'] ??
        appConfigEnvelope;
    if (cfgRaw is! Map) return Map<String, dynamic>.from(site);
    final cfg = Map<String, dynamic>.from(cfgRaw);

    currentAppConfig = cfg;
    notifyListeners();

    final out = Map<String, dynamic>.from(site);
    final dahuaCabinetId = cfg['dahua_cabinet_id'] ?? cfg['cabinet_id'];
    if (dahuaCabinetId != null && dahuaCabinetId.toString().trim().isNotEmpty) {
      out['dahua_cabinet_id'] = dahuaCabinetId.toString();
    }
    if (cfg['config_version'] != null) {
      out['config_version'] = cfg['config_version'];
    }
    if (cfg['nodes'] != null) {
      out['app_config_nodes'] = cfg['nodes'];
    }
    if (cfg['charts'] != null) {
      out['app_config_charts'] = cfg['charts'];
    }
    return out;
  }

  Future<Map<String, dynamic>> mergeCurrentMemberPermissions(
    Map<String, dynamic> site,
  ) async {
    final siteId = int.tryParse(site['site_id']?.toString() ?? '');
    if (siteId == null) return Map<String, dynamic>.from(site);

    try {
      final membersRes = await fetchSiteMembers(siteId: siteId);
      final members = (membersRes?['members'] is List)
          ? (membersRes!['members'] as List)
          : null;
      if (members == null || members.isEmpty) {
        return Map<String, dynamic>.from(site);
      }

      final portalUserId = await getUserId();
      final portalUsername = (await getUsername())?.trim().toLowerCase();

      Map<String, dynamic>? matched;
      for (final raw in members) {
        if (raw is! Map) continue;
        final member = Map<String, dynamic>.from(raw);
        final memberUserId = int.tryParse(member['user_id']?.toString() ?? '');
        final memberUsername = (member['username'] ??
                member['member_username'] ??
                member['member_user'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();

        if (portalUserId != null &&
            memberUserId != null &&
            portalUserId == memberUserId) {
          matched = member;
          break;
        }
        if (portalUsername != null &&
            portalUsername.isNotEmpty &&
            memberUsername == portalUsername) {
          matched = member;
          break;
        }
      }

      if (matched == null) return Map<String, dynamic>.from(site);

      final merged = Map<String, dynamic>.from(site);
      for (final entry in matched.entries) {
        if (entry.key == 'role' ||
            entry.key == 'is_kiosk' ||
            entry.key.startsWith('can_')) {
          merged[entry.key] = entry.value;
        }
      }
      return merged;
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('Merge member permissions error', tag: 'CpanelApi', error: e);
      }
      return Map<String, dynamic>.from(site);
    }
  }

  Future<Map<String, dynamic>?> fetchSiteMembers({
    required int siteId,
    String? adminUsername,
    String? adminPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl?action=list_site_members"),
            headers: _authHeaders(extra: {"Content-Type": "application/json"}),
            body: jsonEncode({
              "action": "list_site_members",
              "site_id": siteId,
              if (adminUsername != null) "admin_username": adminUsername,
              if (adminPassword != null) "admin_password": adminPassword,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('Fetch members error', tag: 'CpanelApi', error: e);
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> registerPushToken({
    required int siteId,
    required String deviceToken,
    String platform = 'android',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl?action=register_push_token"),
            headers: _authHeaders(extra: {"Content-Type": "application/json"}),
            body: jsonEncode({
              "action": "register_push_token",
              "site_id": siteId,
              "device_token": deviceToken,
              "platform": platform,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('Register push token error', tag: 'CpanelApi', error: e);
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> removePushToken({
    required int siteId,
    required String deviceToken,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl?action=remove_push_token"),
            headers: _authHeaders(extra: {"Content-Type": "application/json"}),
            body: jsonEncode({
              "action": "remove_push_token",
              "site_id": siteId,
              "device_token": deviceToken,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('Remove push token error', tag: 'CpanelApi', error: e);
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> createSiteUser({
    required int siteId,
    required String adminUsername,
    required String adminPassword,
    required String newUsername,
    required String role,
    required Map<String, dynamic> permissions,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl?action=create_site_user"),
            headers: _authHeaders(extra: {"Content-Type": "application/json"}),
            body: jsonEncode({
              "action": "create_site_user",
              "site_id": siteId,
              "admin_username": adminUsername,
              "admin_password": adminPassword,
              "new_username": newUsername,
              "role": role,
              "permissions": permissions,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('Create site user error', tag: 'CpanelApi', error: e);
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> setupFirstPassword({
    required String username,
    required String newPassword,
  }) async {
    try {
      final decoded = await _postJson(
        "setup_first_password",
        fields: <String, dynamic>{
          "username": username,
          "new_password": newPassword,
        },
        timeout: const Duration(seconds: 12),
      );
      if (decoded != null) return decoded;
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('Setup first password error', tag: 'CpanelApi', error: e);
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> resetPasswordByUsername({
    required String username,
    required String newPassword,
  }) async {
    try {
      final decoded = await _postJson(
        "reset_password_by_username",
        fields: <String, dynamic>{
          "username": username,
          "new_password": newPassword,
        },
        timeout: const Duration(seconds: 12),
      );
      if (decoded != null) return decoded;
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('Reset password by username error',
            tag: 'CpanelApi', error: e);
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> updateSiteMember({
    required int siteId,
    String? adminUsername,
    String? adminPassword,
    required int memberUserId,
    required String role,
    required Map<String, dynamic> permissions,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl?action=update_site_member"),
            headers: _authHeaders(extra: {"Content-Type": "application/json"}),
            body: jsonEncode({
              "action": "update_site_member",
              "site_id": siteId,
              if (adminUsername != null) "admin_username": adminUsername,
              if (adminPassword != null) "admin_password": adminPassword,
              "member_user_id": memberUserId,
              "role": role,
              "permissions": permissions,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('Update member error', tag: 'CpanelApi', error: e);
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> removeSiteMember({
    required int siteId,
    required String adminUsername,
    required String adminPassword,
    required int memberUserId,
  }) async {
    try {
      Future<Map<String, dynamic>?> call(String action) async {
        final response = await http
            .post(
              Uri.parse("$baseUrl?action=$action"),
              headers:
                  _authHeaders(extra: {"Content-Type": "application/json"}),
              body: jsonEncode({
                "action": action,
                "site_id": siteId,
                "admin_username": adminUsername,
                "admin_password": adminPassword,
                "member_user_id": memberUserId,
              }),
            )
            .timeout(const Duration(seconds: 12));

        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : null;
      }

      // Primary (documented) endpoint
      final res1 = await call('remove_site_member');
      final msg1 = res1?['message']?.toString() ?? '';
      if (res1 != null &&
          !(msg1.contains("Invalid Action") ||
              msg1.contains("Invalid action"))) {
        return res1;
      }

      // Backward/typo compatibility: some servers mistakenly used plural action.
      final res2 = await call('remove_site_members');
      if (res2 != null) return res2;
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('Remove member error', tag: 'CpanelApi', error: e);
      }
    }
    return null;
  }

  Future<bool> updateMaintenanceDate(int siteId, String date) async {
    try {
      if (kDebugMode) {
        AppLog.d(
          'Updating maintenance',
          tag: 'CpanelApi',
          fields: {'siteId': siteId, 'date': date},
        );
      }
      final response = await http
          .post(
            Uri.parse("$baseUrl?action=update_maintenance"),
            headers: _authHeaders(extra: {"Content-Type": "application/json"}),
            body: jsonEncode({
              "site_id": siteId,
              "maintenance_date": date,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('Update maintenance error', tag: 'CpanelApi', error: e);
      }
    }
    return false;
  }

  Future<Map<String, dynamic>?> verifySiteUserPin({
    required int siteId,
    required String pin,
    String actionType = 'door_unlock',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl?action=verify_site_user_pin"),
            headers: _authHeaders(extra: {"Content-Type": "application/json"}),
            body: jsonEncode({
              "action": "verify_site_user_pin",
              "site_id": siteId,
              "pin": pin,
              "action_type": actionType,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('verifySiteUserPin error', tag: 'CpanelApi', error: e);
      }
    }
    return null;
  }

  Future<bool> logRemoteAccess({
    required int siteId,
    required int doorId,
    int? overrideUserId,
  }) async {
    try {
      final body = <String, dynamic>{
        "action": "log_remote_access",
        "site_id": siteId,
        "door_id": doorId,
      };
      if (overrideUserId != null) {
        body["override_user_id"] = overrideUserId;
      }

      final response = await http
          .post(
            Uri.parse("$baseUrl?action=log_remote_access"),
            headers: _authHeaders(extra: {"Content-Type": "application/json"}),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['status'] == 'success';
      }
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('logRemoteAccess error', tag: 'CpanelApi', error: e);
      }
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> fetchRemoteAccessLogs({
    required int siteId,
    int? startTime,
    int? endTime,
  }) async {
    try {
      final body = <String, dynamic>{
        "action": "get_remote_access_logs",
        "site_id": siteId,
      };
      if (startTime != null) body["start_time"] = startTime;
      if (endTime != null) body["end_time"] = endTime;

      final response = await http
          .post(
            Uri.parse("$baseUrl?action=get_remote_access_logs"),
            headers: _authHeaders(extra: {"Content-Type": "application/json"}),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == 'success' && decoded['logs'] is List) {
          return List<Map<String, dynamic>>.from(decoded['logs']);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('fetchRemoteAccessLogs error', tag: 'CpanelApi', error: e);
      }
    }
    return [];
  }

  Future<Map<String, dynamic>?> uploadLogo({
    required int siteId,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    try {
      if (kDebugMode) {
        AppLog.d(
          'Uploading logo',
          tag: 'CpanelApi',
          fields: {
            'siteId': siteId,
            'fileName': fileName,
            'size': fileBytes.length,
          },
        );
      }

      final uri = Uri.parse("$baseUrl?action=upload_logo");
      final request = http.MultipartRequest('POST', uri);

      // Add auth headers
      request.headers.addAll(_authHeaders());

      // Add fields
      request.fields['action'] = 'upload_logo';
      request.fields['site_id'] = siteId.toString();

      MediaType? contentType;
      final ext = fileName.split('.').last.toLowerCase();
      if (ext == 'jpg' || ext == 'jpeg') {
        contentType = MediaType('image', 'jpeg');
      } else if (ext == 'png') {
        contentType = MediaType('image', 'png');
      }

      // Add file
      final file = http.MultipartFile.fromBytes(
        'logo',
        fileBytes,
        filename: fileName,
        contentType: contentType,
      );
      request.files.add(file);

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (kDebugMode) {
        AppLog.d(
          'Upload response',
          tag: 'CpanelApi',
          fields: {
            'statusCode': response.statusCode,
            'body': response.body.length > 500
                ? '${response.body.substring(0, 500)}...'
                : response.body,
          },
        );
      }

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (response.statusCode != 200 && decoded['status'] == null) {
            decoded['status'] = 'error';
          }
          return decoded;
        }
      } catch (_) {
        // Fall through to a normalized response below.
      }

      if (response.statusCode != 200) {
        return {
          'status': 'error',
          'message': 'Upload failed (${response.statusCode}).',
        };
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (kDebugMode) {
          AppLog.d('Upload result',
              tag: 'CpanelApi', fields: {'status': '$data'});
        }
        return data;
      }
    } catch (e) {
      if (kDebugMode) {
        AppLog.w('Upload logo error', tag: 'CpanelApi', error: e);
      }
    }
    return null;
  }
}
