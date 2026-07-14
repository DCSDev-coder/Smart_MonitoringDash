import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/adapter_api_service.dart';
import '../network/api_service.dart';
import '../network/cpanel_api_service.dart';
import '../notifications/push_notification_service.dart';
import '../security/app_lock_controller.dart';
import '../security/secure_action_session.dart';
import '../utils/app_log.dart';
import 'remember_me_store.dart';

class SessionBootstrapResult {
  SessionBootstrapResult({
    required this.authResponse,
    required this.site,
    required this.isRackConsoleAccount,
  });

  final Map<String, dynamic> authResponse;
  final Map<String, dynamic> site;
  final bool isRackConsoleAccount;
}

class SessionFlowService {
  SessionFlowService._();
  static final SessionFlowService instance = SessionFlowService._();

  bool canEnterCurrentApp({
    required Map<String, dynamic> site,
    required bool isRackConsoleBuild,
  }) {
    final isRackConsoleAccount =
        CpanelApiService.instance.isCurrentSiteRackConsole(site);
    return isRackConsoleBuild ? isRackConsoleAccount : !isRackConsoleAccount;
  }

  Future<SessionBootstrapResult> bootstrapFromToken({
    required String token,
  }) async {
    final authRes = await CpanelApiService.instance.authMe(token: token);
    if (authRes == null) {
      throw const SessionBootstrapTransientException(
        'Saved session could not be restored right now. Please try signing in again.',
      );
    }
    if (authRes['status'] != 'success') {
      final msg = authRes['message']?.toString().trim();
      throw SessionBootstrapInvalidException(
        (msg != null && msg.isNotEmpty)
            ? msg
            : 'Session expired. Please sign in again.',
      );
    }

    final sites = authRes['sites'];
    if (sites is! List || sites.isEmpty) {
      throw 'No Racks found for this account. Please contact support.';
    }

    final firstSite = sites[0];
    if (firstSite is! Map) {
      throw 'No Racks found for this account. Please contact support.';
    }

    final mergedSite = await CpanelApiService.instance
        .mergeCurrentMemberPermissions(Map<String, dynamic>.from(firstSite));
    final site = await _mergeSiteWithRemoteConfig(mergedSite);
    CpanelApiService.instance.currentSite = site;
    await PushNotificationService.instance.ensureTokenRegistered(
      timeout: const Duration(seconds: 8),
      retryInterval: const Duration(milliseconds: 500),
    );

    return SessionBootstrapResult(
      authResponse: authRes,
      site: site,
      isRackConsoleAccount:
          CpanelApiService.instance.isCurrentSiteRackConsole(site),
    );
  }

  Future<Map<String, dynamic>> _mergeSiteWithRemoteConfig(
      Map<String, dynamic> site) async {
    final siteId = int.tryParse(site['site_id']?.toString() ?? '');
    Map<String, dynamic>? cfgEnvelope;

    if (siteId != null) {
      if (AdapterApiService.instance.isConfigured) {
        cfgEnvelope =
            await AdapterApiService.instance.fetchAppConfig(siteId: siteId);
      }
      cfgEnvelope ??=
          await CpanelApiService.instance.fetchAppConfig(siteId: siteId);
    }

    return CpanelApiService.instance.mergeSiteWithAppConfig(site, cfgEnvelope);
  }

  Future<bool> connectRackSession(
    Map<String, dynamic> site, {
    bool allowBackgroundLogin = true,
  }) async {
    final targetIp = site['open_ip'];
    final siteUser = (site['site_user'] ?? 'admin').toString();
    final sitePass = (site['site_pass'] ?? '').toString();

    if (targetIp == null || targetIp.toString().isEmpty || sitePass.isEmpty) {
      return false;
    }

    bool ok = false;
    final dbLocalIp = site['local_ip']?.toString();
    final manualFallbackIp = await _getManualFallbackIp();
    final fallbackIp = (dbLocalIp != null && dbLocalIp.isNotEmpty)
        ? dbLocalIp
        : manualFallbackIp;

    if (AdapterApiService.instance.isConfigured && allowBackgroundLogin) {
      ok = true;
      ApiService.instance.login(siteUser, sitePass, ip: targetIp).ignore();
    } else {
      ok = await ApiService.instance.login(
        siteUser,
        sitePass,
        ip: targetIp,
      );

      if (!ok && fallbackIp.isNotEmpty) {
        if (kDebugMode) {
          AppLog.i('Public IP failed, trying local fallback IP', tag: 'Auth');
        }
        ok = await ApiService.instance.login(
          siteUser,
          sitePass,
          ip: fallbackIp,
        );
      }
    }

    return ok;
  }

  Future<String> _getManualFallbackIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('local_fallback_ip') ?? '';
  }

  Future<void> signOut() async {
    AppLockController.instance.clear();
    SecureActionSession.instance.clear();
    await rememberMeStore.clear();
    await PushNotificationService.instance.deactivateCurrentTokenIfPossible();
    await CpanelApiService.instance.logout();
    await ApiService.instance.logout();
  }
}

class SessionBootstrapTransientException implements Exception {
  const SessionBootstrapTransientException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SessionBootstrapInvalidException implements Exception {
  const SessionBootstrapInvalidException(this.message);
  final String message;

  @override
  String toString() => message;
}
