import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../controllers/global_status_poller.dart';
import '../network/adapter_api_service.dart';
import '../network/api_service.dart';
import '../network/cpanel_api_service.dart';
import '../notifications/push_notification_service.dart';
import '../security/app_lock_controller.dart';
import '../security/secure_action_session.dart';
import '../utils/app_log.dart';
import '../../features/smart_rack_console/services/smart_rack_console_repository.dart';
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

    final sitesRaw = authRes['sites'];
    if (sitesRaw is! List || sitesRaw.isEmpty) {
      throw 'No Racks found for this account. Please contact support.';
    }

    final allSites = sitesRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (allSites.isEmpty) {
      throw 'No Racks found for this account. Please contact support.';
    }

    // In 'main' build, filter to non-kiosk sites if any exist; in rack_console, keep kiosk sites.
    final eligibleSites = AppConfig.isRackConsoleBuild
        ? allSites
        : allSites
            .where((s) => !CpanelApiService.instance.isCurrentSiteRackConsole(s))
            .toList();
    final usableSites = eligibleSites.isNotEmpty ? eligibleSites : allSites;
    CpanelApiService.instance.setAvailableSites(usableSites);

    final preferredId = CpanelApiService.instance.selectedSiteId;
    final initialSite = usableSites.firstWhere(
      (s) => int.tryParse(s['site_id']?.toString() ?? '') == preferredId,
      orElse: () => usableSites.first,
    );

    final mergedSite = await CpanelApiService.instance
        .mergeCurrentMemberPermissions(initialSite);
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

  /// Switches the active site in 'main' build (disabled in rack_console kiosk).
  Future<Map<String, dynamic>> switchSite(
    Map<String, dynamic> targetSite,
  ) async {
    if (AppConfig.isRackConsoleBuild) {
      return CpanelApiService.instance.currentSite ?? targetSite;
    }

    final mergedSite = await CpanelApiService.instance
        .mergeCurrentMemberPermissions(Map<String, dynamic>.from(targetSite));
    final site = await _mergeSiteWithRemoteConfig(mergedSite);
    CpanelApiService.instance.currentSite = site;

    await connectRackSession(site);
    SmartRackConsoleRepository.instance.refreshForSiteSwitch();
    await GlobalStatusPoller.instance.resetForSiteSwitch();

    await PushNotificationService.instance.ensureTokenRegistered(
      timeout: const Duration(seconds: 5),
      retryInterval: const Duration(milliseconds: 500),
    );

    return site;
  }

  /// Switches the active rack monitor within the current site in `'main'` build.
  Future<void> switchMonitor(Map<String, dynamic> monitor) async {
    if (AppConfig.isRackConsoleBuild) return;
    final id = int.tryParse(monitor['id']?.toString() ?? '');
    if (id == null || id <= 0) return;

    await CpanelApiService.instance.setSelectedMonitorId(id);
    SmartRackConsoleRepository.instance.refreshForSiteSwitch();
    await GlobalStatusPoller.instance.resetForSiteSwitch();
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
